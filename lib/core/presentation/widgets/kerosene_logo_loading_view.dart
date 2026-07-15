import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';

const String _loadingLogoAssetPath = 'assets/logo/kerosene-k-logo.png';

class KeroseneLogoLoadingView extends StatefulWidget {
  final String status;
  final String detail;
  final bool isDelayed;
  final bool isError;
  final String? errorMessage;
  final double logoSize;

  const KeroseneLogoLoadingView({
    super.key,
    this.status = '',
    this.detail = '',
    this.isDelayed = false,
    this.isError = false,
    this.errorMessage,
    this.logoSize = 230,
  });

  @override
  State<KeroseneLogoLoadingView> createState() =>
      _KeroseneLogoLoadingViewState();
}

class _KeroseneLogoLoadingViewState extends State<KeroseneLogoLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KeroseneMotion.ceremonial,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_loadingLogoAssetPath), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final logoSize = math.min(
      widget.logoSize,
      math.max(148.0, availableWidth * 0.58),
    );
    final foregroundColor = widget.isError
        ? KeroseneBrandTokens.error
        : KeroseneBrandTokens.textPrimary;

    return Scaffold(
      backgroundColor: KeroseneBrandTokens.background,
      body: SafeArea(
        child: Center(
          child: KeroseneLogoLoadingMark(
            logoSize: logoSize,
            controller: _controller,
            foregroundColor: foregroundColor,
            showGlow: !widget.isError,
          ),
        ),
      ),
    );
  }

}

class KeroseneLogoLoadingMark extends StatelessWidget {
  final double logoSize;
  final Animation<double> controller;
  final Color foregroundColor;
  final bool showGlow;

  const KeroseneLogoLoadingMark({
    super.key,
    required this.logoSize,
    required this.controller,
    this.foregroundColor = KeroseneBrandTokens.textPrimary,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = controller.value;
            final reveal = _revealProgress(progress);
            final erase = _eraseProgress(progress);
            final glow = _glowOpacity(progress);

            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.10,
                  child: _KeroseneLoadingGlyph(
                    size: logoSize,
                    color: KeroseneBrandTokens.textPrimary,
                  ),
                ),
                ClipPath(
                  clipper: _DiagonalLogoClipper(
                    revealProgress: reveal,
                    eraseProgress: erase,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showGlow)
                        Opacity(
                          opacity: glow,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 12,
                              sigmaY: 12,
                            ),
                            child: _KeroseneLoadingGlyph(
                              size: logoSize,
                              color: KeroseneBrandTokens.info,
                            ),
                          ),
                        ),
                      _KeroseneLoadingGlyph(
                        size: logoSize,
                        color: foregroundColor,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _revealProgress(double value) {
    if (value < 0.56) {
      return KeroseneMotion.standard.transform(value / 0.56);
    }
    return 1.0;
  }

  double _eraseProgress(double value) {
    if (value < 0.74) return 0.0;
    return KeroseneMotion.standard.transform((value - 0.74) / 0.26);
  }

  double _glowOpacity(double value) {
    final pulse = math.sin(value * math.pi * 2);
    return showGlow ? 0.12 + (pulse + 1) * 0.10 : 0.0;
  }
}

class _KeroseneLoadingGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const _KeroseneLoadingGlyph({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_luminanceMaskMatrix(color)),
      child: Image.asset(
        _loadingLogoAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  List<double> _luminanceMaskMatrix(Color color) {
    final red = color.r * 255;
    final green = color.g * 255;
    final blue = color.b * 255;
    final alpha = color.a;

    return <double>[
      0,
      0,
      0,
      0,
      red,
      0,
      0,
      0,
      0,
      green,
      0,
      0,
      0,
      0,
      blue,
      0.2126 * alpha,
      0.7152 * alpha,
      0.0722 * alpha,
      0,
      0,
    ];
  }
}

class _DiagonalLogoClipper extends CustomClipper<Path> {
  final double revealProgress;
  final double eraseProgress;

  const _DiagonalLogoClipper({
    required this.revealProgress,
    required this.eraseProgress,
  });

  @override
  Path getClip(Size size) {
    final diagonal = size.width + size.height;
    final revealEdge = diagonal * revealProgress;
    final eraseEdge = diagonal * eraseProgress;
    const softness = 28.0;

    final bounds = Offset.zero & size;
    final revealed = _diagonalHalfPlane(size, revealEdge + softness);
    final erased = eraseProgress <= 0
        ? Path()
        : _diagonalHalfPlane(size, eraseEdge - softness);
    final visible = Path.combine(PathOperation.difference, revealed, erased);

    return Path.combine(
      PathOperation.intersect,
      Path()..addRect(bounds),
      visible,
    );
  }

  Path _diagonalHalfPlane(Size size, double edge) {
    return Path()
      ..moveTo(-size.width, -size.height)
      ..lineTo(edge + size.width, -size.height)
      ..lineTo(-size.width, edge + size.height)
      ..close();
  }

  @override
  bool shouldReclip(_DiagonalLogoClipper oldClipper) {
    return oldClipper.revealProgress != revealProgress ||
        oldClipper.eraseProgress != eraseProgress;
  }
}
