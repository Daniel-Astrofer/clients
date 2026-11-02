import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../receive/receive_flow_title_bar.dart';

/// Links supplied for this session. The API supplies no price, payment methods,
/// destination, reservation or payment confirmation; none are inferred here.
class GatewayLinksSnapshot {
  final Map<String, String> urls;
  final DateTime loadedAt;

  GatewayLinksSnapshot(Map<String, String> urls, this.loadedAt)
      : urls = Map.unmodifiable(urls);
}

/// Disposed with the purchase surface so links do not survive between visits.
final receiveGatewayLinksProvider =
    FutureProvider.autoDispose<GatewayLinksSnapshot>((ref) async {
  final owner = ref.watch(sessionStorageScopeProvider)?.trim();
  if (owner == null || owner.isEmpty) {
    throw StateError('No active session for checkout links.');
  }
  final result = await ref.watch(transactionRepositoryProvider).getOnrampUrls();
  if (!ref.mounted || ref.read(sessionStorageScopeProvider)?.trim() != owner) {
    throw StateError('Checkout session changed.');
  }
  return result.fold(
    (failure) => throw Exception(failure.message),
    (urls) => GatewayLinksSnapshot(urls, DateTime.now()),
  );
});

/// External purchase checkout; opening a link never acknowledges a payment.
class ReceiveGatewayProvidersScreen extends ConsumerStatefulWidget {
  final Wallet wallet;

  const ReceiveGatewayProvidersScreen({super.key, required this.wallet});

  @override
  ConsumerState<ReceiveGatewayProvidersScreen> createState() =>
      _ReceiveGatewayProvidersState();
}

class _ReceiveGatewayProvidersState
    extends ConsumerState<ReceiveGatewayProvidersScreen> {
  GatewayLinksSnapshot? _lastLoaded;
  bool _detailsOpen = false;
  String? _openedProvider;
  late final String? _ownerScope;
  bool _scopeLost = false;

  bool get _ownsSession =>
      mounted &&
      !_scopeLost &&
      _ownerScope?.isNotEmpty == true &&
      ref.read(sessionStorageScopeProvider)?.trim() == _ownerScope;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider)?.trim();
    ref.listenManual(sessionStorageScopeProvider, (_, next) {
      if (mounted && !_scopeLost && next?.trim() != _ownerScope) {
        setState(() {
          _scopeLost = true;
          _lastLoaded = null;
          _openedProvider = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    if (!_ownsSession) {
      return Scaffold(
        body: ReceiveFlowScreenShell(
          onBack: () => Navigator.of(context).maybePop(),
          title: context.tr.receiveGatewayProvidersTitle,
          child: const _GatewaySessionChanged(),
        ),
      );
    }
    final state = ref.watch(receiveGatewayLinksProvider);
    if (state.value != null) _lastLoaded = state.value;
    final snapshot = _lastLoaded;
    final entries = snapshot?.urls.entries
            .where((entry) => entry.value.trim().isNotEmpty)
            .toList() ??
        [];
    final theme = Theme.of(context);
    return Scaffold(
      body: ReceiveFlowScreenShell(
        onBack: () => Navigator.of(context).maybePop(),
        title: context.tr.receiveGatewayProvidersTitle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text(context.tr.gatewayLinksSubtitle,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            _GatewayDataRow(
                label: context.tr.gatewaySelectedWallet,
                value: widget.wallet.name),
            if (_openedProvider != null) ...[
              const SizedBox(height: 16),
              _GatewayStatus(
                icon: KeroseneIcons.info,
                text: context.tr.gatewayExternalPending(_openedProvider!),
              ),
            ],
            const SizedBox(height: 20),
            if (snapshot != null)
              Text(
                context.tr.gatewayUpdatedAt(
                    AppDateTime.formatFull(context, snapshot.loadedAt)),
                style: theme.textTheme.bodySmall,
              ),
            if (state.isLoading)
              _GatewayStatus(
                  icon: KeroseneIcons.refresh, text: context.tr.gatewayLoading),
            if (state.hasError)
              _GatewayStatus(
                  icon: KeroseneIcons.error,
                  text: snapshot == null
                      ? context.tr.gatewayLoadFailed
                      : context.tr.gatewayStale),
            if (!state.isLoading && !state.hasError && entries.isEmpty)
              _GatewayStatus(
                  icon: KeroseneIcons.info, text: context.tr.gatewayEmpty),
            const SizedBox(height: 16),
            for (final entry in entries) ...[
              _GatewayLinkTile(
                name: _providerName(entry.key),
                uri: _checkoutUri(entry.value),
                enabled: !state.isLoading && !state.hasError,
                onTap: () => _showDetails(entry),
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              key: const ValueKey('gateway-refresh'),
              label: context.tr.gatewayRefresh,
              variant: AppButtonVariant.secondary,
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (_ownsSession) {
                        ref.invalidate(receiveGatewayLinksProvider);
                      }
                    },
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(MapEntry<String, String> entry) async {
    final uri = _checkoutUri(entry.value);
    if (!_ownsSession || _detailsOpen || uri == null) {
      return;
    }
    final links = ref.read(receiveGatewayLinksProvider);
    if (links.isLoading ||
        links.hasError ||
        links.value?.urls[entry.key] != entry.value) {
      return;
    }
    _detailsOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 560),
        sheetAnimationStyle: AnimationStyle(
          duration: KeroseneMotion.duration(context, KeroseneMotion.short),
          reverseDuration:
              KeroseneMotion.duration(context, KeroseneMotion.short),
        ),
        builder: (_) => _GatewayCheckoutDetails(
          name: _providerName(entry.key),
          uri: uri,
          rawUrl: entry.value.trim(),
          wallet: widget.wallet,
          ownsSession: () => _ownsSession,
          onOpened: () {
            if (_ownsSession) {
              setState(() => _openedProvider = _providerName(entry.key));
            }
          },
        ),
      );
    } finally {
      _detailsOpen = false;
    }
  }
}

Uri? _checkoutUri(String raw) {
  final text = raw.trim();
  if (RegExp(r'\s|[\x00-\x1f\x7f]').hasMatch(text)) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

String _providerName(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return switch (normalized) {
    'mercadopago' => 'Mercado Pago',
    'moonpay' => 'MoonPay',
    'banxa' => 'Banxa',
    'mercuryo' => 'Mercuryo',
    'ramp' || 'rampnetwork' => 'Ramp Network',
    'stripe' || 'stripecryptoonramp' || 'stripeonramp' => 'Stripe',
    'coinbase' || 'coinbaseonramp' => 'Coinbase',
    'onramper' => 'Onramper',
    'transak' => 'Transak',
    'wert' => 'Wert',
    'gatefi' || 'unlimit' || 'gatefiunlimit' => 'GateFi / Unlimit',
    _ => key,
  };
}

class _GatewayLinkTile extends StatelessWidget {
  final String name;
  final Uri? uri;
  final bool enabled;
  final VoidCallback onTap;

  const _GatewayLinkTile(
      {required this.name,
      required this.uri,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.dividerColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled && uri != null ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            KeroseneIcon(
                uri == null ? KeroseneIcons.error : KeroseneIcons.globe),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(uri?.host ?? context.tr.gatewayInvalidLink,
                      textDirection: uri == null ? null : TextDirection.ltr,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (uri != null) ...[
              const SizedBox(width: 8),
              const KeroseneIcon(KeroseneIcons.chevronRight, size: 18),
            ],
          ]),
        ),
      ),
    );
  }
}

class _GatewayCheckoutDetails extends ConsumerStatefulWidget {
  final String name;
  final Uri uri;
  final String rawUrl;
  final Wallet wallet;
  final VoidCallback onOpened;
  final bool Function() ownsSession;

  const _GatewayCheckoutDetails(
      {required this.name,
      required this.uri,
      required this.rawUrl,
      required this.wallet,
      required this.ownsSession,
      required this.onOpened});

  @override
  ConsumerState<_GatewayCheckoutDetails> createState() =>
      _GatewayCheckoutDetailsState();
}

class _GatewayCheckoutDetailsState
    extends ConsumerState<_GatewayCheckoutDetails> {
  bool _opening = false;
  bool _copying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.listenManual(sessionStorageScopeProvider, (_, __) {
      if (!widget.ownsSession()) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _closeOwnRoute());
      }
    });
  }

  void _closeOwnRoute() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route?.isCurrent == true) {
      navigator.pop();
    } else if (route?.isActive == true) {
      navigator.removeRoute(route!);
    }
  }

  Future<void> _open() async {
    if (_opening || !widget.ownsSession()) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    var opened = false;
    try {
      opened =
          await launchUrl(widget.uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A failed platform acknowledgement remains visible and can be retried.
    }
    if (!widget.ownsSession()) return;
    if (opened) {
      widget.onOpened();
      _closeOwnRoute();
    } else if (mounted) {
      setState(() {
        _opening = false;
        _error = context.tr.gatewayOpenFailed;
      });
    }
  }

  Future<void> _copy() async {
    if (_copying || !widget.ownsSession()) return;
    setState(() {
      _copying = true;
      _error = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: widget.rawUrl));
      if (mounted && widget.ownsSession()) {
        AppNotice.showSuccess(context,
            message: context.tr.gatewayCheckoutLinkCopied);
      }
    } catch (_) {
      if (mounted && widget.ownsSession()) {
        setState(() => _error = context.tr.copyDataFailed);
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    if (!widget.ownsSession()) return const _GatewaySessionChanged();
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr.gatewayCheckoutTitle,
              style: AppTypography.playfairDisplay(
                  fontSize: 24, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 20),
          _GatewayDataRow(
              label: context.tr.gatewayProvider, value: widget.name),
          _GatewayDataRow(
              label: context.tr.gatewaySelectedWallet,
              value: widget.wallet.name),
          _GatewayDataRow(
              label: context.tr.gatewayWalletReference,
              value: widget.wallet.id,
              technical: true),
          _GatewayDataRow(
              label: context.tr.gatewayDomain,
              value: widget.uri.host,
              technical: true),
          _GatewayDataRow(
              label: context.tr.gatewayFullLink,
              value: widget.rawUrl,
              technical: true),
          const SizedBox(height: 16),
          Text(context.tr.gatewayCheckoutTerms,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          _GatewayStatus(
              icon: KeroseneIcons.info,
              text: context.tr.gatewayDestinationUnconfirmed),
          if (_error != null)
            _GatewayStatus(icon: KeroseneIcons.error, text: _error!),
          const SizedBox(height: 20),
          AppButton(
              key: const ValueKey('gateway-open-checkout'),
              label: context.tr.gatewayOpen,
              onPressed: _open,
              loading: _opening,
              expand: true),
          const SizedBox(height: 12),
          AppButton(
              key: const ValueKey('gateway-copy-checkout'),
              label: context.tr.gatewayCopy,
              onPressed: _copy,
              loading: _copying,
              variant: AppButtonVariant.secondary,
              expand: true),
        ],
      ),
    );
  }
}

class _GatewaySessionChanged extends StatelessWidget {
  const _GatewaySessionChanged();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const KeroseneIcon(KeroseneIcons.lock, size: 28),
        const SizedBox(height: 16),
        Text(context.tr.securitySessionChangedMessage,
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ]),
    );
  }
}

class _GatewayDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool technical;

  const _GatewayDataRow(
      {required this.label, required this.value, this.technical = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SelectableText(value,
              textDirection: technical ? TextDirection.ltr : null,
              style: technical
                  ? AppTypography.technicalMono(
                      fontSize: 13, color: theme.colorScheme.onSurface)
                  : theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _GatewayStatus extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GatewayStatus({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KeroseneIcon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
