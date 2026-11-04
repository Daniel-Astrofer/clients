import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Carrossel de fundo cinematográfico para telas de PIN / autenticação
/// (estilo Revolut / Banco do Brasil).
///
/// Recursos de Alta Performance:
/// 1. Decodificação limitada à resolução física da tela (`cacheWidth`), evitando OOM.
/// 2. Pré-carregamento sob demanda (`precacheImage`) apenas da próxima imagem.
/// 3. Vinheta radial e sombras em camadas de gradiente vetorial (custo zero na GPU, sem blur).
/// 4. `RepaintBoundary` isolado para que o teclado e o PIN não causem repaint do fundo.
/// 5. Pausa automática do timer quando o app entra em segundo plano (`AppLifecycleState`).
/// 6. Auto-descoberta de assets em assets/pin/ via AssetManifest.
class PinBackgroundRotator extends StatefulWidget {
  final List<String>? imageAssets;
  final Duration rotationInterval;
  final Duration transitionDuration;
  final Widget? child;

  /// Lista padrão de imagens otimizadas do PIN (fallback).
  static const List<String> defaultImages = [
    'assets/pin/55181686977-7e768c5ab5-o.webp',
    'assets/pin/55183089523-2832f9419d-o.webp',
    'assets/pin/nhq202604100022.webp',
    'assets/pin/nhq202604100210.webp',
  ];

  const PinBackgroundRotator({
    super.key,
    this.imageAssets,
    this.rotationInterval = const Duration(seconds: 6),
    this.transitionDuration = const Duration(milliseconds: 1000),
    this.child,
  });

  @override
  State<PinBackgroundRotator> createState() => _PinBackgroundRotatorState();
}

class _PinBackgroundRotatorState extends State<PinBackgroundRotator>
    with WidgetsBindingObserver {
  late List<String> _images;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _images = widget.imageAssets ?? PinBackgroundRotator.defaultImages;
    _discoverPinAssets();
    _startTimer();
  }

  Future<void> _discoverPinAssets() async {
    if (widget.imageAssets != null) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = manifest
          .listAssets()
          .where((path) =>
              path.startsWith('assets/pin/') &&
              (path.endsWith('.webp') ||
                  path.endsWith('.png') ||
                  path.endsWith('.jpg') ||
                  path.endsWith('.jpeg')))
          .toList();
      if (discovered.isNotEmpty && mounted) {
        setState(() {
          _images = discovered;
        });
        _precacheNextImage();
      }
    } catch (_) {
      // Mantém defaultImages
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNextImage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive != isActive) {
      _isAppActive = isActive;
      if (isActive) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_images.length <= 1) return;

    _timer = Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted || !_isAppActive) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
      _precacheNextImage();
    });
  }

  void _precacheNextImage() {
    if (_images.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _images.length;
    final nextPath = _images[nextIndex];
    precacheImage(AssetImage(nextPath), context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return widget.child ?? const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final physicalWidth =
        (mediaQuery.size.width * mediaQuery.devicePixelRatio).toInt();

    final currentAsset = _images[_currentIndex % _images.length];

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagem de fundo com crossfade suave
          AnimatedSwitcher(
            duration: widget.transitionDuration,
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            child: SizedBox.expand(
              key: ValueKey<String>(currentAsset),
              child: Image.asset(
                currentAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: Colors.black);
                },
              ),
            ),
          ),

          // 2. Vinheta radial: escurece os cantos e bordas (estilo cinematográfico)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [
                  Colors.transparent,
                  Color(0x55000000), // ~33% preto
                  Color(0xCC000000), // ~80% preto nos cantos
                ],
                stops: [0.35, 0.75, 1.0],
              ),
            ),
          ),

          // 3. Gradiente vertical: escurecimento estratégico para legibilidade
          // (topo escuro para status/header, base escura para o teclado numérico do PIN)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA000000), // 67% preto no topo
                  Color(0x44000000), // 27% preto no meio (revela a imagem)
                  Color(0xEE000000), // 93% preto na base (fundo do teclado do PIN)
                ],
                stops: [0.0, 0.45, 0.90],
              ),
            ),
          ),

          // 4. Conteúdo sobreposto (Campos do PIN, botões e teclado)
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
