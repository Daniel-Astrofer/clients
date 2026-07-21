import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeSize;
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:lottie/lottie.dart';
import 'package:rive/rive.dart';
import 'package:video_player/video_player.dart';

/// Resolves logical asset keys → package paths (backend never sends full paths).
class SceneAssetCatalog {
  const SceneAssetCatalog._();

  static const heroPrefix = 'assets/hero/';
  static const backgroundsPrefix = 'assets/backgrounds/';
  static const iconsPrefix = 'assets/icons/';

  static List<String> pathsFor(SceneMedia media) {
    final key = media.asset.trim();
    if (key.isEmpty) return const [];
    if (key.contains('/')) return [key];
    return switch (media.type) {
      SceneMediaType.rive => [
          '$heroPrefix$key.riv',
          'assets/animations/rive/$key.riv',
        ],
      SceneMediaType.lottie => [
          'assets/animations/lottie/$key.json',
          '$heroPrefix$key.json',
        ],
      SceneMediaType.svg => [
          '$iconsPrefix$key.svg',
          '$heroPrefix$key.svg',
        ],
      SceneMediaType.image => [
          '$heroPrefix$key.png',
          'assets/images/$key.png',
          'assets/feed/cards/$key.png',
        ],
      _ => [key],
    };
  }
}

/// Unified media host: icon / image / svg / rive / lottie / video.
class SceneMediaLayer extends StatelessWidget {
  final SceneMedia media;
  final double maxHeight;
  final VoidCallback? onComplete;

  const SceneMediaLayer({
    super.key,
    required this.media,
    this.maxHeight = 120,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!media.hasVisual) return const SizedBox.shrink();
    final h = homeSize(maxHeight.clamp(40, 200));

    return switch (media.type) {
      SceneMediaType.icon => _IconMedia(media: media, size: homeSize(32)),
      SceneMediaType.image => _ImageMedia(media: media, height: h),
      SceneMediaType.svg => _SvgMedia(media: media, height: h),
      SceneMediaType.video => _VideoMedia(
          media: media,
          height: h,
          onComplete: onComplete,
        ),
      SceneMediaType.rive => _RiveMedia(media: media, height: h),
      SceneMediaType.lottie => _LottieMedia(media: media, height: h),
      SceneMediaType.none => const SizedBox.shrink(),
    };
  }
}

class _IconMedia extends StatelessWidget {
  final SceneMedia media;
  final double size;

  const _IconMedia({required this.media, required this.size});

  @override
  Widget build(BuildContext context) {
    final key = (media.iconKey ?? media.asset).trim().toLowerCase();
    final icon = switch (key) {
      'bitcoin' || 'btc' => KeroseneIcons.bitcoin,
      'lightning' || 'ln' => KeroseneIcons.lightning,
      'wallet' => KeroseneIcons.wallet,
      'security' || 'shield' => KeroseneIcons.security,
      'info' => KeroseneIcons.info,
      _ => KeroseneIcons.info,
    };
    return Icon(icon, color: Colors.white, size: size);
  }
}

class _ImageMedia extends StatelessWidget {
  final SceneMedia media;
  final double height;

  const _ImageMedia({required this.media, required this.height});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheHeight = (height * dpr).round().clamp(1, 4096);

    final url = media.url?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(homeSize(12)),
        child: Image.network(
          url,
          height: height,
          fit: BoxFit.cover,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    final paths = SceneAssetCatalog.pathsFor(media);
    if (paths.isEmpty) return SizedBox(height: height * 0.3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(homeSize(12)),
      child: Image.asset(
        paths.first,
        height: height,
        fit: BoxFit.cover,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SvgMedia extends StatelessWidget {
  final SceneMedia media;
  final double height;

  const _SvgMedia({required this.media, required this.height});

  @override
  Widget build(BuildContext context) {
    final url = media.url?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return SvgPicture.network(
        url,
        height: height,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox(height: height * 0.4),
      );
    }
    final paths = SceneAssetCatalog.pathsFor(media);
    if (paths.isEmpty) return const SizedBox.shrink();
    return SvgPicture.asset(
      paths.first,
      height: height,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(height: height * 0.4),
    );
  }
}

class _LottieMedia extends StatelessWidget {
  final SceneMedia media;
  final double height;

  const _LottieMedia({required this.media, required this.height});

  @override
  Widget build(BuildContext context) {
    final url = media.url?.trim() ?? '';
    final paths = SceneAssetCatalog.pathsFor(media);
    final fallback = _IconMedia(media: media, size: homeSize(40));

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return SizedBox(
        height: height,
        child: Lottie.network(
          url,
          fit: BoxFit.contain,
          repeat: media.loop,
          errorBuilder: (_, __, ___) => Center(child: fallback),
        ),
      );
    }
    if (paths.isEmpty) {
      return SizedBox(height: height, child: Center(child: fallback));
    }

    return SizedBox(
      height: height,
      child: Lottie.asset(
        paths.first,
        fit: BoxFit.contain,
        repeat: media.loop,
        errorBuilder: (_, __, ___) => Center(child: fallback),
      ),
    );
  }
}

class _RiveMedia extends StatefulWidget {
  final SceneMedia media;
  final double height;

  const _RiveMedia({required this.media, required this.height});

  @override
  State<_RiveMedia> createState() => _RiveMediaState();
}

class _RiveMediaState extends State<_RiveMedia> {
  FileLoader? _loader;
  String? _path;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant _RiveMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.asset != widget.media.asset ||
        oldWidget.media.url != widget.media.url) {
      _loader?.dispose();
      _loader = null;
      _path = null;
      _bind();
    }
  }

  @override
  void dispose() {
    _loader?.dispose();
    super.dispose();
  }

  void _bind() {
    final url = widget.media.url?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _loader = FileLoader.fromUrl(url, riveFactory: Factory.rive);
      _path = url;
      return;
    }
    final paths = SceneAssetCatalog.pathsFor(widget.media);
    if (paths.isEmpty) return;
    _path = paths.first;
    _loader = FileLoader.fromAsset(_path!, riveFactory: Factory.rive);
  }

  @override
  Widget build(BuildContext context) {
    final loader = _loader;
    final fallback = Center(
      child: _IconMedia(media: widget.media, size: homeSize(40)),
    );
    if (loader == null) {
      return SizedBox(height: widget.height, child: fallback);
    }

    return SizedBox(
      height: widget.height,
      child: RiveWidgetBuilder(
        fileLoader: loader,
        builder: (context, state) {
          return switch (state) {
            RiveLoading() => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            RiveFailed() => fallback,
            RiveLoaded(:final controller) => _RiveLoadedView(
                controller: controller,
                stateName: widget.media.state,
              ),
          };
        },
        onFailed: (_, __) {},
      ),
    );
  }
}

class _RiveLoadedView extends StatefulWidget {
  final RiveWidgetController controller;
  final String? stateName;

  const _RiveLoadedView({
    required this.controller,
    this.stateName,
  });

  @override
  State<_RiveLoadedView> createState() => _RiveLoadedViewState();
}

class _RiveLoadedViewState extends State<_RiveLoadedView> {
  @override
  void initState() {
    super.initState();
    _fireState();
  }

  @override
  void didUpdateWidget(covariant _RiveLoadedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateName != widget.stateName) {
      _fireState();
    }
  }

  void _fireState() {
    final name = widget.stateName?.trim();
    if (name == null || name.isEmpty) return;
    try {
      // Backend sends logical state names; Flutter fires SM inputs.
      final sm = widget.controller.stateMachine;
      final trigger = sm.trigger(name);
      if (trigger != null) {
        trigger.fire();
        return;
      }
      final flag = sm.boolean(name);
      if (flag != null) {
        flag.value = true;
      }
    } catch (_) {
      // Missing input / SM — silent no-op.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiveWidget(controller: widget.controller);
  }
}

class _VideoMedia extends StatefulWidget {
  final SceneMedia media;
  final double height;
  final VoidCallback? onComplete;

  const _VideoMedia({
    required this.media,
    required this.height,
    this.onComplete,
  });

  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant _VideoMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url) {
      _disposePlayer();
      _setup();
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
    _ready = false;
  }

  Future<void> _setup() async {
    final url = widget.media.url?.trim() ?? '';
    if (url.isEmpty ||
        !(url.startsWith('https://') || url.startsWith('http://'))) {
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = c;
      await c.initialize();
      if (!mounted) return;
      c.setLooping(widget.media.loop);
      c.setVolume(0);
      c.addListener(_onTick);
      setState(() => _ready = true);
      if (widget.media.autoplay) await c.play();
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos >= dur - const Duration(milliseconds: 200) &&
        !c.value.isPlaying) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _controller != null) {
      final ar =
          widget.media.aspectRatio <= 0 ? 16 / 9 : widget.media.aspectRatio;
      return ClipRRect(
        borderRadius: BorderRadius.circular(homeSize(12)),
        child: AspectRatio(
          aspectRatio: ar,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    }
    return SizedBox(height: widget.height * 0.4);
  }
}
