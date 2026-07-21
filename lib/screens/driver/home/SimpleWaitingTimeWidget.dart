import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

import '../../../providers/ride_requests_service.dart';

class CompletelyIsolatedWaitingTimeWidget extends StatelessWidget {
  final String requestId;
  final double baseFare;

  const CompletelyIsolatedWaitingTimeWidget({
    Key? key,
    required this.requestId,
    required this.baseFare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create the controller without storing it in state
    final controller = _WaitingTimeController(requestId);

    // Return a widget that never rebuilds its parent
    return RepaintBoundary(
      child: _WaitingTimeControllerProvider(
        controller: controller,
        child: const _CompactWaitingTimeView(),
      ),
    );
  }
}

// Controller class that manages all state and logic
class _WaitingTimeController {
  final String requestId;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Timer? _waitingTimer;
  int _waitingTimeSeconds = 0;
  double _additionalFare = 0.0;
  bool _isWaiting = false;
  String _formattedTime = "00:00";

  // Stream controllers for updates
  final _isWaitingController = StreamController<bool>.broadcast();
  final _timeController = StreamController<String>.broadcast();
  final _fareController = StreamController<double>.broadcast();

  Stream<bool> get isWaiting => _isWaitingController.stream;
  Stream<String> get formattedTime => _timeController.stream;
  Stream<double> get additionalFare => _fareController.stream;

  _WaitingTimeController(this.requestId) {
    _loadWaitingTimeData();
  }

  void dispose() {
    _waitingTimer?.cancel();
    _isWaitingController.close();
    _timeController.close();
    _fareController.close();
  }

  Future<void> _loadWaitingTimeData() async {
    try {
      // Get reference using the ride request service
      final rideRequestsService = RideRequestsService();
      DatabaseReference waitingTimeRef = rideRequestsService.getWaitingTimeRef(requestId);

      DatabaseEvent event = await waitingTimeRef.once();

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _waitingTimeSeconds = data['seconds'] ?? 0;
        _isWaiting = data.containsKey('isWaiting') ? data['isWaiting'] : false;
        _additionalFare = (data['additionalFare'] ?? 0.0).toDouble();

        _updateFormattedTime();

        // Notify listeners
        _isWaitingController.add(_isWaiting);
        _timeController.add(_formattedTime);
        _fareController.add(_additionalFare);

        if (_isWaiting) {
          _startTimer();
        }
      }
    } catch (e) {
      print('Error loading waiting time: $e');
    }
  }

  void _updateFormattedTime() {
    final minutes = _waitingTimeSeconds ~/ 60;
    final remainingSeconds = _waitingTimeSeconds % 60;
    _formattedTime = '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _waitingTimer?.cancel();

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _waitingTimeSeconds++;
      _updateAdditionalFare();
      _updateFormattedTime();

      // Notify streams
      _timeController.add(_formattedTime);
      _fareController.add(_additionalFare);

      // Throttle Firebase saves
      if (_waitingTimeSeconds % 15 == 0) {
        _saveToFirebase();
      }
    });
  }

  void _updateAdditionalFare() {
    if (_waitingTimeSeconds > 300) {
      final extraMinutes = ((_waitingTimeSeconds - 300) / 60).ceil();
      _additionalFare = extraMinutes * 7.5;
    } else {
      _additionalFare = 0.0;
    }
  }

  Future<void> _saveToFirebase() async {
    try {
      final rideRequestsService = RideRequestsService();
      DatabaseReference waitingTimeRef = rideRequestsService.getWaitingTimeRef(requestId);

      await waitingTimeRef.update({
        'seconds': _waitingTimeSeconds,
        'isWaiting': _isWaiting,
        'additionalFare': _additionalFare,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error saving waiting time: $e');
    }
  }

  void startWaiting(BuildContext context) {
    if (_isWaiting) return;

    _isWaiting = true;
    _isWaitingController.add(_isWaiting);

    _startTimer();
    _saveToFirebase();
  }

  void stopWaiting(BuildContext context) {
    if (!_isWaiting) return;

    _isWaiting = false;
    _isWaitingController.add(_isWaiting);

    _waitingTimer?.cancel();

    // Use the ride request service
    final rideRequestsService = RideRequestsService();
    DatabaseReference waitingTimeRef = rideRequestsService.getWaitingTimeRef(requestId);

    // Force immediate update to Firebase to ensure isWaiting is false
    waitingTimeRef.update({
      'isWaiting': false,
      'lastUpdated': ServerValue.timestamp,
    }).then((_) {
      // After confirmation of update, save all data
      _saveToFirebase();
    });

    // Show the stop dialog with final time and fare
    _showStopDialog(context, _formattedTime, _additionalFare);
  }

  void _showStopDialog(BuildContext context, String finalTime, double additionalFare) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Waiting Stopped'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Final waiting time: $finalTime'),
            SizedBox(height: 8),
            if (additionalFare > 0)
              Text(
                'Additional fare: Rs${additionalFare.toStringAsFixed(1)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Provider widget to make the controller available to child widgets
class _WaitingTimeControllerProvider extends InheritedWidget {
  final _WaitingTimeController controller;

  const _WaitingTimeControllerProvider({
    required this.controller,
    required Widget child,
  }) : super(child: child);

  static _WaitingTimeController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_WaitingTimeControllerProvider>()!.controller;
  }

  @override
  bool updateShouldNotify(_WaitingTimeControllerProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}

// New compact view that shows timer directly
class _CompactWaitingTimeView extends StatelessWidget {
  const _CompactWaitingTimeView();

  @override
  Widget build(BuildContext context) {
    final controller = _WaitingTimeControllerProvider.of(context);

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Empty Spacer for balance
              SizedBox(width: 24),
              // Centered heading
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Waiting Time',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              // Close button at extreme right
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                splashRadius: 20,
              ),
            ],
          ),
          SizedBox(height: 16.0),

          // Timer display
          StreamBuilder<String>(
            stream: controller.formattedTime,
            initialData: "00:00",
            builder: (context, timeSnapshot) {
              return StreamBuilder<bool>(
                stream: controller.isWaiting,
                initialData: false,
                builder: (context, waitingSnapshot) {
                  final bool isActive = waitingSnapshot.data ?? false;
                  final String time = timeSnapshot.data ?? "00:00";

                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isActive ?
                      AppColors.secondary.value.withOpacity(0.1) :
                      Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isActive ? AppColors.secondary.value : Colors.grey,
                          width: 1.5
                      ),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        color: time.compareTo("05:00") > 0 ? Colors.red :
                        isActive ? AppColors.primary.withOpacity(0.9) : Colors.grey[700],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Additional fare display
          StreamBuilder<double>(
            stream: controller.additionalFare,
            initialData: 0.0,
            builder: (context, snapshot) {
              final fare = snapshot.data ?? 0.0;
              return fare > 0 ?
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Additional fare: Rs${fare.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    fontSize: 16,
                  ),
                ),
              ) : SizedBox(height: 8);
            },
          ),

          SizedBox(height: 16.0),

          // Control buttons
          Row(
            children: [
              Expanded(
                child: StreamBuilder<bool>(
                  stream: controller.isWaiting,
                  initialData: false,
                  builder: (context, snapshot) {
                    return ElevatedButton.icon(
                      onPressed: snapshot.data!
                          ? null
                          : () => controller.startWaiting(context),
                      icon: Icon(Icons.play_circle_outline, size: 18, color: Colors.white),
                      label: Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 10.0),
              Expanded(
                child: StreamBuilder<bool>(
                  stream: controller.isWaiting,
                  initialData: false,
                  builder: (context, snapshot) {
                    return ElevatedButton.icon(
                      onPressed: snapshot.data!
                          ? () => controller.stopWaiting(context)
                          : null,
                      icon: Icon(Icons.stop_circle, size: 18, color: Colors.white),
                      label: Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}