import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isNightMode = false; // Example state variable for Night Mode
  final Auth _auth = Auth.instance; // Use the singleton instance

  Future<void> _logout() async {
    try {
      // Add your logout logic here
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users/${currentUser.uid}')
            .update({'fcmToken': null});
      }
      await _auth.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out. Please try again.')),
      );
    }
  }

  void _pickColor() async {
    // Show color picker dialog
    Color selectedColor = AppColors.secondary.value;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Change App Color"),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (Color color) {
                setState(() {
                  selectedColor = color;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Reset to default color
                selectedColor = const Color(0xFF4E5D94);
                AppColors.secondary.value = selectedColor;
                AppColors.saveColor(selectedColor);
                Navigator.of(context).pop();
              },
              child: const Text("Default"),
            ),
            TextButton(
              onPressed: () {
                AppColors.secondary.value = selectedColor;
                AppColors.saveColor(selectedColor);
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Phone Number
            _buildSettingsTile(
              title: 'Phone number',
              subtitle: '+92********95',
              onTap: () {},
            ),

            // Language
            // _buildSettingsTile(
            //   title: 'Language',
            //   subtitle: 'Default language',
            //   onTap: () {},
            // ),

            // Date and Distances
            // _buildSettingsTile(
            //   title: 'Date and distances',
            //   onTap: () {},
            // ),

            // Night Mode (Example with toggle functionality)
            // SwitchListTile(
            //   title: Text(
            //     'Night mode',
            //     style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
            //   ),
            //   subtitle: Text(
            //     _isNightMode ? 'Enabled' : 'Disabled',
            //     style: TextStyle(color: Colors.grey, fontSize: 14),
            //   ),
            //   value: _isNightMode,
            //   activeColor: Colors.white,
            //   onChanged: (bool value) {
            //     setState(() {
            //       _isNightMode = value;
            //     });
            //   },
            // ),

            // Secondary Color Picker
            _buildSettingsTile(
              title: 'Change App Color',
              subtitle: 'Customize the app theme',
              onTap: _pickColor,
            ),


            // Rules and Terms
            _buildSettingsTile(
              title: 'Rules and terms',
              onTap: () {},
            ),

            // Log Out
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: SizedBox(
                child: ValueListenableBuilder<Color>(
                  valueListenable: AppColors.secondary,
                  builder: (context, color, child) {
                    return TextButton(
                      onPressed: _logout,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.white,
                        backgroundColor: color, // Automatically updates with new color
                      ),
                      child: Text("Log Out"),
                    );
                  },
                ),
              ),
            ),


            // Delete Account
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () {
                  print("Delete account clicked");
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create a settings tile
  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
      ),

      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}
