import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class RideCompletionDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final String fare;
  final String driverName;
  final bool isDriver;

  const RideCompletionDialog({
    Key? key,
    required this.onConfirm,
    required this.fare,
    required this.driverName,
    this.isDriver = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Ride Completed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 15),
            Text(
              isDriver
                  ? 'You have completed the trip.'
                  : 'You have reached your destination.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              isDriver ? 'Earnings:' : 'Fare:',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '$fare',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary.value,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary.value,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'CONFIRM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}