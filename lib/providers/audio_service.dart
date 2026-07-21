// lib/providers/audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasCompleted = false;
  String _currentAudio = '';
  //Function? _onCompletionCallback;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  factory AudioService() {
    return _instance;
  }

  AudioService._internal() {
    // Listen to player state changes
    _player.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
      isPlayingNotifier.value = _isPlaying;
    });

    // Listen for playback completion
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _hasCompleted = true;
      isPlayingNotifier.value = false;
    });
  }

  Future<void> playAudio(String assetPath) async {
    try {
      // If same audio is playing, pause it
      if (_isPlaying && _currentAudio == assetPath) {
        await pauseAudio();
        return;
      }

      // If same audio was paused, resume it
      if (!_isPlaying && _currentAudio == assetPath) {
        await resumeAudio();
        return;
      }

      // Otherwise, start playing new audio
      _currentAudio = assetPath;
      _hasCompleted = false;
      await _player.stop();
      await _player.play(AssetSource(assetPath));
      _isPlaying = true;
      isPlayingNotifier.value = true;
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
      _isPlaying = false;
      isPlayingNotifier.value = false;
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  Future<void> resumeAudio() async {
    try {
      // Only resume if not completed
      if (!_hasCompleted) {
        await _player.resume();
        _isPlaying = true;
        isPlayingNotifier.value = true;
      } else {
        // If completed, start from beginning
        _hasCompleted = false;
        await _player.stop();
        await _player.play(AssetSource(_currentAudio));
        _isPlaying = true;
        isPlayingNotifier.value = true;      }
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      isPlayingNotifier.value = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  bool get isPlaying => _isPlaying;
  String get currentAudio => _currentAudio;
  bool get hasCompleted => _hasCompleted;

  Future<void> togglePlayPause(String assetPath) async {
    if (_isPlaying) {
      await pauseAudio();
    } else if (_currentAudio == assetPath && !_hasCompleted) {
      await resumeAudio();
    } else {
      await playAudio(assetPath);
    }
  }
}