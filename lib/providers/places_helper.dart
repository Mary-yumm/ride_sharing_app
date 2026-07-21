import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configMaps.dart';

class PlacesHelper {
  // Fetch autocomplete suggestions
  static Future<List<dynamic>> fetchAutocompleteSuggestions(String input, String countryCode) async {
    if (input.isEmpty) return [];

    final String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${mapKey}&components=country:$countryCode";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['predictions'];
      } else {
        throw Exception("Failed to fetch suggestions: ${response.statusCode}");
      }
    } catch (error) {
      print("Error in PlacesHelper: $error");
      return [];
    }
  }
}
