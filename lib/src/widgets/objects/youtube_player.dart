import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:mago_widgets/src/widgets/components/object_loader.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yti;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MagoYoutubePlayer extends StatefulWidget {
  final String url;

  final bool autoPlay;

  final double aspectRatio;

  final ValueChanged<MagoYoutubePlayerState>? onPlayerCreated;
  final VoidCallback? onPlayPauseCallback;
  final VoidCallback? onForwardCallback;
  final VoidCallback? onRewindCallback;

  const MagoYoutubePlayer({
    super.key,
    required this.url,
    this.autoPlay = true,
    this.aspectRatio = 16 / 9,
    this.onPlayerCreated,
    this.onPlayPauseCallback,
    this.onForwardCallback,
    this.onRewindCallback,
  });

  @override
  State<MagoYoutubePlayer> createState() => MagoYoutubePlayerState();
}

class MagoYoutubePlayerState extends State<MagoYoutubePlayer> {
  Player? _player;
  mk.VideoController? _videoController;
  String? _streamUrl;

  yti.YoutubePlayerController? _ytController;
  StreamSubscription<yti.YoutubePlayerValue>? _ytValueSub;
  StreamSubscription<yti.YoutubeVideoState>? _ytVideoStateSub;
  Timer? _ytDurationPollTimer;
  Duration _webPosition = Duration.zero;
  Duration _webDuration = Duration.zero;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isMuted = false;

  static const double _virtualW = 1920;
  static const double _virtualH = 1080;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebPlayer();
    } else {
      _initDesktopPlayer();
    }
    widget.onPlayerCreated?.call(this);
  }

  @override
  void dispose() {
    _ytDurationPollTimer?.cancel();
    _ytValueSub?.cancel();
    _ytVideoStateSub?.cancel();
    _ytController?.close();
    _disposeDesktopPlayer();
    super.dispose();
  }

  Duration get currentPosition =>
      kIsWeb ? _webPosition : (_player?.state.position ?? Duration.zero);

  Duration get duration =>
      kIsWeb ? _webDuration : (_player?.state.duration ?? Duration.zero);

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  void togglePlayPause() => _togglePlayPause();

  void forward({int seconds = 10}) => _seekForward(seconds);
  void rewind({int seconds = 10}) => _seekBackward(seconds);

  void updatePlayback(bool play) => _setPlayback(play);
  void updateMute(bool muted) => _setMute(muted);

  void seekTo(Duration position) async {
    if (kIsWeb) {
      await _ytController?.seekTo(
        seconds: position.inMilliseconds / 1000.0,
        allowSeekAhead: true,
      );
    } else {
      _player?.seek(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MagoObjectLoader();
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final Widget playerWidget;

    if (kIsWeb) {
      final c = _ytController;
      if (c == null) {
        return const Center(
          child: Text('Player not initialized',
              style: TextStyle(color: Colors.white70)),
        );
      }
      playerWidget = yti.YoutubePlayer(
        controller: c,
        aspectRatio: widget.aspectRatio,
      );
    } else {
      if (_player == null || _videoController == null) {
        return const Center(
          child: Text('Player not initialized',
              style: TextStyle(color: Colors.white70)),
        );
      }
      playerWidget = mk.Video(
        controller: _videoController!,
        fill: Colors.black,
        aspectRatio: widget.aspectRatio,
      );
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _virtualW,
        height: _virtualH,
        child: playerWidget,
      ),
    );
  }

  Future<void> _initWebPlayer() async {
    try {
      final videoId = _extractYouTubeId(widget.url);
      if (videoId == null) {
        _setError('Invalid YouTube URL: ${widget.url}');
        return;
      }

      _isMuted = widget.autoPlay;

      _ytController = yti.YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: widget.autoPlay,
        params: const yti.YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          enableCaption: true,
        ),
      );

      if (_isMuted) {
        unawaited(_ytController!.mute());
      }

      _ytValueSub = _ytController!.stream.listen((value) {
        if (!mounted) return;
        setState(
            () => _isPlaying = value.playerState == yti.PlayerState.playing);
      });

      _ytVideoStateSub = _ytController!.videoStateStream.listen((state) {
        _webPosition = state.position;
      });

      _ytDurationPollTimer =
          Timer.periodic(const Duration(milliseconds: 500), (_) async {
        final c = _ytController;
        if (c == null) return;
        try {
          final seconds = await c.duration;
          if (seconds > 0) {
            _webDuration = Duration(milliseconds: (seconds * 1000).round());
            _ytDurationPollTimer?.cancel();
            _ytDurationPollTimer = null;
          }
        } catch (_) {}
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      _setError('Failed to load video: $e');
    }
  }

  Future<void> _initDesktopPlayer() async {
    try {
      final videoId = _extractYouTubeId(widget.url);
      if (videoId == null) {
        _setError('Invalid YouTube URL: ${widget.url}');
        return;
      }

      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        String? streamUrl;

        if (manifest.muxed.isNotEmpty) {
          final muxed = manifest.muxed.toList()
            ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
          MuxedStreamInfo? selected;
          for (final s in muxed) {
            final q = s.videoQuality.name.toLowerCase();
            if (q.contains('720') || q.contains('480') || q.contains('360')) {
              selected = s;
              break;
            }
          }
          selected ??= muxed.first;
          streamUrl = selected.url.toString();
        } else if (manifest.videoOnly.isNotEmpty) {
          final vOnly = manifest.videoOnly.toList()
            ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
          VideoOnlyStreamInfo? selected;
          for (final s in vOnly) {
            final q = s.videoQuality.name.toLowerCase();
            if (q.contains('720') || q.contains('480') || q.contains('360')) {
              selected = s;
              break;
            }
          }
          selected ??= vOnly.first;
          streamUrl = selected.url.toString();
        }

        if (streamUrl == null) throw Exception('No suitable stream found');
        _streamUrl = streamUrl;
      } finally {
        yt.close();
      }

      _player = Player();
      _videoController = mk.VideoController(_player!);

      await _player!.setVolume(100);
      _isMuted = false;

      _player!.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
      });

      _player!.stream.completed.listen((completed) {
        if (!completed || !mounted) return;
        setState(() => _isPlaying = false);
      });

      await _player!.open(Media(_streamUrl!));

      if (widget.autoPlay) {
        await _player!.play();
        _isPlaying = true;
      } else {
        await _player!.pause();
        _isPlaying = false;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      _setError('Failed to load video: $e');
    }
  }

  void _disposeDesktopPlayer() {
    final player = _player;
    _player = null;
    _videoController = null;
    if (player == null) return;

    try {
      player.pause();
      player.stop();
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        player.dispose();
      } catch (_) {}
    });
  }

  void _togglePlayPause() async {
    final play = !_isPlaying;
    if (kIsWeb) {
      final c = _ytController;
      if (c == null) return;
      play ? await c.playVideo() : await c.pauseVideo();
    } else {
      final p = _player;
      if (p == null) return;
      play ? p.play() : p.pause();
    }
  }

  void _setPlayback(bool play) async {
    if (kIsWeb) {
      final c = _ytController;
      if (c == null) return;
      play ? await c.playVideo() : await c.pauseVideo();
    } else {
      final p = _player;
      if (p == null) return;
      play ? p.play() : p.pause();
    }
    _isPlaying = play;
    if (mounted) setState(() {});
  }

  void _setMute(bool muted) async {
    if (kIsWeb) {
      final c = _ytController;
      if (c == null) return;
      muted ? await c.mute() : await c.unMute();
    } else {
      _player?.setVolume(muted ? 0 : 100);
    }
    _isMuted = muted;
    if (mounted) setState(() {});
  }

  void _seekForward(int seconds) async {
    if (kIsWeb) {
      final c = _ytController;
      if (c == null) return;
      final cur = _webPosition.inMilliseconds / 1000.0;
      final dur = _webDuration.inMilliseconds / 1000.0;
      final next = dur > 0
          ? (cur + seconds).clamp(0.0, dur)
          : (cur + seconds).clamp(0.0, double.infinity);
      await c.seekTo(seconds: next, allowSeekAhead: true);
    } else {
      final p = _player;
      if (p == null) return;
      final pos = p.state.position + Duration(seconds: seconds);
      p.seek(pos > p.state.duration ? p.state.duration : pos);
    }
  }

  void _seekBackward(int seconds) async {
    if (kIsWeb) {
      final c = _ytController;
      if (c == null) return;
      final cur = _webPosition.inMilliseconds / 1000.0;
      final next = (cur - seconds).clamp(0.0, double.infinity);
      await c.seekTo(seconds: next, allowSeekAhead: true);
    } else {
      final p = _player;
      if (p == null) return;
      final pos = p.state.position - Duration(seconds: seconds);
      p.seek(pos < Duration.zero ? Duration.zero : pos);
    }
  }

  static String? _extractYouTubeId(String raw) {
    try {
      final clean = raw
          .replaceFirst(RegExp(r'^url:\s*'), '')
          .replaceFirst(RegExp(r'^youtube:\s*'), '')
          .replaceAll(RegExp(r'\(\([^)]+\)\)'), '')
          .trim();

      final u = Uri.parse(clean);

      if (u.host.contains('youtube.com') ||
          u.host.contains('youtube-nocookie.com')) {
        if (u.path == '/watch' && u.queryParameters['v'] != null) {
          return u.queryParameters['v'];
        }
        if (u.pathSegments.isNotEmpty) {
          if (u.pathSegments.first == 'embed' && u.pathSegments.length >= 2) {
            return u.pathSegments[1];
          }
          if (u.pathSegments.first == 'shorts' && u.pathSegments.length >= 2) {
            return u.pathSegments[1];
          }
        }
      }

      if (u.host == 'youtu.be' && u.pathSegments.isNotEmpty) {
        return u.pathSegments.first;
      }

      if (clean.length == 11 && !clean.contains('/')) return clean;
    } catch (_) {}
    return null;
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isLoading = false;
    });
  }
}
