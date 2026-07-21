import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth.dart';

class FirebaseMessagingHandler {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {

    // Get the FCM token
    String? token = await _firebaseMessaging.getToken();
    print("FCM Token: $token");

    // Save the token to your backend or Firebase Firestore/Database
    saveTokenToDatabase(token);

  }

  Future<void> showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'ride_sharing_notifications',
      'Ride Sharing Notifications',
      channelDescription: 'Notifications for ride updates and messages',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      // Add iOS details if needed
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? "New Notification",
      message.notification?.body ?? "",
      platformChannelSpecifics,
      payload: jsonEncode(message.data), // Pass payload to handle notification taps
    );
  }

  void saveTokenToDatabase(String? token) {
    if(token==null) {
      print("Token is null");
      return;
    }
    // Save the token to your backend or Firebase Real time Database

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Use the existing Auth class to update the token
      FirebaseDatabase.instance.ref("users/${user.uid}").update({
        "fcmToken": token
      }).then((_) {
        print("FCM Token saved successfully for user: ${user.uid}");
      }).catchError((error) {
        print("Failed to save FCM token: $error");
      });

      // Set up the token refresh listener
      Auth.instance.listenForTokenRefresh(user.uid);
    } else {
      print("No user is currently logged in");
    }

  }
}