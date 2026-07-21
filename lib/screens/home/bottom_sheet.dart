import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:ride_sharing_app/configMaps.dart';
import '../../providers/fare_service.dart';
import '../../providers/location_helper.dart';
import '../../widgets/auth.dart';
import 'active_nearby_available_drivers.dart';
import 'cash_bottom_sheet.dart';
import 'nearby_drivers.dart';
import 'options_bottom_sheet.dart';
import 'package:ride_sharing_app/providers/places_helper.dart';
import 'package:ride_sharing_app/screens/home/autocomplete_dropdown.dart';
import '../../providers/driver_service.dart'; // Import the DriverService
import 'package:ride_sharing_app/screens/home/active_nearby_available_drivers.dart';


class BottomSheetContent extends StatefulWidget {

  final ValueNotifier<LatLng> locationNotifier;
  final void Function(String pickup, String destination) onFindDriver; // Modify the callback type
  final List<ActiveNearByAvailableDrivers> nearbyDrivers;
  final VoidCallback onShowPreviousBottomSheet; // Add this line
  final void Function(String driverId) onDriverSelected; // Add this line


  const BottomSheetContent({
    Key? key,
    required this.locationNotifier,
    required this.onFindDriver, // Add to the constructor
    required this.nearbyDrivers,
    required this.onShowPreviousBottomSheet,
    required this.onDriverSelected, // Add this line

  }) : super(key: key);

  @override
  _BottomSheetContentState createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<BottomSheetContent> {
  // Track the selected option
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _fareController = TextEditingController();
  String _selectedOption = '';
  String _locationName = 'Fetching location...';
  List<dynamic> _predictions = [];
  String _selectedField = '';
  Set<Polyline> _polylines = {};
  bool _showNearbyDrivers = false;
  final DriverService _driverService = DriverService();

  List<Map<String, dynamic>> _driverDetailsList = []; // List to store driver details
  final Auth _auth = Auth.instance; // Use the singleton instance


  @override
  void initState() {
    print('init'); // Log the error

    super.initState();
    widget.locationNotifier.addListener(_onLocationUpdated);

    // Add listener to update UI when controller changes
    _fromController.addListener(() {
      if(mounted) {
        setState(() {}); // Triggers UI update when the controller's text changes
      }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocationDetails(widget.locationNotifier.value));
  }

  // Fetch location details when the location is updated
  void _onLocationUpdated() {
    _fetchLocationDetails(widget.locationNotifier.value);
  }

  // Improved location name fetching with error handling
  Future<void> _fetchLocationDetails(LatLng location) async {
    try {
      final locationName = await LocationHelper.getLocationName(location);
      print('Fetched Location Name: $locationName');
      print('Location Coordinates: '
          'Latitudee: ${location.latitude}, '
          'Longitudee: ${location.longitude}');
      if(mounted) {
        setState(() {
          _locationName = locationName;
          _fromController.text = locationName; // Pre-fill "From" field
        });
      }

    } catch (e) {
      if(mounted) {
        setState(() {
          _locationName = 'Unable to fetch location';
        });
      }
      print('Error fetching location details: $e'); // Log the error
      _showErrorSnackBar('Error fetching location details');
    }
  }

  // Show error messages to the user
  void _showErrorSnackBar(String message) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch autocomplete suggestions with improved error handling
  // Fetch autocomplete suggestions using the PlacesHelper
  Future<void> _fetchSuggestions(String input) async {
    final suggestions = await PlacesHelper.fetchAutocompleteSuggestions(input, 'pk');
    if(mounted) {
      setState(() {
        _predictions = suggestions;
      });
    }
  }


  @override
  void dispose() {
    // Remove the listener to avoid memory leaks
    widget.locationNotifier.removeListener(_onLocationUpdated);
    _fromController.removeListener(() {});
    _fromController.dispose();
    _toController.dispose();
    _fareController.dispose();
    super.dispose();
  }

  // Helper function to determine the background color
  Color _getBackgroundColor(String option) {
    return _selectedOption == option ? AppColors.secondary.value : AppColors.textGrey;
  }

  Future<void> _fetchDriverDetails() async {
    List<Map<String, dynamic>> driverDetails = [];
    for (var driver in widget.nearbyDrivers) {
      if (driver.driverId != null) {
        var details = await _driverService.fetchDriverDetails(driver.driverId!);
        print("Fetched driver details for ${driver.driverId}: $details");

        if (details != null) {
          details['driverId'] = driver.driverId!;
          driverDetails.add(details);
        }
      }
    }
    if(mounted) {
      setState(() {
        _driverDetailsList = driverDetails;
        _showNearbyDrivers = true;
      });
    }
  }

  Future<void> _calculateAndUpdateFare() async {
    if (_fromController.text.isNotEmpty && _toController.text.isNotEmpty && _selectedOption.isNotEmpty) {
      try {
        // Show loading indicator in fare field
        _fareController.text = "Calculating...";

        // Calculate fare using FareService
        double calculatedFare = await FareService.calculateFareFromLocations(
            _fromController.text,
            _toController.text,
            _selectedOption
        );

        // Update the fare controller
        if (mounted) {
          setState(() {
            _fareController.text = '${calculatedFare.toString()}';
          });
        }
      } catch (e) {
        print('Error calculating fare: $e');
        if (mounted) {
          _fareController.text = 'Calculation failed';
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Clear predictions when the bottom sheet is rebuilt
    if (_predictions.isNotEmpty) {
      if(mounted) {
        setState(() {
          _predictions = [];
        });
      }
    }
    return Stack(
      children:[
     Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Background color of the bottom sheet
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Shadow color
            blurRadius: 10.0, // How blurry the shadow is
            offset: Offset(0, -5), // Shadow position
          ),
        ],
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).cardColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ), // Optional: Add a subtle gradient
      ),
      child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOption('Ride AC', Icons.ac_unit, 'ride_ac'),
              _buildOption('Ride', Icons.directions_car, 'ride'),
              _buildOption('Ride Mini', Icons.electric_car, 'ride_mini'),
              _buildOption('Rickshaw', Icons.electric_rickshaw, 'rickshaw'),
              _buildOption('Van', Icons.directions_bus, 'van'),

            ],
          ),
          SizedBox(height: 10.0),
          Text(
            'Location: $_locationName',
            style: TextStyle(color: AppColors.textGrey, fontSize: 16.0),
          ),
          SizedBox(height: 10.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAutocompleteField(
                controller: _fromController,
                hintText: 'From',
                prefixIcon: Icons.location_on,
              ),
              SizedBox(height: 10.0),
              _buildAutocompleteField(
                controller: _toController,
                hintText: 'To',
                prefixIcon: Icons.search,
              ),
              SizedBox(height: 10.0),
              _buildFareField(),
            ],
          ),

          SizedBox(height: 10.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.money, color: Theme.of(context).hintColor),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => CashBottomSheet(),
                  );
                },
              ),
              Expanded(
                child: ElevatedButton(
                  child: Text('Find a driver'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    backgroundColor: AppColors.secondary.value,
                    minimumSize: Size(double.infinity, 48.0),

                  ), onPressed:() async {
                  print("Find Driver button pressed in BottomSheetContent");
                  if(mounted) {
                    setState(() {
                      _showNearbyDrivers = true; // Show the nearby drivers
                    });
                  }
                  widget.onFindDriver(_fromController.text, _toController.text);
                  await _fetchDriverDetails(); // Fetch driver details on button press

                },
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_horiz, color: Theme.of(context).hintColor),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => OptionsBottomSheet(),
                  );
                },
              ),

            ],
          ),
          SizedBox(height: 20.0),
          if (_showNearbyDrivers)
            NearbyDrivers(
              driverDetailsList: _driverDetailsList,
              userid: _auth.currentUser?.uid,
              pickup: _fromController.text,
              destination: _toController.text,
              selectedOption: _selectedOption,
              fare: _fareController.text,
              onShowPreviousBottomSheet: widget.onShowPreviousBottomSheet, // Add this line
              onDriverSelected: widget.onDriverSelected, // Pass the callback

            ),
        ],
      ),

      ),
    ),
        if (_predictions.isNotEmpty && _selectedField.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4, // Dynamic positioning below the text field
            left: 16.0,
            right: 16.0,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final suggestion = _predictions[index]['description'];
                  return ListTile(
                    title: Text(suggestion),
                    onTap: () {
                      if(mounted) {
                        setState(() {
                          if (_selectedField == 'from') {
                            _fromController.text = suggestion;
                          } else {
                            _toController.text = suggestion;
                          }
                          _predictions = [];
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ),
    ],
    );
  }


  Widget _buildFareField() {
    return TextField(
      controller: _fareController,
      readOnly: true, // Make it read-only as it's calculated automatically
      style: TextStyle(
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.bold
      ),
      decoration: InputDecoration(
        hintText: 'Fare will be calculated',
        labelText: 'Fare',
        hintStyle: TextStyle(color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.lightGrey,
        prefixIcon: Icon(Icons.attach_money, color: AppColors.textGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }


  // Widget to build each option
  Widget _buildOption(String label, IconData icon, String option) {
    return GestureDetector(
      onTap: () {
        if(mounted) {
          setState(() {
            _selectedOption = option;
          });
          _calculateAndUpdateFare();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _getBackgroundColor(option),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white),
          ),
          SizedBox(height: 4.0),
          Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
  // Helper method to build the Autocomplete field
  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
  }) {
    return GestureDetector(
      onTap: () {
        if(mounted) {
          setState(() {
            _predictions = []; // Clear predictions after selection
            _selectedField = hintText.toLowerCase(); // Track which field is selected

          });
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AutocompleteScreen(
              controller: controller,
              hintText: hintText,
              currentLocation: _locationName, // Pass the current location
              onSelected: (selectedValue) {
                if(mounted) {
                  setState(() {
                    controller.text = selectedValue;
                    _predictions = []; // Clear predictions after selection
                  });
                  // Calculate fare when a location is selected
                  _calculateAndUpdateFare();
                }
              },
              fetchSuggestions: (input) async {
                await _fetchSuggestions(input); // Existing fetch suggestions method
                return _predictions.map((e) => e['description'] as String).toList();
              },
            ),
          ),
        );
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
      ),
    );
  }

}
