import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; // This imports the Location class

class DirectionsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json?';

  final String apiKey;

  DirectionsService(this.apiKey);

  Future<Map<String, dynamic>> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving', // Default to driving mode
  }) async {
    final String url =
        '${_baseUrl}origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=$mode&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data['status'] == 'OK') {
      // Decode the polyline points
      List<LatLng> points = [];
      String encodedPoints = data['routes'][0]['overview_polyline']['points'];
      points = _decodePolyline(encodedPoints);

      // Get the duration of the trip
      String durationText = data['routes'][0]['legs'][0]['duration']['text'];
      int durationValue = data['routes'][0]['legs'][0]['duration']['value'];

      return {
        'points': points, // List<LatLng> for the polyline
        'durationText': durationText, // String for human-readable duration (e.g., "1 hour 30 mins")
        'durationValue': durationValue, // Int for duration in seconds
      };
    } else {
      throw Exception('Failed to load directions: ${data['status']}');
    }
  }

  // Helper method to decode the polyline
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
  Future<LatLng> getCoordinates(String address) async {
    List<Location> locations = await locationFromAddress(address);
    return LatLng(locations.first.latitude, locations.first.longitude);
  }
}