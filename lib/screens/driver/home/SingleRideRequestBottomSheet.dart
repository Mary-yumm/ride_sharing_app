// lib/screens/driver/home/SingleRideRequestBottomSheet.dart
import 'package:flutter/material.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class SingleRideRequestBottomSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  final String requestId;
  final Function(String) onAccept;
  final Function(String) onReject;

  const SingleRideRequestBottomSheet({
    Key? key,
    required this.request,
    required this.requestId,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 8.0,
      margin: EdgeInsets.all(10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ride Request",
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.green),
                  title: Text("Pickup Location"),
                  subtitle: Text(request['pickupLocation'] ?? 'Unknown location'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.red),
                  title: Text("Drop-off Location"),
                  subtitle: Text(request['destination'] ?? 'Unknown location'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.payment, color: AppColors.primary),
                  title: Text("Fare"),
                  subtitle: Text("Rs${request['fare'] ?? 'N/A'}"),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(height: 10),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => onAccept(requestId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white
                  ),
                  child: Text("Accept"),
                ),
                ElevatedButton(
                  onPressed: () => onReject(requestId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white
                  ),
                  child: Text("Reject"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}