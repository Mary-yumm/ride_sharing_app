import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_sharing_app/configMaps.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:ride_sharing_app/providers/GeolocationService.dart';
import 'package:ride_sharing_app/providers/LocationPermissionHandler.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:ride_sharing_app/screens/driver/home/RiderInfoBottomSheet.dart';

import 'package:ride_sharing_app/providers/directions_service.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';
import '../../../Notifications/NotificationService.dart';
import '../../../widgets/auth.dart';
import '../../home/chat_screen.dart';
import '../../home/ride_completion_dialog.dart';
import 'ACControlWidget.dart';
import 'MultipleRideRequestsBottomSheet.dart';
import 'SimpleWaitingTimeWidget.dart';
import 'SingleRideRequestBottomSheet.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ride_sharing_app/providers/audio_service.dart';


class DriverHomeScreen extends StatefulWidget {
  @override
  _DriverHomeScreenState createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final Auth _auth = Auth.instance;
  final ValueNotifier<LatLng> _currentLocationNotifier =
  ValueNotifier(const LatLng(33.6844, 73.0479)); // Default location: Islamabad

  late GoogleMapController mapController;
  LatLng _currentLocation = const LatLng(33.6844, 73.0479); // Initialize with default
  bool _isLoading = true; // Loading state
  bool _isDriverActive = false; // Driver active state

  final GeolocationService _geolocationService = GeolocationService();
  final LocationPermissionHandler _permissionHandler = LocationPermissionHandler();

  // Polylines
  Set<Polyline> _polylines = {};
  Map<String, Map<String, dynamic>> rideRequests = {};

  // Bottom sheet controllers
  PersistentBottomSheetController? _rideRequestSheetController;
  PersistentBottomSheetController? _rideInfoSheetController;

 // Bottom sheet visibility flags
  bool _showRideRequestSheet = false;
  bool _showRideInfoSheet = false;
  Map<String, dynamic>? currentActiveRide;
  final DirectionsService _directionsService = DirectionsService(mapKey);
  // Add these variables
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  StreamSubscription<Position>? _locationSubscription;
  final RideRequestsService _rideRequestsService = RideRequestsService(); // Initialize the service
  Set<Marker> _markers = {}; // Add this line
  String? _acceptedRideRequestId;
  bool _isRideJustCompleted = false;
  final AudioService _audioService = AudioService();
  final String _safarKiDuaPath = 'sounds/safar_ki_dua.mp3';
  bool _showAudioControls = false;
  NotificationService notificationService = NotificationService();
  bool _userMovedCamera = false;


  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _setupLocationTracking();
    _listenForRideRequests();
    _fetchRideRequestData(); // Fetch ride request data
    // Add a slight delay to ensure everything is loaded before showing the sheet
    Future.delayed(Duration(milliseconds: 500), () {
      _showInitialBottomSheet();
    });


  }

  void _resetCurrentRide() {
    setState(() {
      _pickupLocation = null;
      _destinationLocation = null;
    });
  }

  // Add this method to toggle audio controls visibility
  void _toggleAudioControlsVisibility() {
    setState(() {
      _showAudioControls = !_showAudioControls;
    });
  }

  void _setupLocationTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      print('LOCATION UPDATE: New position received - lat: ${position.latitude}, lng: ${position.longitude}');

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentLocationNotifier.value = _currentLocation;
        print('LOCATION STATE: Updated current location in state');

        // Update the driver's location in Firebase when active
        if (_isDriverActive && _auth.driverId != null) {
          print('FIREBASE UPDATE: Updating driver location in Firebase');

          FirebaseDatabase.instance.ref().child('drivers/${_auth.driverId}/location').set({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
        }

        // If there's an active ride, update the polyline
        if (currentActiveRide != null) {
          print('ACTIVE RIDE: Detected active ride - updating polylines');
          print('RIDE STATUS: ${currentActiveRide!['status']}');
          _updatePolylineWithCurrentLocation();

          // Check if driver has reached pickup when ride is accepted
          // if (currentActiveRide?['status'] == 'accepted' && _pickupLocation != null) {
          //   double pickupDistance = Geolocator.distanceBetween(
          //     position.latitude, position.longitude,
          //     _pickupLocation!.latitude, _pickupLocation!.longitude,
          //   );
          //
          //   if (pickupDistance <= 30) { // Within 30 meters of pickup
          //     _startRide();
          //   }
          // }
          // Check if driver has reached destination when ride is active
          if (currentActiveRide?['status'] == 'active' && _isCloseToDestination()) {
            print('DESTINATION CHECK: Driver is close to destination - will complete ride');

            _completeRide();
          }
        }
      });
    });
  }

  void _addPickupMarker(LatLng pickup) {
    print('Adding pickup marker at: $pickup'); // Debug statement
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('pickup_marker'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup Location'),
      ));
    });
  }

  void _addDestinationMarker(LatLng destination) {
    print('Adding destination marker at: $destination'); // Debug statement
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('destination_marker'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination Location'),
      ));
    });
  }

  void _showInitialBottomSheet() {
    if (currentActiveRide != null) {
      _showRideInfoBottomSheet();
      return;
    }

    // Show first pending request if any
    List<MapEntry<String, Map<String, dynamic>>> pendingRequests =
    rideRequests.entries.where((e) => e.value['status'] == 'pending').toList();

    if (pendingRequests.isNotEmpty) {
      if (pendingRequests.length == 1) {
        _showRideRequestBottomSheet(pendingRequests.first.key, pendingRequests.first.value);
      } else {
        _showMultipleRequestsBottomSheet(pendingRequests);
      }
    }
  }

  Future<void> _fetchRideRequestData() async {
    try {
      // Fetch the ride request data
      print('Driver ID: ${_auth.driverId}'); // Debug statement
      Map<String, dynamic>? rideRequest = await _rideRequestsService.fetchDriverAcceptedOrActiveRide(_auth.driverId!);

      if (rideRequest != null) {
        print('Ride request found: $rideRequest'); // Debug statement

        // Create a directions service to convert string addresses to coordinates
        DirectionsService directionsService = DirectionsService(mapKey); // Use your API key

        setState(() {
          try {
            // Convert string addresses to coordinates
            directionsService.getCoordinates(rideRequest['pickupLocation']).then((pickupCoords) {
              _pickupLocation = pickupCoords;
              print('Pickup Location: $_pickupLocation');

              // Add pickup marker
              _markers.clear();
              _addPickupMarker(_pickupLocation!);
            });

            directionsService.getCoordinates(rideRequest['destination']).then((destCoords) {
              _destinationLocation = destCoords;
              print('Destination Location: $_destinationLocation');

              // Add destination marker
              _addDestinationMarker(_destinationLocation!);

              // Update polylines once both locations are available
              _updatePolylineWithCurrentLocation();
            });

            currentActiveRide = rideRequest;
          } catch (e) {
            print('Error processing location data: $e');
          }
        });
      } else {
        print('No ride request found for the driver.');
      }
    } catch (e) {
      print('Error fetching ride request data: $e');
    }
  }
  // Define the _isCloseToDestination method
  bool _isCloseToDestination() {
    if (_destinationLocation == null) return false;

    double distanceInMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    // Consider destination reached if within 30 meters
    return distanceInMeters <= 30;
  }

  // Define the _completeRide method
  Future<void> _completeRide() async {
    print('COMPLETE-RIDE: Method called');


    if (currentActiveRide == null) {
      print('COMPLETE-RIDE: Aborted - currentActiveRide is null');
      return;
    }
    // Store ride details before clearing state
    Map<String, dynamic> completedRideDetails = Map.from(currentActiveRide!);
    String driverId = _auth.driverId!;

    String requestId = currentActiveRide!['requestId'] ?? '';
    print("COMPLETE-RIDE: Completing ride with requestId: $requestId");

    try {
      // First, close the bottom sheet
      _isRideJustCompleted = true;

      print('COMPLETE-RIDE: Closing all bottom sheets');

      _closeAllBottomSheets();

      // Update ride status in Firebase
      print('COMPLETE-RIDE: Updating Firebase status to completed');

      await _rideRequestsService.completeRideRequest(
        driverId,
        requestId,
      );
      print('COMPLETE-RIDE: Updating local state');

      // Update local state immediately to prevent reshowing
      setState(() {
        currentActiveRide = null;
        _polylines.clear();
        _markers.removeWhere((marker) =>
        marker.markerId.value == 'pickup_marker' ||
            marker.markerId.value == 'destination_marker');
      });

      // Show success message
      print('COMPLETE-RIDE: Showing success message');


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride completed successfully!')),
      );
      String fare = 'Rs300'; // Default value
      try {
        // Fetch the latest ride data from the database
        Map<String, dynamic>? latestRideData = await _rideRequestsService.getRideRequestById(driverId,requestId);
        if (latestRideData != null && latestRideData['fare'] != null) {
          // Use the latest fare value
          fare = latestRideData['fare'].toString();
          print('COMPLETE-RIDE: Using updated fare: $fare');
        } else {
          // Fallback to the cached value if available
          fare = currentActiveRide?['fare']?.toString() ?? 'Rs300';
          print('COMPLETE-RIDE: Using cached fare: $fare');
        }
            } catch (e) {
        print('COMPLETE-RIDE: Error fetching updated fare: $e');
        // Fallback to cached value
        fare = currentActiveRide?['fare']?.toString() ?? 'Rs300';
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return RideCompletionDialog(
              fare: fare,
              driverName: _auth.currentUser?.displayName ?? 'Driver',
              isDriver: true,
              onConfirm: () {
                Navigator.pop(context);
              },
            );
          },
        );
      }
      print('COMPLETE-RIDE: Process completed successfully');
      // Reset the flag after a delay to allow Firebase to sync
      await Future.delayed(Duration(seconds: 2));
      _isRideJustCompleted = false;

    } catch (e) {
      print('Error completing ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete ride. Please try again.')),
      );
    }
  }

  // Enhanced method to update polylines based on ride status
  void _updatePolylineWithCurrentLocation() async {
    print('Updating polylines with current location: $_currentLocation');

    if (currentActiveRide == null || _currentLocation == null) {
      print('No active ride or current location is null');
      return;
    }

    try {

      print('POLYLINE CLEAR: Clearing existing polylines');

      setState(() {
        _polylines.clear(); // Clear existing polylines
      });

      if (currentActiveRide!['status'] == 'accepted' && _pickupLocation != null) {
        print('POLYLINE ROUTE: Ride accepted - fetching route to pickup location');
        print('POLYLINE PICKUP: Pickup location: $_pickupLocation');

        // Get directions to pickup location using your existing service
        print('Fetching route to pickup location');
        final directionsData = await _directionsService.getDirections(
          origin: _currentLocation!,
          destination: _pickupLocation!,
        );
        print('POLYLINE DIRECTIONS: Received directions data from API');


        // Create polyline using the points from directions API
        final routePoints = directionsData['points'] as List<LatLng>;
        print('POLYLINE POINTS: Got ${routePoints.length} points for route to pickup');
        if (routePoints.isNotEmpty) {
          print('POLYLINE DRAW: Creating polyline for pickup route');
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route_to_pickup'),
                points: routePoints,
                color: Colors.green,
                width: 5,
              ),
            );
          });
          print('Added polyline route to pickup with ${routePoints.length} points');

          // Calculate bounds to adjust camera view
          LatLngBounds bounds = _getLatLngBounds(routePoints);
          print('POLYLINE CAMERA: Adjusting camera to show route');

          mapController.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
          print('POLYLINE CAMERA: Camera adjusted');
        }
      }
      else if (currentActiveRide!['status'] == 'active' && _destinationLocation != null) {
        // Get directions to destination using your existing service
        print('Fetching route to destination');
        final directionsData = await _directionsService.getDirections(
          origin: _currentLocation!,
          destination: _destinationLocation!,
        );

        // Create polyline using the points from directions API
        final routePoints = directionsData['points'] as List<LatLng>;
        if (routePoints.isNotEmpty) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route_to_destination'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });
          print('Added polyline route to destination with ${routePoints.length} points');

          // Calculate bounds to adjust camera view
          LatLngBounds bounds = _getLatLngBounds(routePoints);
          print('POLYLINE CAMERA: Adjusting camera to show route');

          // Only adjust camera if user hasn't manually moved it
          if (!_userMovedCamera) {
            print('POLYLINE CAMERA: Adjusting camera to show route');
            LatLngBounds bounds = _getLatLngBounds(routePoints);
            mapController.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
            print('POLYLINE CAMERA: Camera adjusted');
          } else {
            print('POLYLINE CAMERA: Skipping camera adjustment - user moved camera');
          }
          print('POLYLINE CAMERA: Camera adjusted');
        }
      }
    } catch (e) {
      print('Error updating polylines: $e');
    }
  }


  void _closeAllBottomSheets() {
    try {
      // Close ride request sheet if open
      if (_rideRequestSheetController != null) {
        // Don't try to check mounted state on the controller
        try {
          _rideRequestSheetController?.close();
        } catch (e) {
          print('Error closing ride request sheet: $e');
        }
        _rideRequestSheetController = null;
      }

      // Close ride info sheet if open
      if (_rideInfoSheetController != null) {
        try {
          _rideInfoSheetController?.close();
        } catch (e) {
          print('Error closing ride info sheet: $e');
        }
        _rideInfoSheetController = null;
      }

      if (mounted) {
        setState(() {
          _showRideRequestSheet = false;
          _showRideInfoSheet = false;
        });
      }
    } catch (e) {
      print('Error closing bottom sheets: $e');
    }
  }
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    print('Map created'); // Debug statement

  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool permissionGranted = await _permissionHandler.handleLocationPermission(context);

      if (!permissionGranted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position? position = await _geolocationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
          _currentLocationNotifier.value =
              LatLng(position.latitude, position.longitude);
        });

        mapController.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to retrieve your current location. Using default location.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

// Add this helper method to calculate bounds for the map camera
  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) southWestLat = point.latitude;
      if (point.longitude < southWestLng) southWestLng = point.longitude;
      if (point.latitude > northEastLat) northEastLat = point.latitude;
      if (point.longitude > northEastLng) northEastLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }


  void _toggleDriverActiveStatus() async {
    if (_isDriverActive) {
      // Deactivate the driver
      String? driverid;
      driverid = _auth.driverId;
      if(driverid!=null) {
        Geofire.removeLocation(driverid); // Replace with the driver's unique ID
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now offline.')),
      );
    } else {
      // Activate the driver
      Position? position = await _geolocationService.getCurrentLocation();
      String? driverID;
      driverID = _auth.driverId;
      print("before position");
      if (position != null) {
        if (driverID != null) {
          print("true position");
          // Initialize GeoFire
          Geofire.setLocation(
            driverID, // Safe because we checked for null
            position.latitude,
            position.longitude,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are now online.')),
          );
        } else {
          // Handle the null driverId case
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Driver ID is null.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to activate. Unable to get location.')),
        );
      }
    }

    setState(() {
      _isDriverActive = !_isDriverActive;
    });
  }

  void _listenForRideRequests() {
    print('INIT: Setting up ride requests listener');
    // Check if driverId is null
    String? driverId = _auth.driverId;

    DatabaseReference rideRequestsRef = _rideRequestsService.getRideRequestsRef(driverId!);

    // Listen for all ride requests
    rideRequestsRef.onValue.listen((event) {
      print('LISTENER: Ride requests data changed');

      // Skip updates if we're in the middle of completing a ride
      if (_isRideJustCompleted) {
        print('LISTENER: Ignoring update because ride was just completed');
        return;
      }

      if (event.snapshot.exists) {
        print('LISTENER: Snapshot exists with data');

        // Clear existing requests to handle removals
        setState(() {
          rideRequests = {};
        });

        Map<dynamic, dynamic> values = event.snapshot.value as Map<dynamic, dynamic>;
        bool needToFetchRideData = false;
        print('PROCESSING: Found ${values.length} ride requests in database');

        // Filter and process requests for this driver
        values.forEach((key, value) {
          Map<String, dynamic> request = Map<String, dynamic>.from(value);

          // Only add requests assigned to this driver
          if (request['driverId'] == _auth.driverId) {
            print('RIDE-${key}: Status=${request['status']}, Assigned to this driver');

            // Check if status CHANGED to active (not just is active)
            bool wasActiveStatusJustChanged = false;
            if (request['status'] == 'active' &&
                currentActiveRide != null &&
                currentActiveRide!['status'] != 'active') {
              wasActiveStatusJustChanged = true;
              print('STATUS-CHANGE: Ride ${key} changed to ACTIVE');

            }
            setState(() {
              rideRequests[key] = request;
              rideRequests[key]!['requestId'] = key;
              // Check if ride status changed to completed
              if (request['status'] == 'completed' && currentActiveRide != null &&
                  currentActiveRide!['requestId'] == key) {
                // Handle completed ride
                print('STATUS-CHANGE: Ride ${key} changed to COMPLETED - calling _completeRide()');

                _completeRide();
              }
              // If we have an accepted or active ride, set it as current
              else if (request['status'] == 'accepted' || request['status'] == 'active') {
                print('CURRENT-RIDE: Setting current active ride to ${key} with status ${request['status']}');

                currentActiveRide = request;
                needToFetchRideData = true; // Set flag to fetch ride data
                currentActiveRide!['requestId'] = key;

              }
            });

            // Handle newly activated ride
            if (wasActiveStatusJustChanged) {
              print('HANDLING: Processing newly activated ride');
              _handleNewlyActivatedRide();
            }

          }
        });

        // Handle UI updates based on requests
        _handleRideRequestsUI();
        // If we found an accepted or active ride, fetch its data to update map
        if (needToFetchRideData) {
          print('FETCH: Need to fetch ride data for map updates');

          _fetchRideRequestData();
        }
      } else {
        print('LISTENER: No ride requests found in database');
        setState(() {
          rideRequests = {};
          currentActiveRide = null;
        });
        _closeAllBottomSheets();
      }
    });
  }

  Future<void> _handleNewlyActivatedRide() async {
    // Play sound for Muslim drivers
    print('RIDE: Handling newly activated ride');

    final userDetails = await _fetchDriverDetails(_auth.currentUser!.uid);
    if (userDetails != null && userDetails['religion'] == 'Muslim') {
      print('AUDIO: Playing Safar ki Dua for Muslim driver');
      _audioService.playAudio(_safarKiDuaPath);

      // Show audio controls
      setState(() {
        _showAudioControls = true;
      });
    }

    // Refresh the bottom sheet with new status
    _showRideInfoBottomSheet();
  }

  // handles audio playback toggle
  void _togglePlayPause() {
    if (_audioService.isPlaying) {
      // If playing, pause it
      _audioService.pauseAudio().then((_) {
        _updateAudioControlState();
      });
    } else {
      // If not playing, either resume or restart
      if (_audioService.currentAudio == _safarKiDuaPath && !_audioService.hasCompleted) {
        // Resume if paused and not completed
        _audioService.resumeAudio().then((_) {
          _updateAudioControlState();
        });
      } else {
        // Start from beginning if completed or different audio
        _audioService.playAudio(_safarKiDuaPath).then((_) {
          _updateAudioControlState();
        });
      }
    }
  }

  void _updateAudioControlState() {
    if (mounted) {
      setState(() {
        // This ensures the UI reflects the actual state of the audio player
      });
    }
  }

  // Add this method to handle UI updates based on requests
  void _handleRideRequestsUI() {
    // If we have an active ride that is not completed, show its info sheet
    if (currentActiveRide != null && currentActiveRide!['status'] != 'completed') {
      _showRideInfoBottomSheet();
      return;
    }

    // If we have pending requests, show the requests sheet
    List<MapEntry<String, Map<String, dynamic>>> pendingRequests =
    rideRequests.entries.where((e) => e.value['status'] == 'pending').toList();

    if (pendingRequests.isNotEmpty) {
      // Show UI for pending requests (either first one or multiple)
      if (pendingRequests.length == 1) {
        // Show single request sheet for the first pending request
        _showRideRequestBottomSheet(pendingRequests.first.key, pendingRequests.first.value);
      } else {
        // Show multiple requests list
        _showMultipleRequestsBottomSheet(pendingRequests);
      }
    } else {
      _closeAllBottomSheets();
    }
  }

  // Update to handle specific request
  void _showRideRequestBottomSheet(String requestId, Map<String, dynamic> request) {
    _closeAllBottomSheets();

    setState(() {
      _showRideRequestSheet = true;
    });

    _rideRequestSheetController = showBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => SingleRideRequestBottomSheet(
        request: request,
        requestId: requestId,
        onAccept: _acceptRideRequest,
        onReject: _rejectRideRequest,
      ),
    );
  }
  // Add new method for multiple requests
  void _showMultipleRequestsBottomSheet(List<MapEntry<String, Map<String, dynamic>>> requests) {
    _closeAllBottomSheets();

    setState(() {
      _showRideRequestSheet = true;
    });

    _rideRequestSheetController = showBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => MultipleRideRequestsBottomSheet(
        requests: requests,
        onAccept: _acceptRideRequest,
        onReject: _rejectRideRequest,
      ),
    );
  }
  // Update ride info sheet to use currentActiveRide
  void
  _showRideInfoBottomSheet() {
    if (_isRideJustCompleted) {
      print('BOTTOM-SHEET: Not showing because ride was just completed');
      return;
    }

    // Don't show for null or completed rides
    if (currentActiveRide == null || currentActiveRide?['status'] == 'completed') {
      print('BOTTOM-SHEET: Not showing for null/completed ride');
      return;
    }

    // If already showing, don't recreate it
    if (_showRideInfoSheet && _rideInfoSheetController != null) {
      print('BOTTOM-SHEET: Already showing - not recreating');
      return;
    }

    _closeAllBottomSheets();
    print('ShowingBottomSheet');

    if(mounted) {
      setState(() {
        _showRideInfoSheet = true;
      });
    }

    _rideInfoSheetController = showBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext builderContext, StateSetter sheetSetState) => RepaintBoundary(
          child: RiderInfoBottomSheet(
            key: ObjectKey(currentActiveRide!['requestId']), // More stable than ValueKey
            onCancel: () {
              _closeAllBottomSheets();
            },
            rideDetails: currentActiveRide ?? {},
            activeOrAccepted: currentActiveRide?['status'] ?? 'accepted',
          ),
        ),
      ),
    );
    // Add listener to detect when bottom sheet is closed by sliding
    _rideInfoSheetController?.closed.then((_) {
      if (mounted) {
        setState(() {
          _showRideInfoSheet = false;
        });
      }
    });
  }

  Future<Map<String, dynamic>?> _fetchDriverDetails(String userId) async {
    try {
      // Fetch user details
      print('Fetching details for path: users/$userId');
      final userSnapshot = await FirebaseDatabase.instance.ref().child('users/$userId').get();
      if (userSnapshot.exists && userSnapshot.value is Map) {
        return Map<String, dynamic>.from(userSnapshot.value as Map);
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map (keep as is)
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 12.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: _markers, // Add this line
            onCameraMove: (_) {
              _userMovedCamera = true;
            },
            onCameraIdle: () {
              // Optional: reset after some time to allow automatic updates again
              // Future.delayed(Duration(seconds: 30), () {
              //   _userMovedCamera = false;
              // });
            },
          ),

          // Add audio controls overlay
          if (_showAudioControls)
            Positioned(
              top: 90 + MediaQuery.of(context).padding.top,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _audioService.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return IconButton(
                          icon: Icon(
                            _audioService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: AppColors.secondary.value,
                            size: 36,
                          ),
                          onPressed: _togglePlayPause,
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        'Safar ki Dua',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: _toggleAudioControlsVisibility,
                    ),
                  ],
                ),
              ),
            ),

          // Online/Offline button (keep as is)
          Positioned(
            top: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _toggleDriverActiveStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDriverActive ? Colors.green : Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isDriverActive ? 'Go Offline' : 'Go Online',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          // Loading indicator (keep as is)
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),

          // Add a music button to show/hide audio controls
          if (currentActiveRide != null && currentActiveRide?['status'] == 'active')
            Positioned(
              top: 90 + MediaQuery.of(context).padding.top,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.music_note),
                  color: _showAudioControls ? AppColors.secondary.value : Colors.grey,
                  onPressed: _toggleAudioControlsVisibility,
                ),
              ),
            ),
          Positioned(
            top: 150 + MediaQuery.of(context).padding.top,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.timer, color: Colors.orange),
                onPressed: () => _showWaitingTimeDialog(),
                tooltip: 'Waiting Time',
              ),
            ),
          ),
          if(currentActiveRide?['ride_type'] == 'ride_ac')
          Positioned(
            top: 210 + MediaQuery.of(context).padding.top,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.ac_unit),
                color: AppColors.secondary.value,
                onPressed: _showACControlDialog,
                tooltip: 'AC Control',
              ),
            ),
          ),

        ],
      ),
      floatingActionButton: currentActiveRide != null || rideRequests.entries
          .where((e) => e.value['status'] == 'pending')
          .isNotEmpty ? FloatingActionButton(
        onPressed: () {
          if (currentActiveRide != null && !_showRideInfoSheet) {
            _showRideInfoBottomSheet();
          } else if (!_showRideRequestSheet) {
            // Show the appropriate bottom sheet based on number of requests
            List<MapEntry<String, Map<String, dynamic>>> pendingRequests =
            rideRequests.entries.where((e) => e.value['status'] == 'pending').toList();

            if (pendingRequests.length == 1) {
              _showRideRequestBottomSheet(pendingRequests.first.key, pendingRequests.first.value);
            } else if (pendingRequests.length > 1) {
              _showMultipleRequestsBottomSheet(pendingRequests);
            }
          }
        },
        child: Icon(Icons.keyboard_arrow_up),
        backgroundColor: AppColors.secondary.value,
        foregroundColor: Colors.white,
      ) : null,
    );
  }


  void _acceptRideRequest(String requestId) async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/ride_request.mp3'));

    // Get the driver ID
    String driverId = _auth.driverId!;

    // Use the service method instead of direct Firebase access
    bool success = await _rideRequestsService.acceptRideRequest(driverId, requestId);

    if (!success) {
      print("Failed to accept ride request $requestId.");
      return;
    }

    // First get the ride request details to extract userId
    Map<String, dynamic>? requestData = await _rideRequestsService.getRideRequestById(driverId, requestId);

    if (requestData == null) {
      print("Ride request $requestId does not exist.");
      return;
    }

    String riderId = requestData['userId'] as String;

    // Get rider's FCM token from users database
    DataSnapshot riderSnapshot = await FirebaseDatabase.instance.ref().child('users/$riderId').get();
    if (riderSnapshot.exists) {
      Map<String, dynamic> riderData = Map<String, dynamic>.from(riderSnapshot.value as Map);
      String? riderToken = riderData['fcmToken'] as String?;
      String driverName = _auth.currentUser?.displayName ?? 'Your driver';

      // Send notification to rider if token exists
      if (riderToken != null) {
        await notificationService.sendNotification(
          riderToken,
          "Ride Accepted",
          "Your ride has been accepted by $driverName!",
          notificationType: "ride_accepted",
        );
        print("Notification sent to rider with token: $riderToken");
      } else {
        print("Rider FCM token not found");
      }
    }

    // Store the accepted ride request ID
    setState(() {
      _acceptedRideRequestId = requestId;
    });

    // Reject all other pending requests
    rideRequests.forEach((id, request) {
      if (id != requestId && request['status'] == 'pending') {
        _rideRequestsService.rejectRideRequest(driverId, id);
      }
    });

    print("Ride request $requestId accepted.");
  }

  void _rejectRideRequest(String requestId) async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/ride_request_rejected.mp3'));

    // Get the driver ID
    String driverId = _auth.driverId!;

    // Use the service method instead of direct Firebase access
    bool success = await _rideRequestsService.rejectRideRequest(driverId, requestId);

    if (!success) {
      print("Failed to reject ride request $requestId.");
      return;
    }

    print("Ride request $requestId rejected.");
  }

  void _showWaitingTimeDialog() {
    if (currentActiveRide == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CompletelyIsolatedWaitingTimeWidget(
          key: ValueKey('waiting_time_${currentActiveRide!['requestId']}'),
          requestId: currentActiveRide!['requestId'],
          baseFare: double.parse(currentActiveRide!['fare'].toString()),
        ),
      ),
    );
  }

  void _showACControlDialog() {
    if (currentActiveRide == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: ACControlWidget(
          requestId: currentActiveRide!['requestId'],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _closeAllBottomSheets();
    _locationSubscription?.cancel(); // Cancel the subscription to prevent leaks
    super.dispose();
  }
}
