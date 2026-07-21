import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  final String functionUrl = "https://us-central1-ride-sharing-app-acd45.cloudfunctions.net/sendNotification";

  Future<void> sendNotification(String to, String title, String body, {String notificationType = "general", Map<String, dynamic>? data}) async {
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'to': to,
        'title': title,
        'body': body,
        'data': {
          'type': notificationType,
          ...?data, // Include additional data if provided
          // Add any type-specific data here
        }
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.body}');
    }
  }
}