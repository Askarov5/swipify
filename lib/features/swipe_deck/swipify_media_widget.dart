import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/native_gallery_helper.dart';

class SwipifyMediaWidget extends StatefulWidget {
  final SwipifyPhoto asset;
  final bool isFrontCard;

  const SwipifyMediaWidget({
    super.key,
    required this.asset,
    required this.isFrontCard,
  });

  @override
  State<SwipifyMediaWidget> createState() => _SwipifyMediaWidgetState();
}

class _SwipifyMediaWidgetState extends State<SwipifyMediaWidget> {
  /// Max edge length for deck thumbnails (back cards and video posters).
  static const double _deckThumbExtent = 720;

  /// Avoid repeat native export / path resolution when revisiting the same clip in one session.
  static final Map<String, String> _sessionVideoPathCache = <String, String>{};

  VideoPlayerController? _videoController;
  bool _isMuted = true;
  bool _initialized = false;
  String? _videoError;
  /// Mirrors [VideoPlayerController.value.isPlaying] for transport UI without per-frame rebuilds.
  bool _videoIsPlaying = false;

  Future<Uint8List?>? _imageFuture;
  Future<Uint8List?>? _videoPosterFuture;

  Future<Uint8List?> _photoLoadFuture() {
    if (widget.isFrontCard) {
      return widget.asset.fileData;
    }
    return NativeGalleryHelper.fetchThumbnail(
      widget.asset.id,
      width: _deckThumbExtent,
      height: _deckThumbExtent,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.asset.isVideo) {
      _videoPosterFuture = NativeGalleryHelper.fetchThumbnail(
        widget.asset.id,
        width: _deckThumbExtent,
        height: _deckThumbExtent,
      );
      if (widget.isFrontCard) {
        _initVideo();
      }
    } else {
      _imageFuture = _photoLoadFuture();
    }
  }

  /// Returns a session-cached path only if the file is still present and non-empty.
  String? _validCachedVideoPath(String loadId) {
    final p = _sessionVideoPathCache[loadId];
    if (p == null) return null;
    try {
      final f = File(p);
      if (!f.existsSync()) {
        _sessionVideoPathCache.remove(loadId);
        return null;
      }
      if (f.lengthSync() <= 0) {
        _sessionVideoPathCache.remove(loadId);
        return null;
      }
    } catch (_) {
      _sessionVideoPathCache.remove(loadId);
      return null;
    }
    return p;
  }

  void _disposeVideoController() {
    _videoController?.removeListener(_onVideoPlayerTick);
    final c = _videoController;
    _videoController = null;
    c?.dispose();
    _initialized = false;
  }

  void _onVideoPlayerTick() {
    final c = _videoController;
    if (c == null || !mounted) return;
    if (!c.value.isInitialized) return;
    if (c.value.hasError) {
      c.removeListener(_onVideoPlayerTick);
      final msg = c.value.errorDescription;
      c.dispose();
      _videoController = null;
      setState(() {
        _initialized = false;
        _videoError = msg ?? 'Playback error';
        _videoIsPlaying = false;
      });
      return;
    }
    final playing = c.value.isPlaying;
    if (playing != _videoIsPlaying) {
      setState(() => _videoIsPlaying = playing);
    }
  }

  static const int _videoInitMaxAttempts = 4;
  static const Duration _videoInitRetryDelay = Duration(milliseconds: 90);

  Future<void> _initVideo({bool forceNativeRefresh = false}) async {
    if (!mounted || !widget.isFrontCard) return;

    /// Swipes schedule overlapping async work; only the latest [loadId] may update state.
    final String loadId = widget.asset.id;

    setState(() {
      _videoError = null;
    });

    String? path;
    try {
      if (forceNativeRefresh) {
        _sessionVideoPathCache.remove(loadId);
      }
      path = forceNativeRefresh ? null : _validCachedVideoPath(loadId);
      if (path == null) {
        path = await NativeGalleryHelper.fetchFilePath(
          loadId,
          forceRefresh: forceNativeRefresh,
        );
        if (path != null) {
          _sessionVideoPathCache[loadId] = path;
        }
      }
    } catch (_) {
      if (!mounted || widget.asset.id != loadId) return;
      setState(() {
        _videoError = 'Could not access video.';
      });
      return;
    }

    if (!mounted || widget.asset.id != loadId) return;
    if (path == null) {
      setState(() {
        _videoError = 'Could not access video.';
      });
      return;
    }

    for (var attempt = 0; attempt < _videoInitMaxAttempts; attempt++) {
      if (!mounted || widget.asset.id != loadId) return;

      if (attempt > 0) {
        await Future<void>.delayed(_videoInitRetryDelay);
        if (!mounted || widget.asset.id != loadId) return;
      }

      _disposeVideoController();
      if (!mounted || widget.asset.id != loadId) return;

      final controller = VideoPlayerController.file(File(path));
      _videoController = controller;
      controller.addListener(_onVideoPlayerTick);

      try {
        await controller.initialize();
        if (!mounted || widget.asset.id != loadId) {
          controller.removeListener(_onVideoPlayerTick);
          await controller.dispose();
          if (_videoController == controller) {
            _videoController = null;
          }
          return;
        }
        await controller.setVolume(0.0);
        await controller.setLooping(true);
        setState(() {
          _initialized = true;
          _videoError = null;
        });
        controller.play();
        return;
      } catch (_) {
        controller.removeListener(_onVideoPlayerTick);
        await controller.dispose();
        if (_videoController == controller) {
          _videoController = null;
        }
      }
    }

    if (!mounted || widget.asset.id != loadId) return;
    _sessionVideoPathCache.remove(loadId);
    setState(() {
      _initialized = false;
      _videoError = 'Video failed to load.';
    });
  }

  void _retryVideo() {
    _disposeVideoController();
    _initVideo(forceNativeRefresh: true);
  }

  @override
  void didUpdateWidget(SwipifyMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Safely refresh completely if a completely different asset was injected into this exact positional widget state
    if (widget.asset.id != oldWidget.asset.id) {
      if (widget.asset.isVideo) {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _initialized = false;
        _videoError = null;
        _videoIsPlaying = false;
        _videoPosterFuture = NativeGalleryHelper.fetchThumbnail(
          widget.asset.id,
          width: _deckThumbExtent,
          height: _deckThumbExtent,
        );
        if (widget.isFrontCard) {
          _initVideo();
        }
      } else {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _videoError = null;
        setState(() {
          _imageFuture = _photoLoadFuture();
        });
      }
      return;
    }

    if (!widget.asset.isVideo &&
        widget.isFrontCard != oldWidget.isFrontCard) {
      setState(() {
        _imageFuture = _photoLoadFuture();
      });
      return;
    }

    if (widget.asset.isVideo) {
      if (widget.isFrontCard && !oldWidget.isFrontCard) {
        if (!_initialized) {
          _initVideo();
        } else {
          _videoController?.play();
        }
      } else if (!widget.isFrontCard && oldWidget.isFrontCard) {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _initialized = false;
        _videoError = null;
        _videoIsPlaying = false;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoPlayerTick);
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  static const Duration _skipStep = Duration(seconds: 10);

  void _togglePlayPause() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    if (_videoIsPlaying) {
      c.pause();
      setState(() => _videoIsPlaying = false);
    } else {
      c.play();
      setState(() => _videoIsPlaying = true);
    }
  }

  Future<void> _skipBackward() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final next = c.value.position - _skipStep;
    await c.seekTo(next < Duration.zero ? Duration.zero : next);
  }

  Future<void> _skipForward() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final duration = c.value.duration;
    if (duration == Duration.zero) return;
    final next = c.value.position + _skipStep;
    await c.seekTo(next > duration ? duration : next);
  }

  Widget _buildVideoControlsBar() {
    final c = _videoController!;
    final ready = c.value.isInitialized;
    final playing = ready && _videoIsPlaying;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                onPressed: ready ? _skipBackward : null,
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
              ),
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: ready ? _togglePlayPause : null,
                icon: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              IconButton(
                tooltip: 'Forward 10 seconds',
                onPressed: ready ? _skipForward : null,
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.isVideo) {
      if (!_initialized || _videoController == null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _videoPosterFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  if (widget.isFrontCard) {
                    return const SizedBox.shrink();
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final bytes = snapshot.data;
                if (bytes != null && bytes.isNotEmpty) {
                  return Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  );
                }
                return const Center(
                  child: Icon(Icons.videocam, size: 64, color: Colors.grey),
                );
              },
            ),
            if (widget.isFrontCard && _videoError == null)
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.isFrontCard && _videoError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _videoError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _retryVideo,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
          if (widget.isFrontCard)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, right: 16),
                  child: IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                    onPressed: _toggleMute,
                  ),
                ),
              ),
            ),
          if (widget.isFrontCard)
            Positioned(
              left: 20,
              right: 20,
              bottom: 200,
              child: _buildVideoControlsBar(),
            ),
        ],
      );
    }

    // Fallback Image Handle
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Icon(Icons.broken_image, size: 64, color: Colors.grey));
        }

        return Center(
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
