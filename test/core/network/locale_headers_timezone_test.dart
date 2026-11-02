import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/localization/app_timezone.dart';
import 'package:kerosene/core/network/locale_headers_interceptor.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';

final _interceptor = Provider((ref) => LocaleHeadersInterceptor(ref));

class _HeaderCapture implements HttpClientAdapter {
  late RequestOptions last;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('headers follow committed selection, then return to device mode',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'app_locale': 'pt',
      'app_currency': 'BTC',
      'app_timezone': 'UTC+05:45',
      'app_timezone_follow_device': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
    addTearDown(container.dispose);
    final capture = _HeaderCapture();
    final dio = Dio()..httpClientAdapter = capture;
    addTearDown(dio.close);
    dio.interceptors.add(container.read(_interceptor));
    await dio.get('https://fixture.invalid');
    expect(capture.last.headers['X-Timezone'], 'UTC+05:45');
    expect(capture.last.headers['X-Timezone-Offset-Minutes'], '345');
    expect(capture.last.headers['X-Currency'], 'BTC');
    final notifier = container.read(appDisplayPreferencesProvider.notifier);
    await expectLater(
        notifier.setTimeZoneId('America/Invented'), throwsArgumentError);
    expect(
        container.read(appDisplayPreferencesProvider).timeZoneId, 'UTC+05:45');
    expect(preferences.getString('app_timezone'), 'UTC+05:45');
    await notifier.setTimeZoneId('America/Sao_Paulo');
    await dio.get('https://fixture.invalid');
    expect(capture.last.headers['X-Timezone'], 'America/Sao_Paulo');
    expect(capture.last.headers['X-Timezone-Offset-Minutes'], '-180');
    await notifier.setTimeZoneFollowDevice(true);
    await dio.get('https://fixture.invalid');
    expect(capture.last.headers['X-Timezone'], AppTimezone.detectId());
    expect(capture.last.headers['X-Timezone-Offset-Minutes'],
        AppTimezone.deviceOffsetMinutes().toString());
  });
}
