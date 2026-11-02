import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/security/presentation/screens/security_lookup.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('monochrome controls follow their inherited theme: $brightness',
        (tester) async {
      late MonochromeColors colors;
      late ButtonStyle button;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(builder: (context) {
            colors = MonochromeColors.of(context);
            button = monochromeFilledButtonStyle(context: context);
            return const SizedBox.shrink();
          })));
      expect(
          colors.text,
          brightness == Brightness.light
              ? MonochromeColors.light.text
              : MonochromeColors.dark.text);
      final foreground = button.foregroundColor!.resolve({})!;
      final background = button.backgroundColor!.resolve({})!;
      expect(
          (foreground.computeLuminance() - background.computeLuminance()).abs(),
          greaterThan(.8));
    });
  }
  test('lookup retains successful data and time through loading and failure',
      () {
    final lookup = SecurityLookup<bool>();
    final first = AsyncData<bool>(true);
    final at = DateTime(2020, 1, 1, 12);
    lookup.observe('a', first, now: at);
    lookup.observe('a', first, now: at.add(const Duration(hours: 1)));
    expect(lookup.checkedAt, at);
    lookup.observe('a', const AsyncLoading<bool>());
    expect(lookup.last, isTrue);
    expect(lookup.current, isFalse);
    lookup.observe(
        'a', AsyncError<bool>(StateError('private'), StackTrace.current));
    expect(lookup.last, isTrue);
    expect(lookup.checkedAt, at);
    expect(lookup.current, isFalse);
    expect(lookup.failed, isTrue);
    final nextAt = at.add(const Duration(hours: 2));
    lookup.observe('a', const AsyncData(false), now: nextAt);
    expect(lookup.last, isFalse);
    expect(lookup.current, isTrue);
    expect(lookup.checkedAt, nextAt);
  });

  test('a reused response cannot become another account snapshot', () {
    final lookup = SecurityLookup<int>();
    final response = AsyncData<int>(8);
    lookup.observe('a', response);
    lookup.observe('b', response);
    lookup.observe('b', response);
    expect(lookup.last, isNull);
    expect(lookup.checkedAt, isNull);
    expect(lookup.current, isFalse);
    lookup.observe('b', AsyncData<int>(3));
    expect(lookup.last, 3);
    expect(lookup.current, isTrue);
    lookup.observe(null, const AsyncData<int>(3));
    expect(lookup.last, isNull);
    expect(lookup.current, isFalse);
  });

  test('an initial failed lookup cannot invent disabled or zero status', () {
    final lookup = SecurityLookup<int>();
    lookup.observe('a', AsyncError(StateError('private'), StackTrace.current));
    expect(lookup.last, isNull);
    expect(lookup.checkedAt, isNull);
    expect(lookup.failed, isTrue);
    expect(lookup.current, isFalse);
  });
}
