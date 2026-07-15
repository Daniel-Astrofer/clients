// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'package:flutter/cupertino.dart';
import 'package:bip39/bip39.dart' as bip39;

import 'package:kerosene/core/security/secure_screen_guard.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/movement/domain/payment_security_guards.dart';

import '../bitcoin_accounts_dependencies.dart';
import '../bitcoin_accounts_screen.dart';
import '../bitcoin_widgets/bottom_sheets.dart';
import 'cold_wallet_success_screen.dart';
import 'internal_account_creation_screen.dart';

class ColdWalletCreationScreen extends ConsumerStatefulWidget {
  final String? initialStepName;

  const ColdWalletCreationScreen({super.key, this.initialStepName});

  @override
  ConsumerState<ColdWalletCreationScreen> createState() =>
      ColdWalletCreationScreenState();
}

class ColdWalletCreationScreenState
    extends ConsumerState<ColdWalletCreationScreen> {
  final TextEditingController walletNameController = TextEditingController();
  final TextEditingController extraWordController = TextEditingController();
  final List<TextEditingController> verificationControllers = [];
  final deriver = const ColdWalletPublicMaterialDeriver();
  late final SecureSeedVisibility _seedVisibility;

  ColdWalletLevel level = ColdWalletLevel.recommended;
  late ColdWalletStep step;
  bool _secureScopeActive = false;

  @override
  void initState() {
    super.initState();
    _seedVisibility = SecureSeedVisibility(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _seedVisibility.attach();
    if (widget.initialStepName == 'prepare') {
      step = ColdWalletStep.prepare;
      walletNameController.text = 'Carteira fria';
    } else {
      step = ColdWalletStep.purpose;
    }
  }

  ColdWalletPublicMaterial? publicMaterial;
  List<int> verificationIndexes = const [];
  String mnemonic = '';
  bool paperReady = false;
  bool privatePlace = false;
  bool offlineReady = false;
  bool noPhotos = false;
  bool busy = false;

  bool get showWords => _seedVisibility.visible;

  bool get canGenerate =>
      walletNameController.text.trim().isNotEmpty &&
      paperReady &&
      privatePlace &&
      offlineReady &&
      noPhotos;

  String get walletLabel {
    final typed = walletNameController.text.trim();
    return typed.isEmpty ? 'Cold Wallet' : typed;
  }

  int activeColdWalletCountFrom(List<BitcoinAccount> accounts) {
    return accounts
        .where((account) => account.isActive && account.isWatchOnly)
        .length;
  }

  List<String> get words =>
      mnemonic.trim().isEmpty ? const [] : mnemonic.split(' ');

  @override
  void dispose() {
    _seedVisibility.detach();
    _leaveSecureScope();
    walletNameController.dispose();
    extraWordController.dispose();
    for (final controller in verificationControllers) {
      controller.dispose();
    }
    mnemonic = '';
    super.dispose();
  }

  void _enterSecureScope() {
    if (_secureScopeActive) return;
    _secureScopeActive = true;
    SecureScreenGuard.enter();
  }

  void _leaveSecureScope() {
    if (!_secureScopeActive) return;
    _secureScopeActive = false;
    SecureScreenGuard.leave();
  }

  void goBack() {
    if (busy) return;
    switch (step) {
      case ColdWalletStep.purpose:
        Navigator.maybePop(context);
        return;
      case ColdWalletStep.prepare:
        setState(() => step = ColdWalletStep.purpose);
        return;
      case ColdWalletStep.backup:
        discardGeneratedMaterial();
        setState(() => step = ColdWalletStep.prepare);
        return;
      case ColdWalletStep.verify:
        setState(() => step = ColdWalletStep.backup);
        return;
    }
  }

  void continueFromPurpose() {
    if (busy) return;
    final accounts = ref.read(bitcoinAccountsProvider).asData?.value ??
        const <BitcoinAccount>[];
    if (activeColdWalletCountFrom(accounts) >= maxActiveColdWallets) {
      AppNotice.showWarning(
        context,
        title: 'Carteira fria indisponivel',
        message: 'Voce pode criar no maximo duas carteiras frias.',
      );
      return;
    }
    if (walletNameController.text.trim().isEmpty) {
      AppNotice.showWarning(
        context,
        title: context.tr.createWalletNameRequired,
        message: 'Digite o nome que essa carteira fria deve receber.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => step = ColdWalletStep.prepare);
  }

  void discardGeneratedMaterial() {
    mnemonic = '';
    publicMaterial = null;
    _seedVisibility.hide();
    _leaveSecureScope();
    verificationIndexes = const [];
    for (final controller in verificationControllers) {
      controller.dispose();
    }
    verificationControllers.clear();
  }

  void generateColdWallet() {
    if (!canGenerate) {
      return;
    }
    final strength = level.wordCount == 12 ? 128 : 256;
    final generatedMnemonic = bip39.generateMnemonic(strength: strength);
    final generatedPublicMaterial = deriver.derive(
      mnemonic: generatedMnemonic,
      extraWord: level.usesExtraWord ? extraWordController.text : '',
      derivationPath: appColdWalletDerivationPath,
    );
    _enterSecureScope();
    _seedVisibility.hide();
    setState(() {
      mnemonic = generatedMnemonic;
      publicMaterial = generatedPublicMaterial;
      step = ColdWalletStep.backup;
    });
    HapticFeedback.mediumImpact();
  }

  void startVerification() {
    final mnemonicWords = words;
    // Three distinct random indices (more robust than fixed 0 / mid / last).
    final indexes = _pickVerificationIndexes(mnemonicWords.length);
    for (final controller in verificationControllers) {
      controller.dispose();
    }
    verificationControllers
      ..clear()
      ..addAll(List.generate(indexes.length, (_) => TextEditingController()));
    _seedVisibility.hide();
    setState(() {
      verificationIndexes = indexes;
      step = ColdWalletStep.verify;
    });
  }

  List<int> _pickVerificationIndexes(int wordCount) {
    if (wordCount <= 0) return const [];
    if (wordCount <= 3) {
      return List<int>.generate(wordCount, (i) => i);
    }
    final pool = List<int>.generate(wordCount, (i) => i)..shuffle();
    final picked = pool.take(3).toList()..sort();
    return picked;
  }

  bool verificationMatches() {
    final mnemonicWords = words;
    if (mnemonicWords.isEmpty ||
        verificationControllers.length != verificationIndexes.length) {
      return false;
    }
    for (var index = 0; index < verificationIndexes.length; index++) {
      final wordIndex = verificationIndexes[index];
      final typed = verificationControllers[index].text.trim().toLowerCase();
      if (typed != mnemonicWords[wordIndex].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  Future<void> importWatchOnly() async {
    if (publicMaterial == null || !verificationMatches()) {
      AppNotice.showWarning(
        context,
        title: context.tr.coldWalletVerifyFailedTitle,
        message: context.tr.coldWalletVerifyFailedMessage,
      );
      return;
    }

    setState(() => busy = true);
    try {
      final seedToStore = mnemonic.trim().toLowerCase();
      final passphraseToStore =
          level.usesExtraWord ? extraWordController.text.trim() : '';
      final useCase = RegisterColdWalletUseCase(
        importColdWallet: ref.read(bitcoinAccountsProvider.notifier).importColdWallet,
      );
      final result = await useCase.registerFromMnemonic(
        label: walletLabel,
        mnemonic: seedToStore,
        passphrase: passphraseToStore,
        derivationPath: appColdWalletDerivationPath,
        storeSeed: true,
      );
      mnemonic = '';
      extraWordController.clear();
      _leaveSecureScope();
      if (!mounted) return;
      // Replace wizard with success (Enviar / Concluir). Hub awaits outcome.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<ColdWalletFlowOutcome>(
          builder: (_) => ColdWalletSuccessScreen(
            result: result,
            walletLabel: walletLabel,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: context.tr.coldWalletImportErrorTitle,
        message: coldWalletRegisterErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (step == ColdWalletStep.purpose) {
      return buildPurposeScaffold();
    }

    final responsive = context.responsive;
    final colors = BitcoinAccountsColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                responsive.horizontalPadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: busy ? null : goBack,
                    icon: Icon(
                      KeroseneIcons.chevronLeft,
                      color: colors.text,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.tr.coldWalletCreateTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.text,
                            fontSize: responsive.compactFontSize(
                              tiny: 19,
                              compact: 21,
                              regular: 22,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  AppSpacing.sm,
                  responsive.horizontalPadding,
                  AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: responsive.mobileContentMaxWidth,
                    ),
                    child: switch (step) {
                      ColdWalletStep.purpose => const SizedBox.shrink(),
                      ColdWalletStep.prepare => buildPrepare(),
                      ColdWalletStep.backup => buildBackup(),
                      ColdWalletStep.verify => buildVerify(),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPurposeScaffold() {
    final colors = BitcoinAccountsColors.of(context);
    final accounts = ref.watch(bitcoinAccountsProvider).asData?.value ??
        const <BitcoinAccount>[];
    final coldWalletLimitReached =
        activeColdWalletCountFrom(accounts) >= maxActiveColdWallets;
    final introLabel =
        'A Kerosene guarda apenas o material público para acompanhar saldo on-chain. '
        'A semente fica só neste aparelho. Rede: ${coldWalletNetworkLabel(expectedBitcoinNetwork)}.';
    const title = 'Nomeie sua carteira fria';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.isLight ? colors.background : Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: goBack,
                  icon: Icon(
                    KeroseneIcons.back,
                    color: colors.text,
                    size: 24,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CreationTitle(title),
                    const SizedBox(height: 16),
                    Text(
                      introLabel,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        color: colors.mutedText,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                    if (coldWalletLimitReached) ...[
                      const SizedBox(height: 16),
                      const ColdWalletInlineNotice(
                        text:
                            'Voce ja possui duas carteiras frias ativas. Arquive uma delas para criar outra.',
                      ),
                    ],
                    const SizedBox(height: 32),
                    WalletCreationLineTextField(
                      controller: walletNameController,
                      label: 'Nome da carteira',
                      hintText: context.tr.coldWalletNameLabel,
                      onSubmitted: (_) => continueFromPurpose(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.viewInsetsOf(context).bottom > 0 ? 20 : 40,
              ),
              child: CreationPrimaryButton(
                label: 'Continuar',
                onPressed: coldWalletLimitReached ? null : continueFromPurpose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPrepare() {
    final colors = BitcoinAccountsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(context.tr.coldWalletSecurityLevelTitle),
        for (final option in ColdWalletLevel.values)
          ColdWalletLevelTile(
            level: option,
            selected: option == level,
            onTap: () => setState(() => level = option),
          ),
        if (level.usesExtraWord) ...[
          const SizedBox(height: AppSpacing.md),
          WalletCreationLineTextField(
            controller: extraWordController,
            obscureText: true,
            label: context.tr.coldWalletExtraWordLabel,
            hintText: context.tr.coldWalletExtraWordHint,
          ),
          const SizedBox(height: AppSpacing.sm),
          ColdWalletInlineNotice(text: context.tr.coldWalletExtraWordWarning),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(context.tr.coldWalletChecklistTitle),
        ChecklistTile(
          value: paperReady,
          text: context.tr.coldWalletChecklistPaper,
          onChanged: (value) => setState(() => paperReady = value),
        ),
        ChecklistTile(
          value: privatePlace,
          text: context.tr.coldWalletChecklistPrivate,
          onChanged: (value) => setState(() => privatePlace = value),
        ),
        ChecklistTile(
          value: offlineReady,
          text: context.tr.coldWalletChecklistOffline,
          onChanged: (value) => setState(() => offlineReady = value),
        ),
        ChecklistTile(
          value: noPhotos,
          text: context.tr.coldWalletChecklistNoPhotos,
          onChanged: (value) => setState(() => noPhotos = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: colors.filledButtonStyle(),
          onPressed: canGenerate ? generateColdWallet : null,
          icon: const Icon(KeroseneIcons.passkey, size: 18),
          label: Text(context.tr.coldWalletGenerateAction),
        ),
      ],
    );
  }

  Widget buildBackup() {
    final colors = BitcoinAccountsColors.of(context);
    final visibleWords = words.asMap().entries.map(
          (entry) => SeedWordBadge(
            index: entry.key + 1,
            word: entry.value,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      showWords ? KeroseneIcons.eye : KeroseneIcons.eyeOff,
                      color: colors.mutedText,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.coldWalletBackupTitle,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            level.title(context),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.mutedText,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr.coldWalletBackupSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.mutedText,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (showWords)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visibleWords.toList(),
                  )
                else
                  ColdWalletInlineNotice(
                      text: context.tr.coldWalletWordsHidden),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  style: colors.outlinedButtonStyle(),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _seedVisibility.toggle();
                  },
                  icon: Icon(
                      showWords ? KeroseneIcons.eyeOff : KeroseneIcons.eye),
                  label: Text(
                    showWords
                        ? context.tr.coldWalletHideWords
                        : context.tr.coldWalletShowWords,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: colors.filledButtonStyle(),
          onPressed: showWords ? startVerification : null,
          icon: const Icon(KeroseneIcons.success, size: 18),
          label: Text(context.tr.coldWalletBackupDoneAction),
        ),
      ],
    );
  }

  Widget buildVerify() {
    final colors = BitcoinAccountsColors.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge(verificationControllers),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColdWalletInlineNotice(text: context.tr.coldWalletVerifySubtitle),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0;
                index < verificationIndexes.length;
                index++) ...[
              WalletCreationLineTextField(
                controller: verificationControllers[index],
                label: context.tr.coldWalletVerifyWordLabel(
                  verificationIndexes[index] + 1,
                ),
                hintText: 'palavra ${verificationIndexes[index] + 1}',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton.icon(
              style: colors.filledButtonStyle(),
              onPressed:
                  busy || !verificationMatches() ? null : importWatchOnly,
              icon: busy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : const Icon(KeroseneIcons.security, size: 18),
              label: Text(
                busy
                    ? context.tr.coldWalletImportingAction
                    : context.tr.coldWalletImportAction,
              ),
            ),
          ],
        ); // end of Column
      },
    );
  }
}

class ColdWalletInlineNotice extends StatelessWidget {
  final String text;

  const ColdWalletInlineNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.borderStrong, width: 1.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
        child: Text(
          text,
          style: AppTypography.inter(
            color: colors.mutedText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class ColdWalletLevelTile extends StatelessWidget {
  final ColdWalletLevel level;
  final bool selected;
  final VoidCallback onTap;

  const ColdWalletLevelTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border(
                bottom: BorderSide(color: colors.divider),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? KeroseneIcons.success : KeroseneIcons.circle,
                  color: selected ? colors.text : colors.mutedText,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.title(context),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level.body(context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChecklistTile extends StatelessWidget {
  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;

  const ChecklistTile({
    required this.value,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.divider),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
              activeColor: colors.text,
              checkColor: colors.filledButtonForeground,
              side: BorderSide(color: colors.borderStrong),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.mutedText,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeedWordBadge extends StatelessWidget {
  final int index;
  final String word;

  const SeedWordBadge({required this.index, required this.word});

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              index.toString().padLeft(2, '0'),
              style: AppTypography.technicalMono(
                textStyle: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.faintText),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              word,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
