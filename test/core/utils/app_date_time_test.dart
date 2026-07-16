import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/app_date_time.dart';

void main() {
  group('AppDateTime.parse', () {
    test('treats bare ISO wall clock as UTC then converts to local', () {
      final parsed = AppDateTime.parse('2026-07-15T22:47:00');
      expect(parsed, isNotNull);
      // Local offset may vary in CI; assert the UTC instant is correct.
      expect(parsed!.toUtc().hour, 22);
      expect(parsed.toUtc().minute, 47);
    });

    test('honors explicit Z', () {
      final parsed = AppDateTime.parse('2026-07-15T22:47:00Z');
      expect(parsed, isNotNull);
      expect(
        parsed!.toUtc().toIso8601String(),
        startsWith('2026-07-15T22:47:00'),
      );
    });
  });

  group('AppDateTime.formatRelative', () {
    testWidgets('shows minutes ago in Portuguese', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      final now = DateTime(2026, 7, 15, 19, 50);
      final threeMinAgo = now.subtract(const Duration(minutes: 3));
      expect(
        AppDateTime.formatRelative(
          context,
          threeMinAgo,
          now: now,
          languageCode: 'pt',
        ),
        'há 3 min',
      );
      expect(
        AppDateTime.formatRelative(
          context,
          now,
          now: now,
          languageCode: 'pt',
        ),
        'agora',
      );
      expect(
        AppDateTime.formatRelative(
          context,
          threeMinAgo,
          now: now,
          languageCode: 'en',
        ),
        '3m ago',
      );
    });
  });
}
