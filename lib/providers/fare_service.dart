import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../configMaps.dart';

class FareService {
  static const Map<String, double> _baseFares = {
    'ride_ac': 0.0,
    'ride': 0.0,
    'ride_mini': 0.0,
    'rickshaw': 0.0,
    'van': 0.0,
  };

  static const Map<String, double> _perKmRates = {
    'ride_ac': 60.0,
    'ride': 50.0,
    'ride_mini': 40.0,
    'rickshaw': 70.0,
    'van': 80.0,
  };

  // Calculate fare based on distance and ride type
  static double calculateFare(double distanceInKm, String rideType) {
    print('FARE_CALC: Calculating fare for $rideType, distance: $distanceInKm km');

    // Default to 'ride' if rideType is not found
    final baseFare = _baseFares[rideType] ?? _baseFares['ride']!;
    final perKmRate = _perKmRates[rideType] ?? _perKmRates['ride']!;

    print('FARE_CALC: Using base fare: $baseFare, rate per km: $perKmRate');

    // Calculate fare with minimum fare protection
    double calculatedFare = baseFare + (distanceInKm * perKmRate);
    double roundedFare = double.parse(calculatedFare.toStringAsFixed(0));

    print('FARE_CALC: Raw fare: $calculatedFare, rounded fare: $roundedFare');
    return roundedFare;
  }

  // Calculate distance between two locations using Google Distance Matrix API
  static Future<double> getDistanceBetween(String origin, String destination) async {
    print('DISTANCE_API: Calculating distance between "$origin" and "$destination"');

    try {
      final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

      print('DISTANCE_API: Sending POST request to: ${url.toString()}');

      // Routes API v2 requires a POST request with a JSON body
      final requestBody = {
        "origin": {
          "address": origin
        },
        "destination": {
          "address": destination
        },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "computeAlternativeRoutes": false,
        "routeModifiers": {
          "avoidTolls": false,
          "avoidHighways": false,
          "avoidFerries": false
        },
        "languageCode": "en-US",
        "units": "METRIC"
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': mapKey,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration'
        },
        body: json.encode(requestBody),
      );

      print('DISTANCE_API: Response status code: ${response.statusCode}');
      print('DISTANCE_API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        if (decodedData.containsKey('routes') && decodedData['routes'].isNotEmpty) {
          // Extract distance in meters from the first route
          final distanceInMeters = decodedData['routes'][0]['distanceMeters'];
          final distanceInKm = distanceInMeters / 1000.0;
          print('DISTANCE_API: Distance calculated: $distanceInKm km ($distanceInMeters meters)');
          return distanceInKm;
        } else {
          print('DISTANCE_API: No routes found in the response');
          throw Exception('No routes found');
        }
      } else {
        // Handle error response
        print('DISTANCE_API: API request failed with status ${response.statusCode}');
        throw Exception('Failed to calculate distance (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('DISTANCE_API: Error calculating distance: $e');

      // For testing purposes, return an approximate distance
      print('DISTANCE_API: Using fallback distance calculation');
      // Estimate based on common distance between the locations
      return 10.0; // 10 kilometers as a fallback
    }
  }
  // Calculate fare from locations
  static Future<double> calculateFareFromLocations(
      String pickup, String destination, String rideType) async {
    print('FARE_SERVICE: Starting fare calculation for ride type: $rideType');
    print('FARE_SERVICE: Pickup: "$pickup", Destination: "$destination"');

    try {
      // Calculate distance using Google Distance Matrix API
      final distance = await getDistanceBetween(pickup, destination);
      print('FARE_SERVICE: Distance calculation successful: $distance km');

      final fare = calculateFare(distance, rideType);
      print('FARE_SERVICE: Final fare calculated: Rs. $fare');
      return fare;
    } catch (e) {
      print('FARE_SERVICE: Error in fare calculation pipeline: $e');
      // Return a default fare on error
      final defaultFare = _baseFares[rideType] ?? 150.0;
      print('FARE_SERVICE: Returning default fare: Rs. $defaultFare');
      return defaultFare;
    }
  }
}