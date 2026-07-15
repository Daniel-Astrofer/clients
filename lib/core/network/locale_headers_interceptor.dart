import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/localization/app_timezone.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';

/// Attaches locale / timezone / currency to every API request so content,
/// education feed, and notifications can personalize on the backend.
class LocaleHeadersInterceptor extends Interceptor {
  LocaleHeadersInterceptor(this._ref);

  final Ref _ref;

  static const acceptLanguageHeader = 'Accept-Language';
  static const timezoneHeader = 'X-Timezone';
  static const timezoneOffsetHeader = 'X-Timezone-Offset-Minutes';
  static const currencyHeader = 'X-Currency';
  static const localeHeader = 'X-Locale';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final prefs = _ref.read(appDisplayPreferencesProvider);
      final language = prefs.locale.languageCode;
      final timeZone = prefs.timeZoneId;
      final currency = prefs.currency.code;

      options.headers[acceptLanguageHeader] = language;
      options.headers[localeHeader] = language;
      options.headers[timezoneHeader] = timeZone;
      options.headers[timezoneOffsetHeader] =
          AppTimezone.deviceOffsetMinutes().toString();
      options.headers[currencyHeader] = currency;
    } catch (_) {
      // Preferences may not be ready during early bootstrap — still send device TZ.
      options.headers.putIfAbsent(
        timezoneHeader,
        AppTimezone.detectId,
      );
      options.headers.putIfAbsent(
        timezoneOffsetHeader,
        () => AppTimezone.deviceOffsetMinutes().toString(),
      );
    }
    handler.next(options);
  }
}
