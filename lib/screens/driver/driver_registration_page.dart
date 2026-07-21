import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_sharing_app/screens/driver/driver_nav_bar_screen.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import '../../widgets/auth.dart';
import 'package:ride_sharing_app/screens/driver/home/driver_home_screen.dart';


class DriverRegistrationPage extends StatefulWidget {
  @override
  _DriverRegistrationPageState createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  final _vehicleNameController = TextEditingController();
  final _numberController = TextEditingController();
  final _colorController = TextEditingController();

  final Auth _auth = Auth.instance;

  String _selectedOption = 'Car'; // Default vehicle type
  bool _isLoading = false; // Loading state

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Driver Registration", // Dynamic title
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
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Option',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedOption = 'Car';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedOption == 'Car'
                            ? AppColors.secondary.value
                            : Colors.grey,
                        foregroundColor: AppColors.white
                      ),
                      child: Text('Car'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedOption = 'Bike';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedOption == 'Bike'
                            ? AppColors.secondary.value
                            : Colors.grey,
                        foregroundColor: AppColors.white
                      ),
                      child: Text('Bike'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Add Details',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _vehicleNameController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _numberController,
                decoration: InputDecoration(
                  labelText: 'Number',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _registerDriver,
                  child: Text('Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary.value,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),

                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registerDriver() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Fetch current user and their details
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is signed in.');
      }

      final uid = currentUser.uid;

      // Fetch email and phone from users/uid/
      final userSnapshot =
      await _database.child('users/$uid/').once(); // Read data once
      final userData = userSnapshot.snapshot.value as Map?;
      if (userData == null || !userData.containsKey('email') || !userData.containsKey('phone')) {
        throw Exception('User details not found.');
      }

      final email = userData['email'];
      final phone = userData['phone'];
      final name = userData['name'];

      // Step 2: Generate a unique did for the driver
      final newDriverRef = _database.child('drivers/').push();
      final did = newDriverRef.key; // Get the unique key

      if (did == null) throw Exception('Failed to generate driver ID.');

      // Step 3: Store driver details in drivers/did/profile/
      await _database.child('drivers/$did/profile/').set({
        'email': email,
        'name': name,
        'phone': phone,
        'vehicleType': _selectedOption,
        'vehicleName': _vehicleNameController.text.trim(),
        'number': _numberController.text.trim(),
        'color': _colorController.text.trim(),
      });
      // Update the Auth instance with the driver ID
      Auth.instance.setDriverId(did);

      // Step 4: Update the user's node with the driverId
      await _database.child('users/$uid/').update({
        'driverId': did,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver registered successfully!'),
          duration: Duration(seconds: 3),
        ),
      );

      // Clear fields
      _vehicleNameController.clear();
      _numberController.clear();
      _colorController.clear();
      setState(() {
        _selectedOption = 'Car'; // Reset to default
      });
      // Navigate to Driver Home Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DriverHamburgerMenuScreen()),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _numberController.dispose();
    _colorController.dispose();
    super.dispose();
  }
}

void main() {
  runApp(MaterialApp(
    home: DriverRegistrationPage(),
  ));
}
