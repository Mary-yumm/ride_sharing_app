import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_sharing_app/screens/driver/driver_ride_history_screen.dart';
import 'package:ride_sharing_app/screens/home/home_screen.dart';
import 'package:ride_sharing_app/screens/nav_bar_screen.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:ride_sharing_app/widgets/auth.dart'; // Import your Auth class
import 'package:ride_sharing_app/screens/settings/settings_screen.dart';
import 'package:ride_sharing_app/screens/help/help_screen.dart';
import 'package:ride_sharing_app/screens/safety/safety_screen.dart';
import 'package:ride_sharing_app/screens/driver/driver_registration_page.dart';
import 'package:ride_sharing_app/screens/driver/home/driver_home_screen.dart';


class DriverHamburgerMenuScreen extends StatefulWidget {
  @override
  _DriverHamburgerMenuScreenState createState() => _DriverHamburgerMenuScreenState();
}

class _DriverHamburgerMenuScreenState extends State<DriverHamburgerMenuScreen> {
  final Auth _auth = Auth.instance; // Instantiate your Auth class
  int _currentIndex = 0;

  // Screens for navigation
  late final List<Widget> _screens;
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();

    _screens = [
      DriverHomeScreen(),
      DriverRequestHistoryScreen(),
      Center(child: Text('Settings Screen')),
    ];

    _titles = [
      'Driver Home',
      'Request History',
      'Settings',
    ];
  }



  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu, color: Theme.of(context).hintColor),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: Text(
          _titles[_currentIndex], // Dynamic title
          style: TextStyle(
            color: Theme.of(context).hintColor, // Title color
            fontSize: 20, // Font size
            fontWeight: FontWeight.bold, // Font weight
          ),
        ),
        elevation: 4.0, // Default elevation for shadow
        shadowColor: Colors.black.withOpacity(0.3), // Customize shadow color
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).cardColor,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ), // Optional: Add gradient to the AppBar
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10.0,
                offset: Offset(0, 4), // Shadow below the AppBar
              ),
            ],
          ),
        ),
        // bottom: PreferredSize(
        //   preferredSize: Size.fromHeight(4.0), // Optional: Divider height
        //   child: Container(
        //     color: Theme.of(context).dividerColor, // Divider color
        //     height: 1.0, // Divider thickness
        //   ),
        // ),
      ),

      drawer: Drawer(
        child: Container(
          color: Theme.of(context).primaryColor, // Change this to your desired background color
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: AppColors.lightGrey),
                accountName: Text(
                  user?.displayName ?? 'User', // Use displayName if available, otherwise "User"
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(
                  user?.email ?? 'No email found', // Display user's email
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: AppColors.primary),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildListTile(Icons.car_rental, 'City', 0),
                    _buildListTile(Icons.history, 'Request History', 1),
                    _buildListTile(Icons.settings, 'Settings', 2),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => HamburgerMenuScreen()),
                        );

                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary.value,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Rider Mode",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _screens[_currentIndex],
    );
  }

  Widget _buildListTile(IconData icon, String title, int index) {
    final isSelected = _currentIndex == index; // Check if this tile is selected

    return Container(
      color: isSelected ? AppColors.secondary.value : Colors.transparent, // Set secondary color for the selected tile
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Theme.of(context).hintColor, // White icon for selected tile
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).hintColor, // White text for selected tile
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // Optional: bold text for selected tile
          ),
        ),
        onTap: () {
          setState(() {
            _currentIndex = index; // Update the current index
          });
          Navigator.pop(context); // Close the drawer
        },
      ),
    );
  }



}
