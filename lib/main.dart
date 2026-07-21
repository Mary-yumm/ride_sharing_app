// main.dart
import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ride_sharing_app/screens/driver/home/driver_home_screen.dart';
import 'package:ride_sharing_app/screens/home/chat_screen.dart';
import 'package:ride_sharing_app/screens/home/home_screen.dart';
import 'package:ride_sharing_app/screens/login_screen.dart';
import 'package:ride_sharing_app/splash_screen.dart';
import 'Notifications/FirebaseMessagingHandler.dart';
import 'screens/nav_bar_screen.dart';
import 'widget_tree.dart';
import 'utils/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ride_sharing_app/screens/registration_screen.dart';
import 'package:provider/provider.dart';
import 'package:ride_sharing_app/providers/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling background message: ${message.messageId}");
  if (message.data['chatId'] != null) {
    String chatId = message.data['chatId'];
    print('Notification tapped for chatId bg: $chatId');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppColors.loadColor();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize local notifications
  await initLocalNotifications();

  // Setup Firebase Messaging
  setupFirebaseMessaging();

  // Initialize FirebaseMessagingHandler
  FirebaseMessagingHandler firebaseMessagingHandler = FirebaseMessagingHandler();
  await firebaseMessagingHandler.init();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification permissions
  await _requestNotificationPermissions();

  // Get and print the FCM token for debugging
  await _printFCMToken();

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      print(message);
    };
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Initialize Local Notifications
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );


  void handleNotificationNavigation(Map<String, dynamic> payload) {
    String? type = payload['type'];
    print("Handling notification navigation with payload type: $type");
    print("Full payload: $payload");

    switch (type) {
      case 'ride_accepted':
      // Navigate to ride tracking page
        print("Navigating to HomeScreen for ride_accepted notification");
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        ).then((_) => print("Navigation to HomeScreen complete"));
        break;
      case 'ride_request':
      // Navigate to ride tracking page
        print("Navigating to HomeScreen for ride_request notification");
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => DriverHomeScreen()),
        ).then((_) => print("Navigation to HomeScreen complete"));
        break;
      case 'chat':
      // Navigate to chat screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
                driverId: payload['driverId'] ?? "",
                riderId: payload['riderId'] ?? "",
                phone: payload['phone'] ?? "",
                fcmToken: payload['fcmToken'] ?? ""
            ),
          ),
        );
        break;
    // Add more cases as needed
      default:
        print("Unknown notification type: $type - No navigation performed");
        //default to home
        break;
    }
  }

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Parse the payload
      if (response.payload != null) {
        Map<String, dynamic> payload = jsonDecode(response.payload!);
        handleNotificationNavigation(payload);
      }
    },
  );


  // Check if app was launched from a notification
  final NotificationAppLaunchDetails? launchDetails =
  await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
    final String? payload = launchDetails.notificationResponse?.payload;
    if (payload == "chat") {
      // Handle notification that launched the app
      // This will run after your app is fully initialized
      Future.delayed(Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
                driverId: "driverId",
                riderId: "riderId",
                phone: "phone",
                fcmToken: "fcmToken"
            ),
          ),
        );
      });
    }
  }

  // Create the notification channel
  await createNotificationChannel();
}

// Create Notification Channel (Android)
Future<void> createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'ride_sharing_notifications', // Same as in showNotification
    'Ride Sharing Notifications', // Same as in showNotification
    description: 'Notifications for ride updates and messages', // Same as in showNotification
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// Request Notification Permissions
Future<void> _requestNotificationPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: true, // For Android 13+
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }
}

// Print the FCM Token
Future<void> _printFCMToken() async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");
  } catch (e) {
    print("Error getting FCM token: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Ride Sharing App',
          theme: themeProvider.themeData,
          home: SplashScreen(nextScreen: const WidgetTree()),
          routes: {
            '/register': (context) => const RegistrationPage(),
            '/login': (context) => const LoginPage(),
            '/hamburgerMenu': (context) => HamburgerMenuScreen(),
          },
        );
      },
    );
  }
}

// Listen for incoming messages
void setupFirebaseMessaging() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Message received: ${message.notification?.title}");
    // Display the notification
    FirebaseMessagingHandler().showNotification(message);
  });

}