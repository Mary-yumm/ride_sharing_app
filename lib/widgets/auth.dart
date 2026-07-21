import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Auth {
  // Private constructor for singleton
  Auth._privateConstructor();

  // The single instance of the class
  static final Auth _instance = Auth._privateConstructor();

  // Getter for the single instance
  static Auth get instance => _instance;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Optional driver ID and name fields
  String? driverId;
  String? name;

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);

    final User? user = currentUser;
    if (user != null) {
      final userId = user.uid;
      final DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId");

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        driverId = data['driverId'] as String?;
        name = data['name'] as String?;
      } else {
        throw Exception("User data not found in the database.");
      }
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.update({"fcmToken": token});
        print("FCM Token updated on login: $token");
      }
      listenForTokenRefresh(userId);

    } else {
      throw Exception("Failed to retrieve the current user.");
    }


  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    String userId = userCredential.user!.uid;
    String? token = await FirebaseMessaging.instance.getToken();

    await FirebaseDatabase.instance.ref("users/$userId").set({
      "email": email,
      "fcmToken": token, // Store FCM token
    });

    print("User registered with FCM Token: $token");
  }


  Future<void> signOut() async {
    driverId = null;
    name = null;
    await _firebaseAuth.signOut();
  }

  void setDriverId(String did) {
    driverId=did;
  }

  void listenForTokenRefresh(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseDatabase.instance.ref("users/$userId").update({"fcmToken": newToken});
      print("FCM Token refreshed: $newToken");
    });
  }

}
