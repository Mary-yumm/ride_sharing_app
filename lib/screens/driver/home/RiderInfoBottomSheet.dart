import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_app/providers/directions_service.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';
import 'package:ride_sharing_app/screens/home/chat_screen.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:ride_sharing_app/providers/GeolocationService.dart';
import 'package:ride_sharing_app/configMaps.dart';

class RiderInfoBottomSheet extends StatefulWidget {
  final Map<String, dynamic> rideDetails;
  final dynamic onCancel;
  final String activeOrAccepted;

  const RiderInfoBottomSheet({
    Key? key,
    required this.onCancel,
    required this.rideDetails,
    this.activeOrAccepted = 'accepted', // Default to accepted
  }) : super(key: key);

  // Use this factory constructor to help with keys
  factory RiderInfoBottomSheet.withKey({
    required Key key,
    required dynamic onCancel,
    required Map<String, dynamic> rideDetails,
    String activeOrAccepted = 'accepted',
  }) {
    return RiderInfoBottomSheet(
      key: key,
      onCancel: onCancel,
      rideDetails: rideDetails,
      activeOrAccepted: activeOrAccepted,
    );
  }

  @override
  _RiderInfoBottomSheetState createState() => _RiderInfoBottomSheetState();
}

class _RiderInfoBottomSheetState extends State<RiderInfoBottomSheet> {
  late Timer _timer;
  final GeolocationService _geolocationService = GeolocationService();
  final RideRequestsService _rideRequestsService = RideRequestsService();
  final DirectionsService _directionsService = DirectionsService(mapKey);

  // Stream controllers for time updates
  final StreamController<int> _timeToArrivalController = StreamController<int>.broadcast();
  final StreamController<int> _timeToDestinationController = StreamController<int>.broadcast();

  int _timeToArrival = 0;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  Map<String, dynamic>? _userInfo;
  double _baseFare = 0.0;
  //late WaitingTimeService _waitingTimeService = WaitingTimeService();


  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _fetchUserInfo();
    _baseFare = double.parse(widget.rideDetails['fare'].toString());
    // Subscribe to timer updates
   // _initializeWaitingTimeService();

    print('Rider Details in ride info: ${widget.rideDetails}');
  }


  // Future<void> _initializeWaitingTimeService() async {
  //   String requestId = widget.rideDetails['requestId'];
  //
  //   // Initialize the main service first
  //   WaitingTimeService mainService = WaitingTimeService();
  //   await mainService.initialize(requestId);
  //
  //   // Create an isolated instance that won't trigger global listeners
  //   _waitingTimeService = mainService.createIsolatedInstance();
  // }

  void _startLocationUpdates() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchLocationsAndCalculateETA();
      }
    });
    // Initial fetch
    _fetchLocationsAndCalculateETA();
  }
  Future<void> _fetchUserInfo() async {
    String userId = widget.rideDetails['userId'];
    final DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId");
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      if(mounted) {
        setState(() {
          _userInfo = {
            'userId': userId,
            'phone': data['phone'],
            'fcmToken': data['fcmToken'],
            'name': data['name'],
            'email': data['email'],
          };
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _timeToArrivalController.close();
    _timeToDestinationController.close();
    print('RiderInfoBottomSheet is disposed');
    super.dispose();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    double dLng = _degreesToRadians(point2.longitude - point1.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) * cos(_degreesToRadians(point2.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _fetchLocationsAndCalculateETA() async {
    if (!mounted) return;

    try {
      // Get current driver location
      final driverLocationData = await _geolocationService.getCurrentLocation();
      if (driverLocationData != null) {
        _driverLocation = LatLng(driverLocationData.latitude, driverLocationData.longitude);
      }

      if (_driverLocation == null) {
        print('Driver location is null');
        return;
      }

      // Get pickup and destination coordinates
      _pickupLocation ??= await _directionsService.getCoordinates(widget.rideDetails['pickupLocation']);
      _destinationLocation ??= await _directionsService.getCoordinates(widget.rideDetails['destination']);

      if (widget.activeOrAccepted == 'active') {
        // Ride is active - calculate time to destination
        if (_driverLocation != null && _destinationLocation != null) {
          final directions = await _directionsService.getDirections(
            origin: _driverLocation!,
            destination: _destinationLocation!,
            mode: 'driving',
          );

          final durationValue = directions['durationValue'] as int;
          if (mounted) {
            setState(() {
              _timeToArrival = (durationValue / 60).round(); // Convert seconds to minutes
              _timeToDestinationController.add(_timeToArrival);
            });
          }
        }
      } else {
        // Ride is accepted - calculate time to pickup
        if (_driverLocation != null && _pickupLocation != null) {
          final directions = await _directionsService.getDirections(
            origin: _driverLocation!,
            destination: _pickupLocation!,
            mode: 'driving',
          );

          final durationValue = directions['durationValue'] as int;
          if (mounted) {
            setState(() {
              _timeToArrival = (durationValue / 60).round(); // Convert seconds to minutes
              _timeToArrivalController.add(_timeToArrival);
            });
          }
          // Check if driver has reached pickup location
          double distance = _calculateDistance(_driverLocation!, _pickupLocation!);
          print('Distance to pickup: $distance meters');
        }
      }
    } catch (e) {
      print('Error calculating ETA: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
    child: SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              offset: Offset(0, -5),
            ),
          ],
          gradient: LinearGradient(
            colors: [Theme.of(context).primaryColor, Theme.of(context).cardColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: widget.activeOrAccepted == 'active'
                    ? _timeToDestinationController.stream
                    : _timeToArrivalController.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      widget.activeOrAccepted == 'active'
                          ? 'Estimated time to destination ~ ${snapshot.data} minutes'
                          : 'Estimated arrival at pickup ~ ${snapshot.data} minutes',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    );
                  } else {
                    return Text(
                      'Calculating...',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 10.0),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Details',
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary
                        ),
                      ),
                      SizedBox(height: 12.0),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.rideDetails['pickupLocation']}',
                              style: TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Container(
                          height: 25,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.rideDetails['destination']}',
                              style: TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.0),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Rs${widget.rideDetails['fare']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.0),
// Primary action button (Start or Complete)
              if (widget.activeOrAccepted == 'accepted')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      String requestId = widget.rideDetails['requestId'];
                      await _rideRequestsService.updateRideStatus(widget.rideDetails['driverId'],requestId, 'active');
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Start Ride', style: TextStyle(fontSize: 16)),
                  ),
                ),
              if (widget.activeOrAccepted == 'active') ...[


                // Complete Ride button (existing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _handleCompleteRide();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Complete Ride', style: TextStyle(fontSize: 16)),
                  ),
                ),

              ],
              SizedBox(height: 10.0),
// Secondary actions in a row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              driverId: widget.rideDetails['driverId'],
                              riderId: widget.rideDetails['userId'],
                              phone: _userInfo!['phone'],
                              fcmToken: _userInfo!['fcmToken'],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.chat, size: 18,color: AppColors.white,),
                      label: Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary.value,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.0),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onCancel,
                      icon: Icon(Icons.cancel, size: 18,color: AppColors.white,),
                      label: Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

// Add this method to handle the async work
  Future<void> _handleCompleteRide() async {
    String? requestId = widget.rideDetails['requestId'];
    String? driverId = widget.rideDetails['driverId'];

    if (requestId == null || driverId == null) {
      print('Cannot complete ride: requestId or driverId is null');
      return;
    }

    try {
      print('Completing ride with requestId: $requestId');
      double additionalFare = 0.0;

      try {
        // Use the ride request service to get the reference
        DatabaseReference waitingTimeRef = _rideRequestsService.getRideRequestRefRider(requestId, driverId)
            .child('waitingTime');

        DatabaseEvent event = await waitingTimeRef.once();

        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          additionalFare = (data['additionalFare'] ?? 0.0).toDouble();
        }
      } catch (e) {
        print('Error getting additional fare: $e');
      }

      double totalFare = _baseFare + additionalFare;

      // Complete the ride using the service
      await _rideRequestsService.completeRideRequest(
          driverId,
          requestId,
          additionalFare: additionalFare > 0 ? additionalFare : null,
          totalFare: totalFare
      );

      print('Ride completed successfully');

    } catch (e) {
      print('Error completing ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete ride. Please try again.'))
      );
    }
  }
}