import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/security/secure_screen_guard.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bip39_mnemonic_utils.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';

/// Result of the BIP39 seed import wizard.
class SeedImportResult {
  final String mnemonic;
  final String passphrase;

  /// When true, phrase words are BIP39-english but checksum is non-standard.
  final bool allowInvalidChecksum;

  const SeedImportResult({
    required this.mnemonic,
    this.passphrase = '',
    this.allowInvalidChecksum = false,
  });
}

class SeedWordEntryScreen extends StatefulWidget {
  final int initialTotalWords;

  const SeedWordEntryScreen({super.key, this.initialTotalWords = 12});

  @override
  State<SeedWordEntryScreen> createState() => _SeedWordEntryScreenState();
}

class _SeedWordEntryScreenState extends State<SeedWordEntryScreen> {
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _pasteController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late int _totalWords;
  int _currentWordIndex = 1;
  final List<String> _selectedWords = [];
  List<String> _suggestions = [];
  bool _obscureWords = false;
  bool _showPassphrase = false;
  bool _pasteMode = false;
  String? _inlineError;
  String? _statusInfo; // non-error notice (e.g. Electrum detected)
  String? _suggestedLastWord;
  bool _allowInvalidChecksum = false;

  @override
  void initState() {
    super.initState();
    SecureScreenGuard.enter();
    _totalWords = widget.initialTotalWords == 24 ? 24 : 12;
    _wordController.addListener(_onTextChanged);
    Future.delayed(KeroseneMotion.seedReveal, () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    SecureScreenGuard.leave();
    _wordController.dispose();
    _passphraseController.dispose();
    _pasteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // For single-word entry, only the first token matters.
    final token = Bip39MnemonicUtils.tokenize(_wordController.text);
    final q = token.isEmpty ? '' : token.first;
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _inlineError = null;
      });
      return;
    }

    // If user pasted multiple words into the single field, route to paste flow.
    if (token.length > 1) {
      setState(() {
        _pasteMode = true;
        _pasteController.text = Bip39MnemonicUtils.joinWords(token);
        _wordController.clear();
        _suggestions = [];
        _inlineError = null;
      });
      return;
    }

    final matches = Bip39MnemonicUtils.englishWordlist
        .where((word) => word.startsWith(q))
        .take(8)
        .toList();

    setState(() {
      _suggestions = matches;
      _inlineError = matches.isEmpty
          ? 'Palavra fora da lista BIP39 inglesa'
          : null;
    });
  }

  void _setWordCount(int count) {
    if (count != 12 && count != 24) return;
    if (count == _totalWords) return;
    HapticFeedback.selectionClick();
    setState(() {
      _totalWords = count;
      if (_selectedWords.length > count) {
        _selectedWords.removeRange(count, _selectedWords.length);
      }
      _currentWordIndex = _selectedWords.length + 1;
      if (_currentWordIndex > count) {
        _currentWordIndex = count;
      }
      _wordController.clear();
      _suggestions = [];
      _inlineError = null;
      _focusNode.requestFocus();
    });
  }

  void _confirmWord(String word) {
    final normalized = Bip39MnemonicUtils.tokenize(word);
    if (normalized.length != 1 ||
        !Bip39MnemonicUtils.isEnglishWord(normalized.first)) {
      setState(() => _inlineError = 'Escolha uma palavra válida da lista');
      return;
    }
    final w = normalized.first;
    // Exact match only — never auto-pick a partial suggestion.
    if (!Bip39MnemonicUtils.englishWordlist.contains(w)) {
      setState(() => _inlineError = 'Palavra inválida');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedWords.length >= _totalWords) return;
      _selectedWords.add(w);
      _currentWordIndex = (_selectedWords.length < _totalWords)
          ? _selectedWords.length + 1
          : _totalWords;
      _wordController.clear();
      _suggestions = [];
      _inlineError = null;
      if (_selectedWords.length < _totalWords) {
        _focusNode.requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _undoLastWord() {
    if (_selectedWords.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedWords.removeLast();
      _currentWordIndex = _selectedWords.length + 1;
      _wordController.clear();
      _suggestions = [];
      _inlineError = null;
      _focusNode.requestFocus();
    });
  }

  void _applyPaste({bool forceInvalidChecksum = false}) {
    // Electrum native seeds fail BIP39 checksum by design — accept first.
    final electrum = ElectrumSeedUtils.detect(_pasteController.text);
    if (electrum != null) {
      final words = electrum.phrase.split(' ');
      HapticFeedback.mediumImpact();
      setState(() {
        _totalWords = words.length;
        _selectedWords
          ..clear()
          ..addAll(words);
        _currentWordIndex = words.length;
        _pasteMode = false;
        _inlineError = null;
        _statusInfo =
            'Seed Electrum ${electrum.isSegwit ? "segwit" : "standard"} (v${electrum.versionPrefix}). '
            'Toque em Importar carteira para registrar no servidor.';
        _suggestedLastWord = null;
        _allowInvalidChecksum = false;
        _showPassphrase = false;
      });
      return;
    }

    final parsed = Bip39MnemonicUtils.parse(
      _pasteController.text,
      allowInvalidChecksum: forceInvalidChecksum,
    );
    if (!parsed.isValid) {
      HapticFeedback.heavyImpact();
      setState(() {
        _inlineError = parsed.message;
        _statusInfo = null;
        _suggestedLastWord = parsed.suggestedLastWord;
        _allowInvalidChecksum = false;
      });
      return;
    }
    final words = parsed.words;
    final count = words.length == 24
        ? 24
        : (words.length == 12 ? 12 : words.length);
    HapticFeedback.mediumImpact();
    setState(() {
      _totalWords = count;
      _selectedWords
        ..clear()
        ..addAll(words);
      _currentWordIndex = words.length;
      _pasteMode = false;
      _inlineError = null;
      _statusInfo = parsed.checksumValid
          ? 'Semente BIP39 válida. Toque em Importar carteira.'
          : 'Checksum BIP39 inválido — importando a frase literal (não-padrão).';
      _suggestedLastWord = null;
      _allowInvalidChecksum = !parsed.checksumValid;
      _showPassphrase = false;
    });
  }

  void _applySuggestedLastWord() {
    final suggestion = _suggestedLastWord;
    if (suggestion == null || _selectedWords.isEmpty) {
      // Paste mode: replace last token in paste field.
      if (suggestion != null && _pasteMode) {
        final tokens = Bip39MnemonicUtils.tokenize(_pasteController.text);
        if (tokens.isNotEmpty) {
          tokens[tokens.length - 1] = suggestion;
          _pasteController.text = tokens.join(' ');
          _applyPaste();
        }
      }
      return;
    }
    setState(() {
      _selectedWords[_selectedWords.length - 1] = suggestion;
      _suggestedLastWord = null;
      _inlineError = null;
      _allowInvalidChecksum = false;
    });
  }

  void _finish({bool forceInvalidChecksum = false}) {
    FocusScope.of(context).unfocus();
    final joined = Bip39MnemonicUtils.joinWords(_selectedWords);
    if (joined.trim().isEmpty) {
      setState(() {
        _inlineError = 'Nenhuma palavra informada.';
        _statusInfo = null;
      });
      return;
    }

    // Electrum first — never treat as failed BIP39 checksum.
    final electrum = ElectrumSeedUtils.detect(joined);
    if (electrum != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(
        SeedImportResult(
          mnemonic: electrum.phrase,
          passphrase: _passphraseController.text,
        ),
      );
      return;
    }

    final allow = forceInvalidChecksum || _allowInvalidChecksum;
    final parsed = Bip39MnemonicUtils.parse(
      joined,
      allowInvalidChecksum: allow,
    );
    if (!parsed.isValid) {
      HapticFeedback.heavyImpact();
      setState(() {
        _inlineError = parsed.message;
        _statusInfo = null;
        _suggestedLastWord = parsed.suggestedLastWord;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parsed.message ?? context.tr.seedInvalid),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: KeroseneMotion.seedValidationTimeout,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      SeedImportResult(
        mnemonic: parsed.phrase,
        passphrase: _passphraseController.text,
        allowInvalidChecksum: !parsed.checksumValid,
      ),
    );
  }

  bool get _complete => _selectedWords.length >= _totalWords;

  @override
  Widget build(BuildContext context) {
    final progress = _totalWords == 0
        ? 0.0
        : _selectedWords.length / _totalWords;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            KeroseneIcons.arrowBack,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _pasteMode = !_pasteMode;
                _inlineError = null;
              });
            },
            child: Text(
              _pasteMode ? 'Palavra a palavra' : 'Colar frase',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscureWords
                  ? KeroseneIcons.visibilityOff
                  : KeroseneIcons.visibility,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() => _obscureWords = !_obscureWords);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onSurface,
                  ),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_pasteMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _WordCountChip(
                      label: '12 palavras',
                      selected: _totalWords == 12,
                      onTap: () => _setWordCount(12),
                    ),
                    const SizedBox(width: 12),
                    _WordCountChip(
                      label: '24 palavras',
                      selected: _totalWords == 24,
                      onTap: () => _setWordCount(24),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                _pasteMode
                    ? 'Cole a semente BIP39'
                    : _complete
                    ? 'Semente pronta'
                    : 'Palavra $_currentWordIndex / $_totalWords',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _pasteMode
                    ? 'Cole as 12 ou 24 palavras (inglês BIP39). '
                          'A passphrase opcional é outro campo — não misture.'
                    : 'Lista inglesa BIP39. Ordem importa (checksum). '
                          'Passphrase/25ª palavra é opcional e vem depois.',
                style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            if (_pasteMode)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _pasteController,
                        maxLines: 5,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'ex.: abandon ability able about above absent …',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      if (_inlineError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _inlineError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_suggestedLastWord != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            final tokens = Bip39MnemonicUtils.tokenize(
                              _pasteController.text,
                            );
                            if (tokens.isEmpty) return;
                            tokens[tokens.length - 1] = _suggestedLastWord!;
                            _pasteController.text = tokens.join(' ');
                            _applyPaste();
                          },
                          child: Text(
                            'Corrigir última palavra para “$_suggestedLastWord”',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _applyPaste(forceInvalidChecksum: true),
                          child: Text(
                            context.tr.seedImportAnyway,
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _applyPaste(),
                          child: Text(context.tr.seedValidateContinue),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              )
            else ...[
              if (!_complete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextField(
                    controller: _wordController,
                    focusNode: _focusNode,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    textAlign: TextAlign.center,
                    style: AppTypography.financial(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '',
                    ),
                    onSubmitted: (value) {
                      final tokens = Bip39MnemonicUtils.tokenize(value);
                      if (tokens.length == 1 &&
                          Bip39MnemonicUtils.isEnglishWord(tokens.first)) {
                        _confirmWord(tokens.first);
                      } else if (_suggestions.length == 1 &&
                          _suggestions.first == tokens.first) {
                        // Only auto-accept when the typed token is the full word.
                        _confirmWord(_suggestions.first);
                      } else if (_suggestions.contains(
                        tokens.isEmpty ? '' : tokens.first,
                      )) {
                        _confirmWord(tokens.first);
                      } else {
                        setState(() {
                          _inlineError =
                              'Toque numa sugestão ou digite a palavra completa';
                        });
                      }
                    },
                  ),
                ),
              if (_complete) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _showPassphrase = !_showPassphrase);
                        },
                        child: Text(
                          _showPassphrase
                              ? 'Ocultar passphrase BIP39'
                              : 'Adicionar passphrase BIP39 (opcional)',
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_showPassphrase)
                        TextField(
                          controller: _passphraseController,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: context.tr.seedPassphrase25th,
                            hintStyle: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      if (_statusInfo != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _statusInfo!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_inlineError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _inlineError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_suggestedLastWord != null) ...[
                        TextButton(
                          onPressed: _applySuggestedLastWord,
                          child: Text(
                            'Usar última palavra “$_suggestedLastWord” (checksum OK)',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _finish(forceInvalidChecksum: true),
                          child: Text(
                            context.tr.seedImportLiteralInvalidChecksum,
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _finish(),
                          child: Text(context.tr.seedImportWallet),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_inlineError != null && !_complete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _inlineError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: _complete
                    ? const SizedBox.shrink()
                    : _suggestions.isEmpty && _wordController.text.isNotEmpty
                    ? Center(
                        child: Text(
                          _inlineError ?? 'Palavra inválida',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: _suggestions.map((word) {
                          return GestureDetector(
                            onTap: () => _confirmWord(word),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                word,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              if (_selectedWords.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _undoLastWord,
                        child: Text(
                          context.tr.seedUndoPrevious,
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(_selectedWords.length, (index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              _obscureWords
                                  ? '${index + 1}.***'
                                  : '${index + 1}.${_selectedWords[index]}',
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WordCountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WordCountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          color: selected
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
