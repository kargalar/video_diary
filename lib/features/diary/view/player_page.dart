import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class PlayerPageArgs {
  final String path;
  final String? title;
  const PlayerPageArgs({required this.path, this.title});
}

class PlayerPage extends StatefulWidget {
  static const route = '/player';
  final PlayerPageArgs args;
  const PlayerPage({super.key, required this.args});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  bool _isError = false;
  bool _forcedLandscape = false;
  bool _isSpeedUp = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _startHideTimer();
  }

  Future<void> _init() async {
    final file = File(widget.args.path);
    if (!await file.exists()) {
      setState(() => _isError = true);
      return;
    }
    try {
      final c = VideoPlayerController.file(file);
      await c.initialize();
      await c.setLooping(false);
      // If the video is landscape, rotate the UI to landscape for better viewing
      if ((Platform.isAndroid || Platform.isIOS) && c.value.size.width > c.value.size.height) {
        await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        _forcedLandscape = true;
      }
      setState(() => _controller = c);
      await c.play();
    } catch (_) {
      setState(() => _isError = true);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    if (_forcedLandscape) {
      // Restore app-wide portrait lock when leaving the player
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title ?? 'Video';
    return Scaffold(
      appBar: null,
      backgroundColor: Colors.black,
      body: _isError
          ? const Center(
              child: Text('Could not open video', style: TextStyle(color: Colors.white)),
            )
          : _controller == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: _showControlsTemporarily,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.cover, // fill screen, preserve aspect ratio
                        child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)),
                      ),
                    ),
                  ),
                  // Right half for 2x speed
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: GestureDetector(
                      onLongPressStart: (_) async {
                        setState(() => _isSpeedUp = true);
                        await _controller!.setPlaybackSpeed(2.0);
                      },
                      onLongPressEnd: (_) async {
                        setState(() => _isSpeedUp = false);
                        await _controller!.setPlaybackSpeed(1.0);
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: _isSpeedUp
                            ? const Center(
                                child: Text(
                                  '2x',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Center controls
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 10 seconds backward
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.replay_10, color: Colors.white),
                              iconSize: 40,
                              onPressed: () async {
                                final current = _controller!.value.position;
                                final target = current - const Duration(seconds: 10);
                                await _controller!.seekTo(target < Duration.zero ? Duration.zero : target);
                                _showControlsTemporarily();
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Play/Pause
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                              iconSize: 56,
                              onPressed: () async {
                                if (_controller!.value.isPlaying) {
                                  await _controller!.pause();
                                } else {
                                  await _controller!.play();
                                }
                                setState(() {});
                                _showControlsTemporarily();
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          // 10 seconds forward
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.forward_10, color: Colors.white),
                              iconSize: 40,
                              onPressed: () async {
                                final current = _controller!.value.position;
                                final duration = _controller!.value.duration;
                                final target = current + const Duration(seconds: 10);
                                await _controller!.seekTo(target > duration ? duration : target);
                                _showControlsTemporarily();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Top bar (back button and title)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Material(
                              color: Colors.black45,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom controls
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: _Controls(controller: _controller!, onInteraction: _showControlsTemporarily),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onInteraction;
  const _Controls({required this.controller, required this.onInteraction});

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  double _sliderValue = 0;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _Controls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  void _onTick() {
    if (!mounted || _seeking) return;
    final pos = widget.controller.value.position;
    final dur = widget.controller.value.duration;
    if (dur.inMilliseconds > 0) {
      setState(() => _sliderValue = pos.inMilliseconds / dur.inMilliseconds);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 8),
        color: Colors.transparent, // transparent overlay over video
        child: Row(
          children: [
            Text(_fmt(position), style: const TextStyle(color: Colors.white70)),
            Expanded(
              child: Slider(
                value: _sliderValue.clamp(0, 1),
                min: 0,
                max: 1,
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
                onChangeStart: (_) {
                  setState(() => _seeking = true);
                  widget.onInteraction();
                },
                onChanged: (v) => setState(() => _sliderValue = v),
                onChangeEnd: (v) async {
                  final target = Duration(milliseconds: (duration.inMilliseconds * v).round());
                  await widget.controller.seekTo(target);
                  setState(() => _seeking = false);
                  widget.onInteraction();
                },
              ),
            ),
            Text(_fmt(duration), style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
