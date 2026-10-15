import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';

import '../models/attachment.dart';

enum AudioRepeatMode { off, all, one }

class RetroAudioPlayerService extends ChangeNotifier {
  static final RetroAudioPlayerService instance = RetroAudioPlayerService._();

  RetroAudioPlayerService._();

  VideoPlayerController? _controller;
  AudioAttachment? _currentTrack;
  List<AudioAttachment> _playlist = [];
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isShuffle = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  String? _errorMessage;

  AudioAttachment? get currentTrack => _currentTrack;
  List<AudioAttachment> get playlist => List.unmodifiable(_playlist);
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isShuffle => _isShuffle;
  AudioRepeatMode get repeatMode => _repeatMode;
  String? get errorMessage => _errorMessage;
  bool get hasTrack => _currentTrack != null;

  int get currentIndex {
    if (_currentTrack == null || _playlist.isEmpty) return -1;
    return _playlist.indexWhere((a) => a.id == _currentTrack!.id);
  }

  Future<void> playTrack(
    AudioAttachment track, {
    List<AudioAttachment>? playlist,
  }) async {
    if (playlist != null && playlist.isNotEmpty) {
      _playlist = List.from(playlist);
    } else if (!_playlist.any((a) => a.id == track.id)) {
      _playlist.add(track);
    }

    if (_currentTrack?.id == track.id && _controller != null) {
      if (!_isPlaying) {
        await play();
      }
      return;
    }

    if (track.url.isEmpty) {
      _errorMessage = 'Аудиозапись недоступна для воспроизведения';
      notifyListeners();
      return;
    }

    _disposeController();

    _currentTrack = track;
    _errorMessage = null;
    _isBuffering = true;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration(seconds: track.duration);
    notifyListeners();

    try {
      if (Platform.isWindows) {
        WindowsVideoPlayer.registerWith();
      }

      final uri = Uri.parse(track.url);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      controller.addListener(_onControllerUpdate);
      await controller.setVolume(_volume);
      await controller.play();

      _isPlaying = true;
      _isBuffering = false;
      _duration = controller.value.duration;
      notifyListeners();
    } catch (e) {
      _isBuffering = false;
      _isPlaying = false;
      _errorMessage = 'Ошибка воспроизведения: $e';
      notifyListeners();
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null) return;

    final val = c.value;
    final isP = val.isPlaying;
    final isB = val.isBuffering;
    final pos = val.position;
    final dur = val.duration;

    bool shouldNotify = false;

    if (_isPlaying != isP) {
      _isPlaying = isP;
      shouldNotify = true;
    }
    if (_isBuffering != isB) {
      _isBuffering = isB;
      shouldNotify = true;
    }
    if ((pos - _position).abs() >= const Duration(milliseconds: 300) ||
        (dur > Duration.zero && _duration != dur)) {
      _position = pos;
      if (dur > Duration.zero) {
        _duration = dur;
      }
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }

    // Auto next track on completion
    if (dur > Duration.zero && pos >= dur && isP) {
      _handleTrackFinished();
    }
  }

  void _handleTrackFinished() {
    if (_repeatMode == AudioRepeatMode.one && _currentTrack != null) {
      seekTo(Duration.zero);
      play();
      return;
    }

    next();
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (_controller != null) {
      await _controller!.play();
      _isPlaying = true;
      notifyListeners();
    } else if (_currentTrack != null) {
      await playTrack(_currentTrack!, playlist: _playlist);
    }
  }

  Future<void> pause() async {
    if (_controller != null) {
      await _controller!.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      final rand = Random();
      final nextIdx = rand.nextInt(_playlist.length);
      await playTrack(_playlist[nextIdx], playlist: _playlist);
      return;
    }

    final curIdx = currentIndex;
    if (curIdx != -1 && curIdx + 1 < _playlist.length) {
      await playTrack(_playlist[curIdx + 1], playlist: _playlist);
    } else if (_repeatMode == AudioRepeatMode.all && _playlist.isNotEmpty) {
      await playTrack(_playlist.first, playlist: _playlist);
    } else {
      await pause();
      await seekTo(Duration.zero);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }

    final curIdx = currentIndex;
    if (curIdx > 0) {
      await playTrack(_playlist[curIdx - 1], playlist: _playlist);
    } else {
      await seekTo(Duration.zero);
    }
  }

  Future<void> seekTo(Duration pos) async {
    _position = pos;
    notifyListeners();
    if (_controller != null) {
      await _controller!.seekTo(pos);
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
    if (_controller != null) {
      await _controller!.setVolume(_volume);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case AudioRepeatMode.off:
        _repeatMode = AudioRepeatMode.all;
        break;
      case AudioRepeatMode.all:
        _repeatMode = AudioRepeatMode.one;
        break;
      case AudioRepeatMode.one:
        _repeatMode = AudioRepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
