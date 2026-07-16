import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/icons.dart';

/// Visual tone for education / event dialogs on the dark home surface.
enum KeroseneEducationTone {
  info,
  success,
  warning,
  security,
}

/// Shared dark education dialog (TOTP tips, receive confirmations, etc.).
class KeroseneEducationDialog extends StatelessWidget {
  final IconData icon;
  final KeroseneEducationTone tone;
  final String title;
  final String body;
  final List<String> bullets;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String? footerNote;

  const KeroseneEducationDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.tone = KeroseneEducationTone.info,
    this.bullets = const [],
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.footerNote,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String body,
    required String primaryLabel,
    KeroseneEducationTone tone = KeroseneEducationTone.info,
    List<String> bullets = const [],
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    String? footerNote,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: KeroseneMotion.medium,
      pageBuilder: (ctx, anim, secondary) {
        return KeroseneEducationDialog(
          icon: icon,
          tone: tone,
          title: title,
          body: body,
          bullets: bullets,
          primaryLabel: primaryLabel,
          secondaryLabel: secondaryLabel,
          footerNote: footerNote,
          onPrimary: () {
            Navigator.of(ctx).pop(true);
            onPrimary?.call();
          },
          onSecondary: () {
            Navigator.of(ctx).pop(false);
            onSecondary?.call();
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: KeroseneMotion.standard,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Color get _accent {
    return switch (tone) {
      KeroseneEducationTone.success => KeroseneBrandTokens.success,
      KeroseneEducationTone.warning => KeroseneBrandTokens.warning,
      KeroseneEducationTone.security => const Color(0xFF7DD3FC),
      KeroseneEducationTone.info => KeroseneBrandTokens.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: accent, size: 26),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: AppTypography.display.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontFamily: AppTypography.bodyFontFamily,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (bullets.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      for (final bullet in bullets) ...[
                        _BulletRow(text: bullet, accent: accent),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (footerNote != null && footerNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        footerNote!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontFamily: AppTypography.bodyFontFamily,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onPrimary?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          onSecondary?.call();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.72),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(secondaryLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  final Color accent;

  const _BulletRow({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontFamily: AppTypography.bodyFontFamily,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Convenience: TOTP education copy (pt-first with simple locale switch).
Future<bool?> showTotpEducationDialog(BuildContext context) {
  final lang = Localizations.localeOf(context).languageCode;
  final title = switch (lang) {
    'en' => 'Protect your account with TOTP',
    'es' => 'Protege tu cuenta con TOTP',
    _ => 'Proteja sua conta com TOTP',
  };
  final body = switch (lang) {
    'en' =>
      'TOTP (Time-based One-Time Password) is a code that changes every few seconds in an authenticator app (Google Authenticator, Authy, etc.). Even if someone steals your password, they still need that phone code.',
    'es' =>
      'TOTP (contraseña de un solo uso basada en tiempo) es un código que cambia cada pocos segundos en una app autenticadora (Google Authenticator, Authy, etc.). Aunque roben tu contraseña, aún necesitan ese código del teléfono.',
    _ =>
      'TOTP (senha de uso único baseada em tempo) é um código que muda a cada poucos segundos no app autenticador (Google Authenticator, Authy, etc.). Mesmo que alguém descubra sua senha, ainda precisa do código do celular.',
  };
  final bullets = switch (lang) {
    'en' => const [
        'Works offline — no SMS that can be intercepted',
        'Required for sensitive actions and stronger account recovery',
        'Takes about a minute to set up',
      ],
    'es' => const [
        'Funciona sin conexión — sin SMS interceptables',
        'Refuerza acciones sensibles y la recuperación de la cuenta',
        'Se configura en cerca de un minuto',
      ],
    _ => const [
        'Funciona offline — sem SMS que possam ser interceptados',
        'Reforça ações sensíveis e a recuperação da conta',
        'Leva cerca de um minuto para ativar',
      ],
  };
  final primary = switch (lang) {
    'en' => 'Enable TOTP',
    'es' => 'Activar TOTP',
    _ => 'Ativar TOTP',
  };
  final secondary = switch (lang) {
    'en' => 'Not now',
    'es' => 'Ahora no',
    _ => 'Agora não',
  };
  final footer = switch (lang) {
    'en' => 'You can enable this anytime in Settings → Security.',
    'es' => 'Puedes activarlo cuando quieras en Ajustes → Seguridad.',
    _ => 'Você pode ativar quando quiser em Configurações → Segurança.',
  };

  return KeroseneEducationDialog.show(
    context: context,
    icon: KeroseneIcons.shield,
    tone: KeroseneEducationTone.security,
    title: title,
    body: body,
    bullets: bullets,
    primaryLabel: primary,
    secondaryLabel: secondary,
    footerNote: footer,
  );
}

/// Incoming funds celebration / confirmation dialog.
Future<bool?> showIncomingTransferDialog(
  BuildContext context, {
  required String amountLabel,
  required String walletName,
  required String networkLabel,
  String? subtitle,
}) {
  final lang = Localizations.localeOf(context).languageCode;
  final title = switch (lang) {
    'en' => 'You received funds',
    'es' => 'Recibiste fondos',
    _ => 'Você recebeu fundos',
  };
  final body = switch (lang) {
    'en' =>
      'Your wallet “$walletName” just received $amountLabel via $networkLabel.${subtitle == null || subtitle.isEmpty ? '' : '\n\n$subtitle'}',
    'es' =>
      'Tu cartera “$walletName” recibió $amountLabel por $networkLabel.${subtitle == null || subtitle.isEmpty ? '' : '\n\n$subtitle'}',
    _ =>
      'Sua carteira “$walletName” recebeu $amountLabel via $networkLabel.${subtitle == null || subtitle.isEmpty ? '' : '\n\n$subtitle'}',
  };
  final primary = switch (lang) {
    'en' => 'View activity',
    'es' => 'Ver actividad',
    _ => 'Ver atividade',
  };
  final secondary = switch (lang) {
    'en' => 'Close',
    'es' => 'Cerrar',
    _ => 'Fechar',
  };

  return KeroseneEducationDialog.show(
    context: context,
    icon: KeroseneIcons.receive,
    tone: KeroseneEducationTone.success,
    title: title,
    body: body,
    primaryLabel: primary,
    secondaryLabel: secondary,
    footerNote: switch (lang) {
      'en' => 'On-chain funds may still need confirmations before they settle.',
      'es' =>
        'Los fondos on-chain pueden necesitar confirmaciones antes de liquidarse.',
      _ =>
        'Fundos on-chain podem precisar de confirmações antes de liquidar.',
    },
  );
}
