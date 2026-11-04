import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/components/generic/kerosene_logo.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import '../../controller/auth_controller.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _phoneMockupAsset = 'assets/welcome_phone_mockup.png';
  bool _openingRoute = false;

  Future<void> _open(String route) async {
    if (_openingRoute) return;
    HapticFeedback.selectionClick();
    setState(() => _openingRoute = true);
    try {
      await context.push<void>(route);
    } finally {
      if (mounted) setState(() => _openingRoute = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_phoneMockupAsset), context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      if (next is AuthAuthenticated && mounted) {
        context.go('/home_loading');
      }
    });

    final colors = KeroseneBrandTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: context.responsive.formConstraints,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      child: AuthMotionStagger(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _WelcomeHeader(),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: (constraints.maxHeight * 0.32)
                                .clamp(180.0, 320.0)
                                .toDouble(),
                            child: const Center(child: _PhoneHeroImage()),
                          ),
                          const SizedBox(height: 28),
                          _WelcomeActions(
                            onCreateAccount:
                                _openingRoute ? null : () => _open('/signup'),
                            onSignIn:
                                _openingRoute ? null : () => _open('/login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final colors = KeroseneBrandTheme.of(context);
    final titleSize = context.responsive.isTinyPhone ? 24.0 : 28.0;
    return Column(
      children: [
        KeroseneLogo(
          size: context.responsive.isTinyPhone ? 36.0 : 42.0,
          showText: false,
          color: colors.textPrimary,
        ),
        const SizedBox(height: 20),
        Text(
          'Praticidade e segurança para gastar em bitcoin onde quiser.',
          textAlign: TextAlign.center,
          style: AppTypography.playfairDisplay(
            color: colors.textPrimary,
            fontSize: titleSize,
            fontWeight: AppTypography.w510,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Fomos projetados há oferecer praticidade e segurança em um unico lugar.',
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PhoneHeroImage extends StatelessWidget {
  const _PhoneHeroImage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize =
            constraints.biggest.shortestSide.clamp(0.0, 340.0).toDouble();

        final dpr = MediaQuery.devicePixelRatioOf(context);
        final targetCacheSize = (imageSize * dpr).round();

        // The existing illustration depicts the dark interface. Keep its
        // background intentional in both themes and remove legacy rail colors.
        return RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: Colors.black,
              child: Image.asset(
                _WelcomeScreenState._phoneMockupAsset,
                width: imageSize,
                height: imageSize,
                cacheWidth: targetCacheSize > 0 ? targetCacheSize : null,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                color: Colors.grey,
                colorBlendMode: BlendMode.saturation,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = KeroseneBrandTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WelcomeButton(
          label: context.tr.welcomeCreateAccountButton,
          onPressed: onCreateAccount,
          backgroundColor: colors.textPrimary,
          foregroundColor: colors.background,
          borderColor: colors.textPrimary,
        ),
        const SizedBox(height: 14),
        _WelcomeButton(
          label: context.tr.welcomeAlreadyHaveAccountButton,
          onPressed: onSignIn,
          backgroundColor: Colors.transparent,
          foregroundColor: colors.textPrimary,
          borderColor: colors.border,
        ),
      ],
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Color.alphaBlend(
                foregroundColor.withValues(alpha: 0.08),
                backgroundColor,
              );
            }
            return backgroundColor;
          }),
          foregroundColor: WidgetStateProperty.all(foregroundColor),
          overlayColor: WidgetStateProperty.all(
            foregroundColor.withValues(alpha: 0.08),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: borderColor),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            AppTypography.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
