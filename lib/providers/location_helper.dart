import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_app/configMaps.dart';

class LocationHelper {
  // Fetch the location name using coordinates
  static Future<String> getLocationName(LatLng location) async {
    print('Fetching address for location: ${location.latitude}, ${location.longitude}');

    final url = 'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=${location.latitude},${location.longitude}&key=$mapKey';

    final response = await http.get(Uri.parse(url));

    print('API URL: $url'); // Log the API URL
    print('Response Status: ${response.statusCode}'); // Log the response status code


    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      print('Response Body: ${jsonResponse}'); // Log the full JSON response

      if (jsonResponse['results'] != null &&
          (jsonResponse['results'] as List).isNotEmpty) {

        final firstResult = jsonResponse['results'][0];
        print('Full Address Components: ${firstResult['address_components']}');
        print('Formatted Address: ${firstResult['formatted_address']}');
        print('Place ID: ${firstResult['place_id']}');
        return jsonResponse['results'][0]['formatted_address'];
      } else {
        throw Exception('No address found.');
      }
    } else {
      throw Exception('Failed to fetch location name. HTTP Status: ${response.statusCode}');
    }
  }

  Future<String> getLocationNameByPlaceId(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?'
        'placeid=$placeId&key=$mapKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['result']['formatted_address'];
    }

    throw Exception('Could not retrieve location details');
  }
}
