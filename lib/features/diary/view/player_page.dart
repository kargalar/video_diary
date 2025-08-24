import 'dart:io';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
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
      setState(() => _controller = c);
      await c.play();
    } catch (_) {
      setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
              child: Text('Video açılamadı', style: TextStyle(color: Colors.white)),
            )
          : _controller == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.cover, // fill screen, preserve aspect ratio
                      child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
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
                Positioned(left: 0, right: 0, bottom: 0, child: _Controls(controller: _controller!)),
              ],
            ),
    );
  }
}

class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  const _Controls({required this.controller});

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
    final isPlaying = widget.controller.value.isPlaying;
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent, // transparent overlay over video
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  iconSize: 36,
                  onPressed: () async {
                    if (isPlaying) {
                      await widget.controller.pause();
                    } else {
                      await widget.controller.play();
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Slider(
                        value: _sliderValue.clamp(0, 1),
                        min: 0,
                        max: 1,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white38,
                        onChangeStart: (_) => setState(() => _seeking = true),
                        onChanged: (v) => setState(() => _sliderValue = v),
                        onChangeEnd: (v) async {
                          final target = Duration(milliseconds: (duration.inMilliseconds * v).round());
                          await widget.controller.seekTo(target);
                          setState(() => _seeking = false);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position), style: const TextStyle(color: Colors.white70)),
                          Text(_fmt(duration), style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
