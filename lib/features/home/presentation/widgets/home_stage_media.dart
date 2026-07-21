import 'package:flutter/material.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:video_player/video_player.dart';

/// Renders stage media: icon, image, or muted autoplay video with poster.
class HomeStageMediaView extends StatefulWidget {
  final HomeStageMedia media;
  final VoidCallback? onVideoComplete;
  final double maxHeight;

  const HomeStageMediaView({
    super.key,
    required this.media,
    this.onVideoComplete,
    this.maxHeight = 160,
  });

  @override
  State<HomeStageMediaView> createState() => _HomeStageMediaViewState();
}

class _HomeStageMediaViewState extends State<HomeStageMediaView> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant HomeStageMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url ||
        oldWidget.media.type != widget.media.type) {
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
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _controller = null;
    _ready = false;
    _failed = false;
  }

  Future<void> _setup() async {
    final media = widget.media;
    if (media.type != HomeStageMediaType.video) return;
    final url = media.url?.trim() ?? '';
    if (url.isEmpty ||
        !(url.startsWith('https://') || url.startsWith('http://'))) {
      setState(() => _failed = true);
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(media.loop);
      controller.setVolume(media.muted ? 0 : 1);
      controller.addListener(_onVideoTick);
      setState(() => _ready = true);
      if (media.autoplay) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos >= dur - const Duration(milliseconds: 200) &&
        !c.value.isPlaying) {
      widget.onVideoComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    if (!media.hasVisual) return const SizedBox.shrink();

    final h = homeSize(widget.maxHeight.clamp(48, 200));

    return switch (media.type) {
      HomeStageMediaType.icon => Icon(
          media.resolveIcon(),
          color: Colors.white,
          size: homeSize(28),
        ),
      HomeStageMediaType.image || HomeStageMediaType.lottie => _networkOrAsset(
          media.posterUrl?.isNotEmpty == true
              ? media.posterUrl!
              : (media.url ?? ''),
          h,
        ),
      HomeStageMediaType.video => _buildVideo(h),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildVideo(double h) {
    final media = widget.media;
    if (_ready && _controller != null) {
      final ar = media.aspectRatio <= 0 ? 16 / 9 : media.aspectRatio;
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
    final poster = media.posterUrl?.trim() ?? '';
    if (poster.isNotEmpty && !_failed) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _networkOrAsset(poster, h),
          if (!_failed)
            Icon(Icons.play_circle_fill,
                color: Colors.white70, size: homeSize(36)),
        ],
      );
    }
    return SizedBox(
      height: h * 0.5,
      child: const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white38),
      ),
    );
  }

  Widget _networkOrAsset(String url, double h) {
    if (url.isEmpty) return SizedBox(height: h * 0.4);
    final isAsset = url.startsWith('asset:');
    final path = isAsset ? url.substring('asset:'.length) : url;
    final child = isAsset
        ? Image.asset(path,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink())
        : Image.network(path,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
    return ClipRRect(
      borderRadius: BorderRadius.circular(homeSize(12)),
      child: child,
    );
  }
}
