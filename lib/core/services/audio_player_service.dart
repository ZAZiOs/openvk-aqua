import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/attachment.dart';

enum AudioRepeatMode { off, all, one }

class RetroAudioPlayerService extends ChangeNotifier {
  static final RetroAudioPlayerService instance = RetroAudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  AudioAttachment? _currentTrack;
  List<AudioAttachment> _playlist = [];
  List<AudioAttachment> _originalPlaylist = [];
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isShuffle = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  String? _errorMessage;
  bool _contextConfigured = false;

  RetroAudioPlayerService._() {
    _initPlayer();
  }

  AudioAttachment? get currentTrack => _currentTrack;
  List<AudioAttachment> get playlist => List.unmodifiable(_playlist);
  List<AudioAttachment> get originalPlaylist => List.unmodifiable(_originalPlaylist);
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

  void _initPlayer() {
    _configureAudioContext();

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      final isPlayingState = state == PlayerState.playing;
      final isBufferingState = false; // audioplayers handles buffering internally

      bool shouldNotify = false;
      if (_isPlaying != isPlayingState) {
        _isPlaying = isPlayingState;
        shouldNotify = true;
      }
      if (_isBuffering != isBufferingState) {
        _isBuffering = isBufferingState;
        shouldNotify = true;
      }
      if (shouldNotify) {
        notifyListeners();
      }
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      if ((pos - _position).abs() >= const Duration(milliseconds: 300)) {
        _position = pos;
        notifyListeners();
      }
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (dur > Duration.zero && _duration != dur) {
        _duration = dur;
        notifyListeners();
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      _handleTrackFinished();
    });
  }

  Future<void> _configureAudioContext() async {
    if (_contextConfigured) return;
    _contextConfigured = true;

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gain,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RetroAudioPlayerService] Error configuring AudioContext: $e');
    }
  }

  Future<void> playTrack(
    AudioAttachment track, {
    List<AudioAttachment>? playlist,
  }) async {
    if (playlist != null && playlist.isNotEmpty) {
      _originalPlaylist = List.from(playlist);
      if (_isShuffle) {
        final others = List<AudioAttachment>.from(playlist)
          ..removeWhere((a) => a.id == track.id);
        others.shuffle(Random());
        _playlist = [track, ...others];
      } else {
        _playlist = List.from(playlist);
      }
    } else if (!_playlist.any((a) => a.id == track.id)) {
      _playlist.add(track);
      if (!_originalPlaylist.any((a) => a.id == track.id)) {
        _originalPlaylist.add(track);
      }
    }

    if (_currentTrack?.id == track.id && _isPlaying) {
      return;
    }

    if (_currentTrack?.id == track.id && !_isPlaying) {
      await play();
      return;
    }

    if (track.url.isEmpty) {
      _errorMessage = 'Аудиозапись недоступна для воспроизведения';
      notifyListeners();
      return;
    }

    _currentTrack = track;
    _errorMessage = null;
    _isBuffering = true;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration(seconds: track.duration);
    notifyListeners();

    try {
      await _configureAudioContext();
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(UrlSource(track.url));

      _isPlaying = true;
      _isBuffering = false;
      notifyListeners();
    } catch (e) {
      _isBuffering = false;
      _isPlaying = false;
      _errorMessage = 'Ошибка воспроизведения: $e';
      notifyListeners();
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
    if (_currentTrack != null) {
      try {
        await _player.resume();
        _isPlaying = true;
        notifyListeners();
      } catch (e) {
        await playTrack(_currentTrack!, playlist: _playlist);
      }
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[RetroAudioPlayerService] Error pausing: $e');
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    final curIdx = currentIndex;
    if (curIdx != -1 && curIdx + 1 < _playlist.length) {
      await playTrack(_playlist[curIdx + 1]);
    } else if (_repeatMode == AudioRepeatMode.all && _playlist.isNotEmpty) {
      await playTrack(_playlist.first);
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
      await playTrack(_playlist[curIdx - 1]);
    } else if (_repeatMode == AudioRepeatMode.all && _playlist.isNotEmpty) {
      await playTrack(_playlist.last);
    } else {
      await seekTo(Duration.zero);
    }
  }

  Future<void> seekTo(Duration pos) async {
    _position = pos;
    notifyListeners();
    try {
      await _player.seek(pos);
    } catch (e) {
      debugPrint('[RetroAudioPlayerService] Error seeking: $e');
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _player.setVolume(_volume);
    } catch (e) {
      debugPrint('[RetroAudioPlayerService] Error setting volume: $e');
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      // Save original order before shuffling
      if (_originalPlaylist.isEmpty || _originalPlaylist.length != _playlist.length) {
        _originalPlaylist = List.from(_playlist);
      }
      if (_playlist.length > 1) {
        final current = _currentTrack;
        final others = _playlist.where((a) => a.id != current?.id).toList();
        others.shuffle(Random());
        if (current != null) {
          _playlist = [current, ...others];
        } else {
          _playlist = others;
        }
      }
    } else {
      // Restore original order
      if (_originalPlaylist.isNotEmpty) {
        _playlist = List.from(_originalPlaylist);
      }
    }
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

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

