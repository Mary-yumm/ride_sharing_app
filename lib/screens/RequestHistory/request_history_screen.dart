import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';
import 'package:ride_sharing_app/providers/driver_service.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class RequestHistoryScreen extends StatefulWidget {
  @override
  _RequestHistoryScreenState createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  final RideRequestsService _rideRequestsService = RideRequestsService();
  final DriverService _driverService = DriverService();
  late Future<List<Map<String, dynamic>>> _rideRequestsFuture;
  Map<String, Map<String, dynamic>> _driverDetails = {};

  @override
  void initState() {
    super.initState();
    _loadRideRequests();
  }

  void _loadRideRequests() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      setState(() {
        _rideRequestsFuture = _rideRequestsService.fetchCompletedRides(userId);
      });
    } else {
      setState(() {
        _rideRequestsFuture = Future.value([]);
      });
    }
  }
  Future<Map<String, dynamic>?> _fetchDriverDetails(String driverId) async {
    return await _driverService.fetchDriverDetails(driverId);
  }

  Future<void> _loadDriverDetails(String driverId) async {
    if (!_driverDetails.containsKey(driverId)) {
      final driverDetails = await _driverService.fetchDriverDetails(driverId);
      if (driverDetails != null) {
        setState(() {
          _driverDetails[driverId] = driverDetails;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _loadRideRequests();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _rideRequestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)));
            } else if (snapshot.data!.isEmpty) {
              return Center(
                child: Text('No ride history available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey)),
              );
            } else {
              final rideRequests = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: rideRequests.length,
                itemBuilder: (context, index) {
                  final rideRequest = rideRequests[index];
                  final pickupLocation = rideRequest['pickupLocation'];
                  final destination = rideRequest['destination'];
                  final fare = rideRequest['fare'];
                  final rideType = rideRequest['ride_type'];
                  final rideDate = rideRequest['date'];
                  final driverId = rideRequest['driverId'];

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchDriverDetails(driverId),
                    builder: (context, driverSnapshot) {
                      if (driverSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (driverSnapshot.hasError) {
                        return Center(child: Text('Error: ${driverSnapshot.error}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)));
                      } else {
                        final driverDetails = driverSnapshot.data;
                        final driverName = driverDetails?['name'];
                        final driverPhoneNumber = driverDetails?['phone'];

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: Colors.grey.withOpacity(0.3),
                          child: ExpansionTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                                    SizedBox(width: 6),
                                    Text('Date: 10-03-2025', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, color: Colors.green, size: 20),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$destination',
                                        style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (driverName != null && driverPhoneNumber != null) ...[
                                      Text('Driver Name: $driverName', style: TextStyle(fontSize: 16)),
                                      Text('Phone: $driverPhoneNumber', style: TextStyle(fontSize: 16)),
                                      SizedBox(height: 10),
                                    ],
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, color: Colors.red, size: 20),
                                        SizedBox(width: 6),
                                        Expanded(child: Text('Pickup: $pickupLocation', style: TextStyle(fontSize: 16))),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.attach_money, color: Colors.green, size: 20),
                                        SizedBox(width: 6),
                                        Text('Fare: Rs ${fare.toString()}', style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.car_rental, color: Colors.green, size: 20),
                                        SizedBox(width: 6),
                                        Text('Ride Type: ${rideType.toString()}', style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}