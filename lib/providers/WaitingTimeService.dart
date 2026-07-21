import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class WaitingTimeService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Use ValueNotifier for efficient state management
  final ValueNotifier<bool> _isWaiting = ValueNotifier(false);
  final ValueNotifier<int> _waitingTimeSeconds = ValueNotifier(0);
  final ValueNotifier<double> _additionalFare = ValueNotifier(0.0);

  Timer? _waitingTimer;
  DateTime? _waitingStartTime;
  String? _currentRideId;

  // Streams for external listeners
  ValueListenable<bool> get isWaiting => _isWaiting;
  ValueListenable<int> get waitingTime => _waitingTimeSeconds;
  ValueListenable<double> get additionalFare => _additionalFare;

  // Public getters
  bool get currentIsWaiting => _isWaiting.value;
  int get currentWaitingTime => _waitingTimeSeconds.value;
  double get currentAdditionalFare => _additionalFare.value;

  Future<void> initialize(String rideId, [double baseFare = 0.0]) async {
    _currentRideId = rideId;

    try {
      DatabaseEvent event = await _dbRef.child('rideRequests/$rideId/waitingTime').once();

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _waitingTimeSeconds.value = data['seconds'] ?? 0;
        _isWaiting.value = data['isWaiting'] ?? false;
        _additionalFare.value = (data['additionalFare'] ?? 0.0).toDouble();

        if (_isWaiting.value) {
          _startTimer();
        }
      }
    } catch (e) {
      debugPrint('Error initializing waiting time: $e');
    }
  }

  void startWaitingTime() {
    if (_isWaiting.value) return;

    _isWaiting.value = true;
    _waitingStartTime = DateTime.now();
    _startTimer();
    _saveToFirebase();
  }

  void stopWaitingTime() {
    if (!_isWaiting.value) return;

    _isWaiting.value = false;
    _waitingTimer?.cancel();
    _saveToFirebase();
  }

  void reset() {
    stopWaitingTime();
    _waitingTimeSeconds.value = 0;
    _additionalFare.value = 0.0;

    if (_currentRideId != null) {
      _dbRef.child('rideRequests/$_currentRideId/waitingTime').remove();
    }
  }

  String formatWaitingTime([int? customSeconds]) {
    final seconds = customSeconds ?? _waitingTimeSeconds.value;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _waitingTimer?.cancel();
    _isWaiting.dispose();
    _waitingTimeSeconds.dispose();
    _additionalFare.dispose();
  }

  // Private methods
  void _startTimer() {
    _waitingTimer?.cancel();

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _waitingTimeSeconds.value++;
      _updateAdditionalFare();

      // Throttle Firebase saves
      if (_waitingTimeSeconds.value % 15 == 0) {
        _saveToFirebase();
      }
    });
  }

  void _updateAdditionalFare() {
    if (_waitingTimeSeconds.value > 300) {
      final extraMinutes = ((_waitingTimeSeconds.value - 300) / 60).ceil();
      _additionalFare.value = extraMinutes * 7.5;
    } else {
      _additionalFare.value = 0.0;
    }
  }

  Future<void> _saveToFirebase() async {
    if (_currentRideId == null) return;

    try {
      await _dbRef.child('rideRequests/$_currentRideId/waitingTime').update({
        'seconds': _waitingTimeSeconds.value,
        'isWaiting': _isWaiting.value,
        'additionalFare': _additionalFare.value,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error saving waiting time: $e');
    }
  }
}