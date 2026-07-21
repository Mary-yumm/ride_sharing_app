import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

import '../../Notifications/NotificationService.dart';
import '../../providers/ride_requests_service.dart';
import '../../widgets/auth.dart';
import 'RideInfoBottomSheet.dart';
import 'package:audioplayers/audioplayers.dart';

class NearbyDrivers extends StatefulWidget {
  final List<Map<String, dynamic>> driverDetailsList;
  final String? userid;
  final String? pickup;
  final String? destination;
  final String? selectedOption;
  final String? fare;
  final VoidCallback onShowPreviousBottomSheet; // Add this line
  final void Function(String driverId) onDriverSelected; // Add this line

  const NearbyDrivers({
    Key? key,
    required this.driverDetailsList,
    required this.userid,
    required this.pickup,
    required this.destination,
    required this.selectedOption,
    required this.fare,
    required this.onShowPreviousBottomSheet,
    required this.onDriverSelected, // Add this line
  }) : super(key: key);

  @override
  _NearbyDriversState createState() => _NearbyDriversState();
}


class _NearbyDriversState extends State<NearbyDrivers> {
  final Auth _auth = Auth.instance; // Use the singleton instance
  StreamSubscription<DatabaseEvent>? _rideRequestSubscription;
  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;
  String? _requestedDriverId;
  NotificationService notificationService = NotificationService();
  final RideRequestsService _rideService = RideRequestsService();
  String? _requestId;


  @override
  void initState() {
    super.initState();
  }

  void listenForDriverLocation(String driverId) {
    _driverLocationSubscription = FirebaseDatabase.instance
        .ref()
        .child('drivers/$driverId/location')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        var location = event.snapshot.value as Map;
        double latitude = location['latitude'];
        double longitude = location['longitude'];
        LatLng driverPosition = LatLng(lat:latitude, lng:longitude);

        // Update the map with the new driver position
        setState(() {
          // Update the driver's marker position on the map
        });
      }
    });
  }

  void listenForRequestStatus(String driverId, String requestId) {
    print("Listening for ride request status with ID: $requestId");

    // Cancel any existing subscription
    _rideRequestSubscription?.cancel();

    _rideRequestSubscription = _rideService
        .listenToRideRequest(driverId, requestId)
        .listen((event) async {
      if (event.snapshot.exists) {
        var data = event.snapshot.value as Map;
        var status = data['status'];
        print("Ride request status: $status");

        if (status == 'accepted') {
          print("Ride accepted!");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Your ride has been accepted!')),
          );

          Navigator.pop(context);
          widget.onDriverSelected(driverId);
        } else if (status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Your ride was rejected.')),
          );
        }
      }
    });
  }

  void requestRide(String driverId) async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/ride_request.mp3'));

    try {
      String? userid = _auth.currentUser?.uid;

      // Fetch FCM token by driver ID
      String? fcmToken = await _rideService.fetchFcmTokenByDriverId(driverId);
      if (fcmToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver FCM token not found.')),
        );
        return;
      }

      // Create ride details map
      Map<String, dynamic> rideDetails = {
        'pickup': widget.pickup,
        'destination': widget.destination,
        'fare': widget.fare,
        'ride_type': widget.selectedOption,
      };

      // Create ride request using the service
      String? requestId = await _rideService.createRideRequest(
          driverId, userid!, rideDetails);

      // Send notification to the driver
      await notificationService.sendNotification(
        fcmToken,
        'New Ride Request',
        'You have a new ride request from ${widget.pickup} to ${widget.destination}',
        notificationType: 'ride_request',
      );

      if (requestId != null) {
        setState(() {
          _requestedDriverId = driverId;
          _requestId = requestId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request sent to the driver!')),
        );

        // Listen for the request status
        listenForRequestStatus(driverId, requestId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send ride request.')),
        );
      }
    } catch (e) {
      print("Error sending ride request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send ride request.')),
      );
    }
  }

  void cancelRideRequest(String driverId) async {
    if (_requestId == null) return;

    bool success = await _rideService.cancelRideRequest(driverId, _requestId!);

    if (success) {
      setState(() {
        _requestedDriverId = null;
        _requestId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride request canceled.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel ride request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Nearby drivers list: ${widget.driverDetailsList}");
    return Column(
      children: widget.driverDetailsList.map((driverDetails) {
        bool isRequested = _requestedDriverId == driverDetails['driverId'];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Icon(Icons.directions_car, color: AppColors.secondary.value),
            title: Text(
              driverDetails['name'] ?? 'Unknown Driver',
              style: TextStyle(fontSize: 16.0),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle: ${driverDetails['vehicleName']} ${driverDetails['number']}',
                  style: TextStyle(fontSize: 14.0, color: AppColors.textGrey),
                ),
                Text(
                  'Color: ${driverDetails['color']}',
                  style: TextStyle(fontSize: 14.0, color: AppColors.textGrey),
                ),
                Text(
                  'Phone: ${driverDetails['phone']}',
                  style: TextStyle(fontSize: 14.0, color: AppColors.textGrey),
                ),
                SizedBox(height: 10.0),
                ElevatedButton(
                  onPressed: isRequested
                      ? () => cancelRideRequest(driverDetails['driverId'])
                      : () => requestRide(driverDetails['driverId']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRequested
                        ? Colors.red
                        : AppColors.secondary.value, // Customize button color                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(
                    isRequested ? 'Cancel Request' : 'Request Ride',
                    style: TextStyle(fontSize: 16.0, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  @override
  void dispose() {
    _rideRequestSubscription?.cancel();
    _driverLocationSubscription?.cancel(); // Add this line
    super.dispose();
  }
}
