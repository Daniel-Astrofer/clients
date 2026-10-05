import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
// The package does not expose its English wordlist through the public API.
// ignore: implementation_imports
import 'package:bip39/src/wordlists/english.dart' as bip39_english;
import 'package:crypto/crypto.dart';

/// Shared BIP39 helpers for cold-wallet create/import.
///
/// The pub `bip39` package splits on a single space only and does not NFKD
/// normalize — so paste / mobile keyboards often produce false checksum errors.
class Bip39MnemonicUtils {
  Bip39MnemonicUtils._();

  static const Set<int> supportedWordCounts = {12, 15, 18, 21, 24};

  static List<String> get englishWordlist => bip39_english.WORDLIST;

  /// True when [word] is an English BIP39 word (case-insensitive).
  static bool isEnglishWord(String word) {
    final n = _normalizeToken(word);
    return n.isNotEmpty && bip39_english.WORDLIST.contains(n);
  }

  /// Collapse whitespace, strip punctuation noise, lower-case, NFKD-ish cleanup.
  static String normalizePhrase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    // Common paste noise: newlines, tabs, commas, numbered lists "1. word".
    s = s.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    s = s.replaceAll(RegExp(r'[,;|/\\]+'), ' ');
    s = s.replaceAll(RegExp(r'\b\d+[\.\):\-]\s*'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.toLowerCase();
    // Strip zero-width / BOM chars mobile keyboards sometimes inject.
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    // Decompose + strip combining marks (é → e) for latin keyboard accidents.
    s = _stripCombiningMarks(s);
    return s.trim();
  }

  static List<String> tokenize(String raw) {
    final normalized = normalizePhrase(raw);
    if (normalized.isEmpty) return const [];
    return normalized
        .split(' ')
        .map(_normalizeToken)
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }

  static String joinWords(Iterable<String> words) =>
      words.map(_normalizeToken).where((w) => w.isNotEmpty).join(' ');

  /// Validates and returns a normalized phrase, or a structured error.
  ///
  /// When [allowInvalidChecksum] is true, all words must still be English BIP39
  /// words with a legal count — only the checksum bit check is skipped.
  /// Seed derivation (PBKDF2) still uses the exact phrase string.
  static Bip39MnemonicParseResult parse(
    String raw, {
    bool allowInvalidChecksum = false,
  }) {
    final words = tokenize(raw);
    if (words.isEmpty) {
      return const Bip39MnemonicParseResult.invalid(
        code: Bip39MnemonicErrorCode.empty,
        message: 'Cole ou digite as palavras da semente.',
      );
    }
    if (!supportedWordCounts.contains(words.length)) {
      return Bip39MnemonicParseResult.invalid(
        code: Bip39MnemonicErrorCode.wordCount,
        message: 'São ${words.length} palavras. Use 12 ou 24 (BIP39). '
            'Se a carteira for Electrum com seed próprio, não é BIP39.',
        words: words,
      );
    }

    final unknown = <int>[];
    for (var i = 0; i < words.length; i++) {
      if (!bip39_english.WORDLIST.contains(words[i])) {
        unknown.add(i);
      }
    }
    if (unknown.isNotEmpty) {
      final preview =
          unknown.take(3).map((i) => '#${i + 1} “${words[i]}”').join(', ');
      return Bip39MnemonicParseResult.invalid(
        code: Bip39MnemonicErrorCode.unknownWord,
        message: 'Palavra(s) fora da lista BIP39 inglesa: $preview. '
            'Confira typos (ex.: abandon ≠ abandoned).',
        words: words,
        problemIndexes: unknown,
      );
    }

    final phrase = words.join(' ');
    if (!bip39.validateMnemonic(phrase)) {
      final suggestion = suggestChecksumFix(words);
      if (allowInvalidChecksum) {
        return Bip39MnemonicParseResult.valid(
          phrase: phrase,
          words: words,
          checksumValid: false,
        );
      }
      final hint = suggestion == null
          ? ''
          : ' Se a última palavra for typo, o checksum da mesma entropia pede “${suggestion.lastWord}”.';
      return Bip39MnemonicParseResult.invalid(
        code: Bip39MnemonicErrorCode.checksum,
        message: 'As palavras existem no BIP39, mas o checksum não fecha.$hint '
            'Ordem errada, typo (ex.: pole/poem), ou carteira que aceita seed sem checksum. '
            'Use “Importar mesmo assim” só se o backup for literalmente esta frase.',
        words: words,
        suggestedLastWord: suggestion?.lastWord,
      );
    }

    return Bip39MnemonicParseResult.valid(
      phrase: phrase,
      words: words,
      checksumValid: true,
    );
  }

  static bool validate(String raw) => parse(raw).isValid;

  /// Recomputes only the checksum bits of the last word, keeping the entropy
  /// bits implied by [words]. Typo hint (e.g. pole → poem).
  static Bip39ChecksumSuggestion? suggestChecksumFix(List<String> words) {
    if (!supportedWordCounts.contains(words.length)) return null;
    if (words.any((w) => !bip39_english.WORDLIST.contains(w))) return null;
    try {
      final bits = words.map((w) {
        final index = bip39_english.WORDLIST.indexOf(w);
        return index.toRadixString(2).padLeft(11, '0');
      }).join();
      // ENT bits = floor(len/33)*32 ; CS = ENT/32.
      final entLen = (bits.length ~/ 33) * 32;
      final csLen = bits.length - entLen;
      if (csLen <= 0 || entLen < 128) return null;
      final entBits = bits.substring(0, entLen);
      final entropy = _bitsToBytes(entBits);
      final hash = sha256.convert(entropy).bytes;
      final hashBits =
          hash.map((b) => b.toRadixString(2).padLeft(8, '0')).join();
      final csBits = hashBits.substring(0, csLen);
      final fixedBits = entBits + csBits;
      final lastBits = fixedBits.substring(fixedBits.length - 11);
      final lastIndex = int.parse(lastBits, radix: 2);
      final lastWord = bip39_english.WORDLIST[lastIndex];
      if (lastWord == words.last) return null;
      final fixedWords = [...words.sublist(0, words.length - 1), lastWord];
      final phrase = fixedWords.join(' ');
      if (!bip39.validateMnemonic(phrase)) return null;
      return Bip39ChecksumSuggestion(lastWord: lastWord, phrase: phrase);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _bitsToBytes(String bits) {
    final out = Uint8List(bits.length ~/ 8);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(bits.substring(i * 8, i * 8 + 8), radix: 2);
    }
    return out;
  }

  static String _normalizeToken(String word) {
    var w = word.trim().toLowerCase();
    w = w.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    w = _stripCombiningMarks(w);
    // Strip trailing punctuation occasionally left by paste.
    w = w.replaceAll(RegExp(r'[^a-z]'), '');
    return w;
  }

  static String _stripCombiningMarks(String input) {
    // Lightweight NFKD-ish: remove combining diacritical marks.
    final buf = StringBuffer();
    for (final rune in input.runes) {
      // Combining marks range.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      if (rune >= 0x1AB0 && rune <= 0x1AFF) continue;
      if (rune >= 0x1DC0 && rune <= 0x1DFF) continue;
      buf.writeCharCode(rune);
    }
    return buf.toString();
  }
}

enum Bip39MnemonicErrorCode {
  empty,
  wordCount,
  unknownWord,
  checksum,
}

class Bip39ChecksumSuggestion {
  final String lastWord;
  final String phrase;

  const Bip39ChecksumSuggestion({
    required this.lastWord,
    required this.phrase,
  });
}

class Bip39MnemonicParseResult {
  final bool isValid;
  final String phrase;
  final List<String> words;
  final Bip39MnemonicErrorCode? code;
  final String? message;
  final List<int> problemIndexes;
  final bool checksumValid;
  final String? suggestedLastWord;

  const Bip39MnemonicParseResult._({
    required this.isValid,
    required this.phrase,
    required this.words,
    this.code,
    this.message,
    this.problemIndexes = const [],
    this.checksumValid = true,
    this.suggestedLastWord,
  });

  const Bip39MnemonicParseResult.valid({
    required String phrase,
    required List<String> words,
    bool checksumValid = true,
  }) : this._(
          isValid: true,
          phrase: phrase,
          words: words,
          checksumValid: checksumValid,
        );

  const Bip39MnemonicParseResult.invalid({
    required Bip39MnemonicErrorCode code,
    required String message,
    List<String> words = const [],
    List<int> problemIndexes = const [],
    String? suggestedLastWord,
  }) : this._(
          isValid: false,
          phrase: '',
          words: words,
          code: code,
          message: message,
          problemIndexes: problemIndexes,
          checksumValid: false,
          suggestedLastWord: suggestedLastWord,
        );
}
