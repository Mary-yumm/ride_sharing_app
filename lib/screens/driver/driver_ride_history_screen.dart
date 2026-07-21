import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

import '../../widgets/auth.dart';

class DriverRequestHistoryScreen extends StatefulWidget {
  @override
  _DriverRequestHistoryScreenState createState() => _DriverRequestHistoryScreenState();
}

class _DriverRequestHistoryScreenState extends State<DriverRequestHistoryScreen> {
  final RideRequestsService _rideRequestsService = RideRequestsService();
  late Future<List<Map<String, dynamic>>> _rideRequestsFuture;

  @override
  void initState() {
    super.initState();
    _loadRideRequests();
  }

  void _loadRideRequests() {
    String? driverId = Auth.instance.driverId;
    if (driverId != null) {
      setState(() {
        _rideRequestsFuture = _rideRequestsService.fetchCompletedRidesForDriver(driverId);
      });
    } else {
      setState(() {
        _rideRequestsFuture = Future.value([]);
      });
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

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Ride to $destination',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                          ),
                          SizedBox(height: 10),
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
                              Text('Fare: Rs ${fare.toString()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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