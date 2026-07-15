import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bip39_mnemonic_utils.dart';

void main() {
  group('Bip39MnemonicUtils', () {
    test('accepts standard abandon vector', () {
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final r = Bip39MnemonicUtils.parse(phrase);
      expect(r.isValid, isTrue);
      expect(r.words.length, 12);
      expect(r.phrase, phrase);
    });

    test('normalizes newlines, commas and numbering on paste', () {
      const messy = '''
1. abandon
2. abandon
3. abandon
4. abandon
5. abandon
6. abandon
7. abandon
8. abandon
9. abandon
10. abandon
11. abandon
12. about
''';
      final r = Bip39MnemonicUtils.parse(messy);
      expect(r.isValid, isTrue, reason: r.message);
      expect(r.words.length, 12);
      expect(r.words.last, 'about');
    });

    test('double spaces still validate', () {
      const phrase =
          'abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  about';
      final r = Bip39MnemonicUtils.parse(phrase);
      expect(r.isValid, isTrue, reason: r.message);
    });

    test('generated 12-word is valid', () {
      final m = bip39.generateMnemonic(strength: 128);
      expect(Bip39MnemonicUtils.validate(m), isTrue);
    });

    test('wrong last word → checksum error', () {
      const bad =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';
      final r = Bip39MnemonicUtils.parse(bad);
      expect(r.isValid, isFalse);
      expect(r.code, Bip39MnemonicErrorCode.checksum);
      expect(r.message, contains('checksum'));
    });

    test('pole vs poem: same entropy typo hint', () {
      const withPole =
          'nut bone peanut cotton donate omit gossip siren breeze concert make pole';
      final r = Bip39MnemonicUtils.parse(withPole);
      expect(r.isValid, isFalse);
      expect(r.code, Bip39MnemonicErrorCode.checksum);
      expect(r.suggestedLastWord, 'poem');

      final forced = Bip39MnemonicUtils.parse(
        withPole,
        allowInvalidChecksum: true,
      );
      expect(forced.isValid, isTrue);
      expect(forced.checksumValid, isFalse);
      expect(forced.phrase.endsWith('pole'), isTrue);

      final fixed = Bip39MnemonicUtils.parse(
        'nut bone peanut cotton donate omit gossip siren breeze concert make poem',
      );
      expect(fixed.isValid, isTrue);
      expect(fixed.checksumValid, isTrue);
    });

    test('unknown word is reported with index', () {
      const bad =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon notaword';
      final r = Bip39MnemonicUtils.parse(bad);
      expect(r.isValid, isFalse);
      expect(r.code, Bip39MnemonicErrorCode.unknownWord);
      expect(r.problemIndexes, contains(11));
    });

    test('wrong count is reported', () {
      final r = Bip39MnemonicUtils.parse('abandon abandon about');
      expect(r.isValid, isFalse);
      expect(r.code, Bip39MnemonicErrorCode.wordCount);
    });
  });
}
