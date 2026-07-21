import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

class LocationPermissionHandler {
  /// Comprehensive method to handle location permissions
  Future<bool> handleLocationPermission(BuildContext context) async {
    // Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If location services are off, show a user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please enable them in device settings.')),
      );

      // Optionally open location settings
      await Geolocator.openLocationSettings();
      return false;
    }

    // Check current location permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // If already granted, return true
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    // Request permissions
    permission = await Geolocator.requestPermission();

    // Handle different permission scenarios
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return true;

      case LocationPermission.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied. Please grant permissions in app settings.')),
        );
        return false;

      case LocationPermission.deniedForever:
      // Guide user to app settings for manual permission
        await _openAppSettings(context);
        return false;

      case LocationPermission.unableToDetermine:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to determine location permissions.')),
        );
        return false;
    }
  }

  /// Open app settings for manual permission configuration
  Future<void> _openAppSettings(BuildContext context) async {
    await permission_handler.openAppSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enable location permissions in app settings.')),
    );
  }
}