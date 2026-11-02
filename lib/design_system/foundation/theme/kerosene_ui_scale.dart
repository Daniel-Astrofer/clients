import 'package:flutter/widgets.dart';

/// Presentation density shared by every client route and overlay.
/// Does not resize controls, QR codes, images or the viewport.
class KeroseneUiScale extends StatelessWidget {
  // Normal density restored at the user's request.
  static const factor = 1.0;
  final Widget child;
  const KeroseneUiScale({super.key, required this.child});

  static bool isActive(BuildContext context) =>
      factor != 1.0 && MediaQuery.textScalerOf(context) is KeroseneTextScaler;

  static Widget icon(BuildContext context, Widget child) =>
      isActive(context) ? Transform.scale(scale: factor, child: child) : child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.textScaler is KeroseneTextScaler) {
      return child;
    }
    return MediaQuery(
      data: media.copyWith(textScaler: KeroseneTextScaler(media.textScaler)),
      child: child,
    );
  }
}

/// Composes with the system scaler, including nonlinear accessibility scaling.
class KeroseneTextScaler extends TextScaler {
  final TextScaler inherited;
  const KeroseneTextScaler(this.inherited);

  @override
  double scale(double fontSize) =>
      inherited.scale(fontSize) * KeroseneUiScale.factor;

  @override
  double get textScaleFactor => scale(14) / 14;
}
