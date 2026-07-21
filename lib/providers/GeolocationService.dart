import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeolocationService {
  // Determine the current location with enhanced error handling
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      // If permissions are denied, attempt to request
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        // Double-check after requesting
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied by user.');
          return null;
        }
      }

      // Check for permanent denial
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied. Cannot request.');
        return null;
      }

      // If we've reached this point, permissions are granted
      // Attempt to get the current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),

      );

      // Print latitude and longitude
      debugPrint('Geo Location Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      return position;

    } catch (e) {
      // Catch and log any unexpected errors
      debugPrint('Unexpected error in getCurrentLocation: $e');
      return null;
    }
  }

  // Enhanced stream for continuous location updates
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Minimum distance (in meters) to trigger update

      ),
    );
  }

  // Convert address to LatLng coordinates
  Future<LatLng> getCoordinates(String address) async {
    try {
      // Convert address to a list of Location objects
      List<Location> locations = await locationFromAddress(address);

      // Check if locations were found
      if (locations.isEmpty) {
        throw Exception('No locations found for the address: $address');
      }

      // Return the first location as LatLng
      return LatLng(locations.first.latitude, locations.first.longitude); // Use positional parameters
    } catch (e) {
      debugPrint('Error in getCoordinates: $e');
      throw Exception('Failed to get coordinates for address: $address');
    }
  }
}
