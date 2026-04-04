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
      });
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
