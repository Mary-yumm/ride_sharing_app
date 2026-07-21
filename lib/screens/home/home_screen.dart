import 'dart:async';
import 'dart:ui';
import 'dart:typed_data'; // Add this import

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_sharing_app/configMaps.dart';
import 'package:ride_sharing_app/screens/home/active_nearby_available_drivers.dart';
import 'package:ride_sharing_app/providers/geofire_assistant.dart';
import 'package:ride_sharing_app/providers/directions_service.dart';
import 'package:ride_sharing_app/screens/home/ride_completion_dialog.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth.dart';
import 'RideInfoBottomSheet.dart';
import 'bottom_sheet.dart';
import 'package:ride_sharing_app/providers/GeolocationService.dart';
import 'package:ride_sharing_app/providers/LocationPermissionHandler.dart'; // Add this import
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:ride_sharing_app/providers/ride_requests_service.dart';
import 'package:ride_sharing_app/providers/directions_service.dart';
import '../../providers/driver_service.dart';

class RideState {
  String? requestId;
  String status = ''; // 'accepted', 'active', 'completed'
  Map<String, dynamic>? rideData;
  String? driverId;
  late LatLng pickupLocation;
  late LatLng destinationLocation;

  bool get isActive => requestId != null &&
      (status == 'accepted' || status == 'active');

  void reset() {
    requestId = null;
    status = '';
    rideData = null;
    driverId = null;
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //String activeOrAccepted = " ";
  final DriverService _driverService = DriverService(); // Create an instance of DriverService
  final ValueNotifier<LatLng> _currentLocationNotifier =
  ValueNotifier(const LatLng(33.6844, 73.0479)); // Default location: Islamabad

  late GoogleMapController mapController;
  LatLng _currentLocation = const LatLng(33.6844, 73.0479); // Initialize with default
  bool _isLoading = true; // Add a loading state
  PersistentBottomSheetController? _bottomSheetController; // Add this line


  // Create instances of services
  final GeolocationService _geolocationService = GeolocationService();
  final LocationPermissionHandler _permissionHandler = LocationPermissionHandler();

  // Polylines
  Set<Polyline> _polylines = {};
  bool activeNearByDriverKeysLoaded = false; // Initialize

  Set<Marker> _driverMarkers = {}; // Define this at the top of the class
  BitmapDescriptor? activeNearbyIcon; // Define activeNearbyIcon
  Set<Marker> markersSet = {}; // Define markersSet

  final DirectionsService _directionsService = DirectionsService(mapKey); // Replace with your API key

  Timer? _driverLocationTimer;
  //String? _selectedDriverId;
  final RideRequestsService _rideRequestsService = RideRequestsService(); // Create an instance of RideRequestsService
  bool hasActiveRide = false;
  bool _showRideInfoSheet = false;
  Marker? _destinationMarker;
  Marker? _pickupMarker;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DatabaseEvent>? _rideStatusSubscription;
  //String? _requestId; // Add this field to store the request ID
  bool _isRideJustCompleted = false;
  Map<String, dynamic>? currentActiveRide;
  final RideState _rideState = RideState();
  bool _isCompletionDialogShown = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    createActiveNearByDriverIconMarker(); // Initialize the driver icon marker
    displayActiveDriversOnUserMap();
    // First check for an active ride, then setup location tracking
    _checkForActiveRide().then((_) {
      if (hasActiveRide) {
        _setupLocationTracking();
        _startDriverLocationUpdates();
      } else {
        _setupLocationTracking();
      }
    });
  }

  void _setupLocationTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 4, // Update every 4 meters
      ),
    ).listen((Position position) {
      // Update location state synchronously
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentLocationNotifier.value = _currentLocation;
      });

      // Handle async operations outside of setState
      if (hasActiveRide) {
        _updatePolylineWithCurrentLocation();
        _checkDestinationProximity();
      }
    });
  }

// Move the async destination check to a separate method
  void _checkDestinationProximity() async {
    // Guard against null requestId
    if (_rideState.requestId == null) {
      print("Cannot check proximity: requestId is null");
      return;
    }

    // First check if the ride is already completed in database
    try {
      Map<String, dynamic>? latestRideData =
      await _rideRequestsService.getRideRequestById(_rideState.requestId!,_rideState.driverId!);

      if (latestRideData != null && latestRideData['status'] == 'completed') {
        print('Ride already marked as completed in database');
        _completeRide();
        return;
      }
    } catch (e) {
      print('Error checking database for completion: $e');
    }

  }

  void _completeRide() async {
    print('COMPLETE-RIDE: Method called');

    // Guard against duplicate calls
    if (_isCompletionDialogShown) {
      print('COMPLETE-RIDE: Aborted - completion dialog already shown');
      return;
    }

    // Mark as handling completion immediately
    _isCompletionDialogShown = true;

    try {
      // 1. Cancel all listeners and timers first
      _locationSubscription?.cancel();
      _driverLocationTimer?.cancel();
      _rideStatusSubscription?.cancel();

      // 2. Close bottom sheets
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 3. Fetch final ride data
      Map<String, dynamic>? finalRideData;
      if (_rideState.requestId != null) {
        finalRideData = await _rideRequestsService.getRideRequestById(_rideState.requestId!,_rideState.driverId!);
      }

      // 4. Extract necessary information
      String fare = finalRideData?['fare']?.toString() ?? _rideState.rideData?['fare']?.toString() ?? 'N/A';
      String driverName = 'Driver';

      // 5. Fetch driver details
      if (_rideState.driverId != null) {
        var driverDetails = await _driverService.fetchDriverDetails(_rideState.driverId!);
        if (driverDetails != null) {
          driverName = driverDetails['name'] ?? 'Driver';
        }
      }

      // 6. Reset UI state
      setState(() {
        hasActiveRide = false;
        _showRideInfoSheet = false;
        _polylines.clear();
        markersSet.removeWhere((marker) => marker.markerId.value != 'my_location_marker');
      });

      // 7. Show completion dialog after a small delay
      if (mounted) {
        Future.delayed(Duration(milliseconds: 300), () {
          showDialog(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder: (BuildContext dialogContext) {
              return RideCompletionDialog(
                fare: fare,
                driverName: driverName,
                isDriver: false,
                onConfirm: () {
                  Navigator.of(dialogContext).pop();

                  // Reset ride state completely
                  setState(() {
                    _rideState.reset();
                    currentActiveRide = null;
                    _isCompletionDialogShown = false;
                  });
                },
              );
            },
          );
        });
      }
    } catch (e) {
      print('COMPLETE-RIDE: Error completing ride: $e');
      _isCompletionDialogShown = false;
    }
  }


  Future<void> _updatePolylineWithCurrentLocation() async {
    // Only update polyline to destination if ride is "active"
    if (_rideState.status == "active" && _rideState.driverId != null) {
      try {
        // Fetch driver's current location instead of using user's location
        LatLng? driverLocation = await _driverService.fetchDriverLocation(_rideState.driverId!);

        if (driverLocation != null) {
          setState(() {
            _polylines.removeWhere((polyline) => polyline.polylineId.value == 'route_polyline');
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route_polyline'),
                points: [
                  driverLocation, // Driver's current location
                  _rideState.destinationLocation, // Destination location
                ],
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          // Log for debugging
          print('Updated polyline from driver (${driverLocation.latitude}, ${driverLocation.longitude}) to destination');
        } else {
          print('Could not fetch driver location');
        }
      } catch (e) {
        print('Error updating polyline with driver location: $e');
      }
    }
  }

  Future<void> _checkForActiveRide() async {
    User? user = Auth.instance.currentUser;
    if (user != null) {
      String userId = user.uid;
      print("Checking for active ride for user: $userId");
      Map<String, dynamic>? acceptedRide = await _rideRequestsService
          .getAcceptedRideRequest(userId);

      Map<String, dynamic>? activeRide = await _rideRequestsService
          .getStartedRideRequest(userId);

      // declare a bool to pass to know if the ride is accepted or active
      if(activeRide != null){
        print("Active ride found");
        //activeOrAccepted="active";
        currentActiveRide = activeRide;
        _updateRideState(activeRide, "active");
        print("Successfully processed active ride data");

      }
      if(acceptedRide != null){
        print("Accepted ride found");
        //activeOrAccepted="accepted";
        currentActiveRide = acceptedRide;
        _updateRideState(acceptedRide, "accepted");
        print("Successfully processed accepted ride data");

      }
      print("Before final condition: activeRide=${activeRide != null}, acceptedRide=${acceptedRide != null}");
      if (_rideState.isActive) {
        hasActiveRide = true;
        _setupRideStatusListener();
        _setupRideUI();
      }

    }
    else{
      print("User is not logged in");
    }
  }

  void _setupRideUI() {
    if (_rideState.pickupLocation != null && _rideState.destinationLocation != null) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_polyline'),
            points: [
              _rideState.pickupLocation!,
              _rideState.destinationLocation!,
            ],
            color: Colors.blue,
            width: 5,
          ),
        );

        // Add markers
        _addPickupMarker(_rideState.pickupLocation!);
        _addDestinationMarker(_rideState.destinationLocation!);
      });

      // Show ride info bottom sheet
      _showRideInfoBottomSheet(_rideState.driverId!, _rideState.status);
    }
  }

  void _setupRideStatusListener() {
    // Cancel any existing subscription first
    _rideStatusSubscription?.cancel();

    if (_rideState.requestId == null || _rideState.driverId == null) {
      print("Cannot setup listener: requestId or driverId is null");
      return;
    }

    print("RIDE-STATUS: Setting up listener for ride ID: ${_rideState.requestId}");

    // Use the ride requests service to get a reference to the ride request
    DatabaseReference rideRef = _rideRequestsService.getRideRequestRefRider(_rideState.requestId!, _rideState.driverId!);

    _rideStatusSubscription = rideRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> rideData = event.snapshot.value as Map<dynamic, dynamic>;
        String newStatus = rideData['status'] ?? '';

        print('RIDE-STATUS: Firebase status change detected: $newStatus');

        // Update the cached data regardless of status change
        setState(() {
          currentActiveRide = Map<String, dynamic>.from(rideData);
          _rideState.status = newStatus;
          _rideState.rideData = Map<String, dynamic>.from(rideData);
        });

        // Handle status transitions
        if (newStatus == 'completed' && !_isCompletionDialogShown) {
          print('RIDE-STATUS: Ride completed, showing dialog');
          _completeRide();
        }
      }
    }, onError: (error) {
      print("Error in ride status listener: $error");
    });
  }

  void _updateRideState(Map<String, dynamic> rideData, String status) {
    setState(() {
      // Update the RideState
      _rideState.rideData = Map<String, dynamic>.from(rideData);
      _rideState.requestId = rideData['requestId'];
      _rideState.status = status;
      _rideState.driverId = rideData['driverId'];
      //activeOrAccepted = status; // Keep for backward compatibility
      _rideState.driverId = rideData['driverId'];
      //_requestId = rideData['requestId']; // Keep for backward compatibility

      // Process locations
      _directionsService.getCoordinates(rideData['destination']).then((destLocation) {
        _rideState.destinationLocation = destLocation;
      });

      _directionsService.getCoordinates(rideData['pickupLocation']).then((pickupLocation) {
        _rideState.pickupLocation = pickupLocation;
      });
    });

    print("Updated ride state: status=${_rideState.status}, requestId=${_rideState.requestId}");
  }

  // Add this method to start the timer
  void _startDriverLocationUpdates() {
    _driverLocationTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      await _updateDriverLocation();
    });
  }

  // Add this method to fetch and update the driver's location
  Future<void> _updateDriverLocation() async {
    if(_rideState.driverId != null) {
      LatLng? driverLocation;
      driverLocation =
      (await _driverService.fetchDriverLocation(_rideState.driverId!));

      if (driverLocation != null) {
        setState(() {
          Marker updatedMarker = Marker(
            markerId: MarkerId(_rideState.driverId!),
            position: driverLocation!,
            icon: activeNearbyIcon ?? BitmapDescriptor.defaultMarker,
            rotation: 360,
          );
          _driverMarkers.removeWhere((marker) =>
          marker.markerId.value == _rideState.driverId);
          _driverMarkers.add(updatedMarker);
          markersSet.addAll(_driverMarkers);

          // Update the polyline's start point to the user's current location
          _polylines.removeWhere((polyline) => polyline.polylineId.value == 'route_polyline');
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_polyline'),
              points: [
                _rideState.pickupLocation, // User's current location
                driverLocation, // Driver's current location
              ],
              color: Colors.blue,
              width: 5,
            ),
          );
        });
      }
    }
    else{
      print("Driver ID is null");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Add the initial polyline
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_polyline'),
          points: [
            _rideState.pickupLocation, // User's current location
            _rideState.destinationLocation, // Destination location
          ],
          color: Colors.blue,
          width: 5,
        ),
      );
      _addDestinationMarker(_rideState.destinationLocation);

    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      // First, handle permissions
      bool permissionGranted = await _permissionHandler.handleLocationPermission(context);

      if (!permissionGranted) {
        // If permissions are not granted, stop loading and use default location
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Attempt to get current location
      Position? position = await _geolocationService.getCurrentLocation();

      if (position != null) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _currentLocationNotifier.value = LatLng(position.latitude, position.longitude);
          });
        }

        // Move the map to the current location
        mapController.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );

        initializeGeoFireListener();
      } else {


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to retrieve your current location. Using default location.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Handle any unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      // Ensure loading stops regardless of success or failure
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _addPickupMarker(LatLng pickup) {
    setState(() {
      Marker pickupMarker = Marker(
        markerId: MarkerId('pickup_marker'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
      markersSet.add(pickupMarker);
    });
  }
  void _addDestinationMarker(LatLng destination) {
    setState(() {
      _destinationMarker = Marker(
        markerId: MarkerId('destination_marker'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
      markersSet.add(_destinationMarker!);
    });
  }

  void initializeGeoFireListener() {
    print("Initializing GeoFire listener");
    Geofire.initialize("activeDrivers");
    Geofire.queryAtLocation(_currentLocation.latitude, _currentLocation.longitude, 50)?.listen((map) {
      if (map != null) {
        print("GeoFire query result: $map");
        var callBack = map["callBack"];
        switch (callBack) {
          case Geofire.onKeyEntered:
            print("Driver entered: ${map["key"]}");
            ActiveNearByAvailableDrivers activeDriver = ActiveNearByAvailableDrivers(
              driverId: map["key"],
              locationLatitude: map["latitude"],
              locationLongitude: map["longitude"],

            );
            GeoFireAssistant.activeNearByAvailableDriversList.add(activeDriver);
            if (activeNearByDriverKeysLoaded) {
              displayActiveDriversOnUserMap();
            }
            break;

          case Geofire.onKeyExited:
            print("Driver exited: ${map["key"]}");
            GeoFireAssistant.deleteOfflineDriverFromList(map["key"]);
            displayActiveDriversOnUserMap();
            break;


          case Geofire.onKeyMoved:
            print("Driver moved: ${map["key"]}");
            ActiveNearByAvailableDrivers movedDriver = ActiveNearByAvailableDrivers(
              driverId: map["key"],
              locationLatitude: map["latitude"],
              locationLongitude: map["longitude"],
            );
            GeoFireAssistant.updateActiveNearByAvailableDriverLocation(movedDriver);
            displayActiveDriversOnUserMap();
            break;

          case Geofire.onGeoQueryReady:
            print("GeoFire query ready");
            activeNearByDriverKeysLoaded = true;
            displayActiveDriversOnUserMap();
            break;
        }
      }
    });
  }

  void displayActiveDriversOnUserMap() {
    if (mounted) {
      setState(() {
        _driverMarkers.clear();
        for (ActiveNearByAvailableDrivers eachDriver in GeoFireAssistant.activeNearByAvailableDriversList) {
          LatLng eachDriverActivePosition = LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);
          Marker marker = Marker(
            markerId: MarkerId(eachDriver.driverId!),
            position: eachDriverActivePosition,
            icon: activeNearbyIcon ?? BitmapDescriptor.defaultMarker,
            rotation: 360,
          );
          _driverMarkers.add(marker);
        }
        markersSet.addAll(_driverMarkers);
        print("Markers updated: ${_driverMarkers.length} markers added");
      });
    }
  }


  void createActiveNearByDriverIconMarker() async {
    activeNearbyIcon = await createCustomMarkerIcon(Colors.red); // Set the icon color to red
    setState(() {});
  }


  Future<BitmapDescriptor> createCustomMarkerIcon(Color color) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0; // Marker size

    // Draw a circle or any custom background for the marker
    final Paint paint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    // Draw the red car icon
    final Icon icon = Icon(
      Icons.directions_car,
      color: color,
      size: 64.0, // Icon size
    );

    // Create a TextPainter to render the icon
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.icon!.codePoint),
      style: TextStyle(
        fontSize: icon.size,
        fontFamily: icon.icon!.fontFamily,
        color: icon.color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    // Convert to an image
    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? data = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GestureDetector(
            onTap: () {
              if (_bottomSheetController != null) {
                _bottomSheetController!.close(); // Close the BottomSheet
              }
            },
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation, // Use current location
                zoom: 12.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              polylines: _polylines, // Add this line to display polylines
              markers: markersSet, // Add this line to display markers
            ),
          ),

          // Loading Indicator (if needed)
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_showRideInfoSheet) {
            _showRideInfoBottomSheet(_rideState.driverId!,_rideState.status);
          } else {
            _showPreviousBottomSheet();
          }
        },        child: Icon(Icons.keyboard_arrow_up),
      ),

    );
  }


  Future<void> _showRideInfoBottomSheet(String driverId,String activeOrAccepted) async {
    //debug print
    print("Driver selected: $driverId");
    //_selectedDriverId = driverId;
    // Fetch driver details using the driverId
    var driverDetails = await _driverService.fetchDriverDetails(driverId);

    if (driverDetails != null) {
      driverDetails['driverId'] = driverId; // Add the driverId to the details
      setState(() {
        _showRideInfoSheet = true; // Set the flag to true
      });
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: true,
        builder: (context) => RideInfoBottomSheet(
          onCancel: () {
            // Handle ride cancellation
            Navigator.pop(context); // Close the ride info bottom sheet
            _showPreviousBottomSheet(); // Show the previous bottom sheet
          },
          driverDetails: driverDetails,
          activeOrAccepted: _rideState.status,
          onRideComplete: _completeRide, // Add this callback
        ),
      );
    } else {
      // Handle the case where driver details are not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch driver details.')),
      );
    }
  }

  void _showRideInfoBottomSheetWrapper(String driverId) {
    _showRideInfoBottomSheet(driverId, _rideState.status);
  }
  void _showPreviousBottomSheet() {
    setState(() {
      _showRideInfoSheet = false; // Set the flag to false
    });
    _bottomSheetController = showBottomSheet(
      context: context,
      builder: (context) => BottomSheetContent(
        locationNotifier: _currentLocationNotifier,
        onFindDriver: _handleFindDriver,
        nearbyDrivers: GeoFireAssistant.activeNearByAvailableDriversList,
        onShowPreviousBottomSheet: _showPreviousBottomSheet,
        onDriverSelected: _showRideInfoBottomSheetWrapper, // Pass the callback
      ),
    );
  }
  Future<void> _handleFindDriver(String pickup, String destination) async {
    print("Pickup: $pickup, Destinationn: $destination");

    // Polylines
    try {
      // Convert addresses to LatLng
      final pickupLocation = await _geolocationService.getCoordinates(pickup);
      final destinationLocation = await _geolocationService.getCoordinates(destination);

      // Fetch polyline points
      final directions = await _directionsService.getDirections(
        origin: pickupLocation,
        destination: destinationLocation,
        mode:'driving',
      );
      final polylinePoints = directions['points'] as List<LatLng>;
      // Extract duration text and value
      final durationText = directions['durationText'] as String;
      final durationValue = directions['durationValue'] as int;

      // Draw the polyline on the map
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_polyline'),
            points: polylinePoints,
            color: Colors.blue,
            width: 5,
          ),
        );
        _addPickupMarker(pickupLocation);
        _addDestinationMarker(destinationLocation);
      });

      // Move the camera to show the entire route
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getLatLngBounds(polylinePoints),
          50, // Padding around the route
        ),
      );

      // Display the duration to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimated trip duration: $durationText'),
          duration: Duration(seconds: 5),
        ),
      );

      // You can also use the durationValue (in seconds) for further calculations
      print('Duration in seconds: $durationValue');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching route: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    //Call the GeoFire listener and update the map finding the nearby drivers
    print("Find Driver button callback triggered in HomeScreen");
    if (GeoFireAssistant.activeNearByAvailableDriversList.isNotEmpty) {
      print("Nearby drivers found: ${GeoFireAssistant.activeNearByAvailableDriversList.length}");
      displayActiveDriversOnUserMap();
    } else {
      print("No nearby drivers found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No nearby drivers available."),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

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

  @override
  void dispose() {
    _rideStatusSubscription?.cancel();
    _locationSubscription?.cancel();
    _driverLocationTimer?.cancel();
    _currentLocationNotifier.dispose(); // Clean up notifier
    Geofire.stopListener();
    super.dispose();
  }
}



