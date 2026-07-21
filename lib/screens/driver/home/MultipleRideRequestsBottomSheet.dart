// lib/screens/driver/home/MultipleRideRequestsBottomSheet.dart
import 'package:flutter/material.dart';

class MultipleRideRequestsBottomSheet extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> requests;
  final Function(String) onAccept;
  final Function(String) onReject;

  const MultipleRideRequestsBottomSheet({
    Key? key,
    required this.requests,
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
              "Multiple Ride Requests (${requests.length})",
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 300, // Adjust height as needed
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final requestId = requests[index].key;
                  final request = requests[index].value;

                  return ListTile(
                    title: Text(request['destination'] ?? 'Unknown destination'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("From: ${request['pickupLocation'] ?? 'Unknown'}"),
                        Text("Fare: ₹${request['fare'] ?? 'N/A'}"),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => onAccept(requestId),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => onReject(requestId),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}