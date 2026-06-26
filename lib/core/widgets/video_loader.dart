import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A looping video-based loading indicator.
/// Plays [fox_run.mp4] from assets and loops it as a loader.
/// Falls back to [CircularProgressIndicator] if the video fails.
class VideoLoader extends StatefulWidget {
  final double size;

  const VideoLoader({super.key, this.size = 150});

  @override
  State<VideoLoader> createState() => _VideoLoaderState();
}

class _VideoLoaderState extends State<VideoLoader> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    try {
      _controller = VideoPlayerController.asset('assets/videos/fox_run.mp4');
      _controller!.initialize().then((_) {
        if (!mounted) return;
        _controller!.setLooping(true);
        _controller!.play();
        setState(() {});
      }).catchError((e) {
        print('--- VideoLoader error: $e ---');
        if (!mounted) return;
        setState(() => _hasError = true);
      });
    } catch (e) {
      print('--- VideoLoader init error: $e ---');
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: widget.size,
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}
