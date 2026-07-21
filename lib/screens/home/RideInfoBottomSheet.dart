import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:ride_sharing_app/screens/home/chat_screen.dart';
import 'package:ride_sharing_app/providers/directions_service.dart';
import 'package:ride_sharing_app/providers/GeolocationService.dart';
import 'package:ride_sharing_app/providers/driver_service.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';

import '../../configMaps.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../providers/fare_service.dart';
import '../../providers/places_helper.dart';
import 'autocomplete_dropdown.dart';


class RideInfoBottomSheet extends StatefulWidget {
  final VoidCallback onCancel;
  final Map<String, dynamic> driverDetails;
  late final String activeOrAccepted;
  final Function? onRideComplete;
  final Function? onRideUpdate;

  RideInfoBottomSheet({
    Key? key,
    required this.onCancel,
    required this.driverDetails,
    required this.activeOrAccepted,
    this.onRideComplete,
    this.onRideUpdate,

  }) : super(key: key);

  @override
  _RideInfoBottomSheetState createState() => _RideInfoBottomSheetState();
}

class _RideInfoBottomSheetState extends State<RideInfoBottomSheet> {
  late Timer _timer;
  int _timeToArrival = 10; // Example initial time to arrival in minutes
  //late final _driverLocation;
  final DirectionsService _directionsService = DirectionsService(mapKey); // Replace with your actual API key
  final GeolocationService _geolocationService = GeolocationService();
  final DriverService _driverService = DriverService();
  final RideRequestsService _rideRequestsService = RideRequestsService();
  LatLng? _driverLocation;
  final StreamController<int> _timeToArrivalController = StreamController<int>.broadcast();
  final StreamController<int> _timeToDestinationController = StreamController<int>.broadcast();
  Map<String, dynamic>? rideRequest;
  Map<String, dynamic>? _userInfo;
  String? _liveRideStatus;
  DatabaseReference? _liveRideStatusRef;
  StreamSubscription? _liveRideStatusSubscription;
  bool _isChangingDestination = false;
  TextEditingController _newDestinationController = TextEditingController();
  String? _originalDestination;
  double? _originalFare;
  List<dynamic> _predictions = [];
  String _selectedField = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _liveRideStatus = widget.activeOrAccepted; // Use initial value
    _startTimer();
    _loadRideRequest(); // Use a separate method instead of await in initState
    _listenToRideStatusChanges();
    _setupLiveRideStatusListener(); // Add this new method
    _newDestinationController = TextEditingController(text: rideRequest!['destination']);

    _fetchDriverAndRideDetails();
    _fetchUserInfo();
    print('Driver Details in ride info: ${widget.driverDetails}');
  }

  // Add this new method to set up the live ride status listener
  void _setupLiveRideStatusListener() {
    if (widget.driverDetails['driverId'] == null || rideRequest == null || rideRequest!['requestId'] == null) {
      print('Missing driver ID or request ID, cannot set up status listener');
      return;
    }

    String driverId = widget.driverDetails['driverId'];
    String requestId = rideRequest!['requestId'];

    // Cancel any existing subscription
    _liveRideStatusSubscription?.cancel();

    // Use the more efficient stream to monitor only the status field
    _liveRideStatusSubscription = _rideRequestsService
        .getRideStatusStream(driverId, requestId)
        .listen((status) {
      if (status != null && mounted) {
        print('Live Ride Status Updated: $status');

        setState(() {
          _liveRideStatus = status;
        });

        if (status == 'completed') {
          _handleRideCompletion();
        }
      }
    },
        onError: (error) {
          print('Error in ride status listener: $error');
        });
  }

  void _listenToRideStatusChanges() {
    print('Listening to ride status changes...');
    String userId = FirebaseAuth.instance.currentUser!.uid;

    // Cancel any existing subscription first
    _liveRideStatusSubscription?.cancel();

    if (widget.driverDetails['driverId'] == null || rideRequest == null || rideRequest!['requestId'] == null) {
      print('Missing required IDs for status listener, will retry later');
      // Schedule a retry after ride request is loaded
      Future.delayed(Duration(seconds: 2), () {
        if (mounted && rideRequest != null) {
          _listenToRideStatusChanges();
        }
      });
      return;
    }

    String driverId = widget.driverDetails['driverId'];
    String requestId = rideRequest!['requestId'];

    // Use the more efficient stream that only listens to the status field
    _liveRideStatusSubscription = _rideRequestsService
        .getRideStatusStream(driverId, requestId)
        .listen((status) {
      if (status != null && mounted) {
        print('Ride status update: $status');

        setState(() {
          _liveRideStatus = status;
        });

        if (status == 'active' && widget.activeOrAccepted == 'accepted') {
          print('Ride status changed to active!');
          // Update the status in the state
          setState(() {
            _liveRideStatus = 'active';
          });
          print('Updated ride status to active: $_liveRideStatus');
        }
        else if (status == 'completed') {
          print('Ride completed! Closing bottom sheet...');
          _handleRideCompletion();
        }
      }
    },
        onError: (error) {
          print('Error in ride status listener: $error');
        });
  }

// Extract ride completion logic to a separate method
  void _handleRideCompletion() {
    // Cancel any active subscriptions first
    _timer.cancel();
    _liveRideStatusSubscription?.cancel();
    _timeToArrivalController.close();
    _timeToDestinationController.close();

    // Close the bottom sheet
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Call the completion callback if provided
    if (widget.onRideComplete != null) {
      widget.onRideComplete!();
    }
  }

  // Add helper methods for null safety
  String getPickupLocation() {
    return rideRequest?['pickupLocation'] ?? 'Unknown location';
  }

  String getDestination() {
    return rideRequest?['destination'] ?? 'Unknown destination';
  }

  String getFare() {
    return rideRequest?['fare']?.toString() ?? '0';
  }

  Future<void> _loadRideRequest() async {
    try {
      String driverId = widget.driverDetails['driverId'];
      String riderId = FirebaseAuth.instance.currentUser!.uid;

      print('Loading ride request for driver: $driverId and rider: $riderId');

      if (driverId != null) {
        final acceptedRide = await _rideRequestsService.getAcceptedRideRequest(riderId);
        print('Fetched ride request data: $acceptedRide');

        if (mounted && acceptedRide != null) {
          setState(() {
            rideRequest = acceptedRide;
            print('Found alternate ride data: $rideRequest');
          });
        }
      }
    } catch (e) {
      print('Error fetching ride request: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchDriverAndRideDetails();
      }
    });
  }

  @override
  void dispose() {
    _liveRideStatusSubscription?.cancel();
    _newDestinationController.dispose();
    _timer.cancel();
    _timeToArrivalController.close();
    _timeToDestinationController.close();
    super.dispose();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    double dLng = _degreesToRadians(point2.longitude - point1.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) * cos(_degreesToRadians(point2.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _fetchDriverAndRideDetails() async {
    print('Fetching driver and ride details...');
    String driverId = widget.driverDetails['driverId'];
    String userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Fetch driver location
      final driverLocation = await _driverService.fetchDriverLocation(driverId);
      print('Driver Location: $driverLocation');

      if (driverLocation != null) {
        _driverLocation = driverLocation;
      } else {
        throw Exception('Driver location is null');
      }

      // Fetch ride request details
      print('Ride Request: $rideRequest');

      if (_driverLocation != null && rideRequest != null) {
        // Fetch rider location
        final riderLocation = await _geolocationService.getCurrentLocation();
        print('Rider Location: $riderLocation');
        // print active or accepted
        print('Active or Accepted: ${_liveRideStatus}');

        if (_liveRideStatus == 'active') {
          // Fetch directions to the destination
          String? destination = rideRequest?['destination'];
          if(destination!=null && destination.isNotEmpty) {
            final destinationLocation = await _directionsService.getCoordinates(
                destination);
            final directions = await _directionsService.getDirections(
              origin: _driverLocation!,
              destination: destinationLocation,
              mode: 'driving',
            );
            print('Directions: $directions');

            final durationText = directions['durationText'] as String;
            final durationValue = directions['durationValue'] as int;
            print(
                'Duration to destination: $durationText ($durationValue seconds)');

            setState(() {
              _timeToArrival =
                  (durationValue / 60).round(); // Convert seconds to minutes
              _timeToDestinationController.add(_timeToArrival); // Add to stream
              print('Updated Time to Destination: $_timeToArrival minutes');
            });
          }
        }
        else if (_liveRideStatus == 'accepted') {
          // Fetch directions to the pickup location
          String? pickup = rideRequest?['pickupLocation'];
          if(pickup!=null && pickup.isNotEmpty) {
            final pickupLocation = await _directionsService.getCoordinates(
                pickup);
            final directions = await _directionsService.getDirections(
              origin: _driverLocation!,
              destination: pickupLocation,
              mode: 'driving',
            );
            print('Directions: $directions');

            final durationText = directions['durationText'] as String;
            final durationValue = directions['durationValue'] as int;
            print('Duration to pickup: $durationText ($durationValue seconds)');

            setState(() {
              _timeToArrival =
                  (durationValue / 60).round(); // Convert seconds to minutes
              _timeToArrivalController.add(_timeToArrival); // Add to stream
              print('Updated Time to Arrival: $_timeToArrival minutes');
            });

            // Check if the driver has reached the pickup location
            LatLng riderLocationLatLng = LatLng(
                riderLocation!.latitude, riderLocation.longitude);
            double distance = _calculateDistance(
                _driverLocation!, riderLocationLatLng);
            print('Distance to pickup: $distance meters');

            // if (distance <= 5) { // Threshold distance in meters
            //   print('Driver has reached the pickup location!');
            //   // Update the status of the ride to "started"
            //   await _rideRequestsService.updateAcceptedRideToStarted(userId);
            //
            //   // Update the widget variable to reflect the active ride
            //   widget.onStatusChange('active');
            // }
          }
        }
      }
    } catch (e) {
      print('Error fetching driver or ride details: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    String driverId = widget.driverDetails['driverId'];
    final DatabaseReference ref = FirebaseDatabase.instance.ref("users");
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final users = snapshot.value as Map<dynamic, dynamic>;
      for (var userId in users.keys) {
        final user = users[userId] as Map<dynamic, dynamic>;
        if (user['driverId'] == driverId) {
          setState(() {
            _userInfo = {
              'fcmToken': user['fcmToken'],
            };
          });
          break;
        }
      }
    }
  }


  Future<List<String>> _fetchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return [];
    }

    try {
      final suggestions = await PlacesHelper.fetchAutocompleteSuggestions(input, 'PK');
      if (mounted) {
        setState(() {
          _predictions = suggestions;
        });
      }
      return suggestions.map<String>((suggestion) => suggestion['description'] as String).toList();

    } catch (e) {
      print('Error fetching predictions: $e');
      return [];
    }
  }

// Change Destination

  Future<void> _processDestinationChange(String newDestination) async {
    if (newDestination.isEmpty || newDestination == getDestination()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _originalDestination = getDestination();
      _originalFare = double.tryParse(getFare()) ?? 0.0;
    });

    try {
      // Calculate new fare based on the new destination
      double newFare = await _calculateFareForNewDestination(newDestination);

      // Show confirmation dialog
      bool confirmed = await _showFareChangeConfirmationDialog(newFare);
      if (!confirmed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      String? driverId = rideRequest?['driver_id'] as String?;
      String? requestId = rideRequest?['requestId'] as String?;

      if (driverId != null && requestId != null) {
        // Update the ride request in Firebase
      await RideRequestsService().updateRideRequestDestination(
          driverId,
          rideRequest!['requestId'] as String,
          newDestination,
          newFare
      );

      // Update the local state
      setState(() {
        rideRequest!['destination'] = newDestination;
        rideRequest!['fare'] = newFare;
      });

      // Send notification to driver
      //String? driverId = widget.driverDetails['driverId'];
      // String? driverFcmToken = await RideRequestsService()
      //     .fetchFcmTokenByDriverId(driverId);

      // if (driverFcmToken != null) {
      //   // Send notification to driver via FCM
      //   await FirebaseFirestore.instance.collection('notifications').add({
      //     'title': 'Destination Changed',
      //     'body': 'The rider has changed their destination',
      //     'recipientId': driverId,
      //     'senderId': FirebaseAuth.instance.currentUser!.uid,
      //     'timestamp': FieldValue.serverTimestamp(),
      //     'type': 'destination_change',
      //     'read': false,
      //     'rideRequestId': rideRequest!.key,
      //   });
      // }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destination updated successfully')),
      );

      // Refresh the map and polylines
      if (widget.onRideUpdate != null) {
        widget.onRideUpdate!();
      }
    }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update destination: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<double> _calculateFareForNewDestination(String newDestination) async {
    try {
      final String pickup = rideRequest!['pickup'] ?? '';
      final String selectedOption = rideRequest!['selectedOption'] ?? '';

      // Calculate fare using FareService
      double calculatedFare = await FareService.calculateFareFromLocations(
        pickup,
        newDestination,
        selectedOption,
      );

      return calculatedFare;
    } catch (e) {
      debugPrint('Error calculating new fare: $e');
      throw Exception('Could not calculate new fare');
    }
  }

  Future<bool> _showFareChangeConfirmationDialog(double newFare) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Destination Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original destination: $_originalDestination'),
            Text('New destination: ${_newDestinationController.text}'),
            SizedBox(height: 8),
            Text('Original fare: Rs${_originalFare?.toStringAsFixed(2)}'),
            Text('New fare: Rs${newFare.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Do you want to change your destination?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showChangeDestinationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Destination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newDestinationController,
              decoration: InputDecoration(
                labelText: 'New Destination',
                hintText: 'Enter new destination',
                prefixIcon: Icon(Icons.location_on),
              ),
              onChanged: (value) async {
                if (value.length > 2) {
                  List<String> suggestions = await _fetchSuggestions(value);
                  setState(() {
                    _predictions = suggestions;
                  });
                }
              },
            ),
            if (_predictions.isNotEmpty)
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_predictions[index]),
                      onTap: () {
                        _newDestinationController.text = _predictions[index];
                        setState(() {
                          _predictions = [];
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processDestinationChange(_newDestinationController.text);
            },
            child: Text('Change'),
          ),
        ],
      ),
    );
  }
// Show waiting dialog while driver decides
  void _showWaitingForDriverApprovalDialog(String destination, double additionalFare, double totalFare) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Waiting for Driver Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('New destination: $destination'),
            SizedBox(height: 10),
            Text('Additional fare: Rs${additionalFare.toStringAsFixed(2)}'),
            Text('New total: Rs${totalFare.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

// Handle accepted destination change
  void _updateRideWithNewDestination(String newDestination, LatLng coords, double newFare) {
    // Close waiting dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Update local ride request data
    setState(() {
      rideRequest!['destination'] = newDestination;
      rideRequest!['destinationLat'] = coords.latitude;
      rideRequest!['destinationLng'] = coords.longitude;
      rideRequest!['fare'] = newFare.toStringAsFixed(2);
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Destination changed successfully')),
    );

    // Refresh the map and polylines
    if (widget.onRideUpdate != null) {
      widget.onRideUpdate!();
    }
  }

// Handle rejected destination change
  void _handleRejectedDestinationChange() {
    // Close waiting dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show rejection message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Driver declined the destination change request')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_predictions.isNotEmpty) {
        setState(() {
          _predictions = [];
        });

    }
    return SizedBox(
      width: double.infinity, // Ensures full width
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              offset: Offset(0, -5),
            ),
          ],
          gradient: LinearGradient(
            colors: [Theme.of(context).primaryColor, Theme.of(context).cardColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: _liveRideStatus == 'active'
                    ? _timeToDestinationController.stream
                    : _timeToArrivalController.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      _liveRideStatus == 'active'
                          ? 'Estimated time to destination ~ ${snapshot.data} minutes'
                          : 'Estimated Arrival ~ ${snapshot.data} minutes',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    );
                  } else {
                    return Text(
                      'Calculating...',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 16.0),

              // Driver details card
              // For the driver details card - add chat button on the right
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Driver Details',
                            style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary
                            ),
                          ),

                        ],
                      ),
                      SizedBox(height: 5.0),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Icon(Icons.person, color: AppColors.primary),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.driverDetails['name']}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${widget.driverDetails['vehicleName']} ${widget.driverDetails['number']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chat button on the right side
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    driverId: widget.driverDetails['driverId'],
                                    riderId: FirebaseAuth.instance.currentUser!.uid,
                                    phone: widget.driverDetails['phone'],
                                    fcmToken: _userInfo!['fcmToken'],
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.chat, color: AppColors.secondary.value),
                            tooltip: 'Chat with driver',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 5.0),

              // Ride details card (this is the card you already added)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Details',
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary
                        ),
                      ),
                      SizedBox(height: 12.0),
                      // Add Change Destination button (only if ride is active)
                      if (_liveRideStatus == 'active')
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isChangingDestination = true;
                              _predictions = [];
                            });
                            _showChangeDestinationDialog(context);
                          },
                          icon: Icon(Icons.edit_location),
                          label: Text('Change Destination'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getPickupLocation(),
                              style: TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Container(
                          height: 25,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getDestination(),
                              style: TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.0),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.payment, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Rs${getFare()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Cancel button on right side
                            ElevatedButton.icon(
                              onPressed: widget.onCancel,
                              icon: Icon(Icons.cancel, size: 18, color: AppColors.white),
                              label: Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }

}