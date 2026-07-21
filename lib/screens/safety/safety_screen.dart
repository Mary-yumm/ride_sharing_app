import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class SafetyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(
        children: [
          // First Row: Support and Emergency Contacts
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2, // Two columns in the grid
              crossAxisSpacing: 16.0, // Space between columns
              mainAxisSpacing: 16.0, // Space between rows
              shrinkWrap: true, // Prevent GridView from taking up infinite height
              physics: NeverScrollableScrollPhysics(), // Disable scrolling inside GridView
              children: [
                _buildOptionCard(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Support',
                ),
                _buildOptionCard(
                  context,
                  icon: Icons.contacts,
                  label: 'Emergency contacts',
                ),
              ],
            ),
          ),
          SizedBox(height: 5.0),

          // Call Emergency Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  // Handle emergency call
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 8.0),
                    Text(
                      'Call emergency',
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 5.0),
          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'How you\'re protected',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          // GridView for Protection Options
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                children: [
                  _buildOptionCard(context, label: 'Before the ride', icon: Icons.key),
                  _buildOptionCard(
                      context,
                      label: 'Driver identity\nand selfie verification',
                      icon: Icons.account_circle),
                  _buildOptionCard(context, label: 'Safety features', icon: Icons.check_circle),
                  _buildOptionCard(context, label: '24/7 emergency chat', icon: Icons.support_agent),
                  _buildOptionCard(context, label: 'How we check cars', icon: Icons.car_repair),
                  _buildOptionCard(context, label: 'Safe communications', icon: Icons.message),
                ],
              ),
            ),
          ),
        ],
      ),
      //backgroundColor: Colors.black,
    );
  }

  Widget _buildOptionCard(BuildContext context, {required String label, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40.0, color: AppColors.secondary.value),
          SizedBox(height: 16.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
