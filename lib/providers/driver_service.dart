import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>?> fetchDriverDetails(String driverId) async {
    try {
      print('Fetching details for path: drivers/$driverId/profile');
      final snapshot = await _dbRef.child('drivers/$driverId/profile').get();

      if (snapshot.exists && snapshot.value is Map) {
        // Explicitly cast the generic Map to Map<String, dynamic>
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        print('No data found or invalid format for driverId: $driverId');
        return null;
      }
    } catch (e) {
      print('Error fetching driver details: $e');
      return null;
    }
  }


  Future<LatLng?> fetchDriverLocation(String driverId) async {
    try {
      print('Fetching location for path: drivers/$driverId/location');
      final snapshot = await _dbRef.child('drivers/$driverId/location').get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final latitude = data['latitude'] as double;
        final longitude = data['longitude'] as double;
        return LatLng(latitude,longitude);
      } else {
        print('No data found or invalid format for driverId: $driverId');
        return null;
      }
    } catch (e) {
      print('Error fetching driver location: $e');
      return null;
    }
  }

}
