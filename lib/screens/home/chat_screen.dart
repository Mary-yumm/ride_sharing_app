import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:ride_sharing_app/Notifications/NotificationService.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;


class ChatScreen extends StatefulWidget {
  final String driverId;
  final String riderId;
  final String phone;
  final String fcmToken;

  const ChatScreen({Key? key, required this.driverId, required this.riderId, required this.phone,required this.fcmToken}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref().child('chats');
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    //print fcm token with message
    print('fcm token: ${widget.fcmToken}');
    _chatId = '${widget.driverId}_${widget.riderId}';
    FirebaseMessaging.onMessage.listen(_handleMessage);


  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        await _chatRef.child(_chatId).push().set({
          'senderId': FirebaseAuth.instance.currentUser?.uid,
          'message': _messageController.text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        await notificationService.sendNotification(
          widget.fcmToken,
          "New Message",
          _messageController.text,
          notificationType: "chat",
          data: {
            'driverId': widget.driverId,
            'riderId': widget.riderId,
            'phone': widget.phone,
            'fcmToken': widget.fcmToken,
          },
        );
        print("Notification sent to recipient with token: ${widget.fcmToken}");

        _messageController.clear();
        _scrollToBottom();
      } catch (e) {
        print('Failed to send message: $e');
      }
    }
  }

  void _handleMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text(notification.title ?? ''),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(notification.body ?? '')],
              ),
            ),
          );
        },
      );
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _makeCall() async {
    final status = await Permission.phone.request();

    if (status.isGranted) {
      final Uri url = Uri(scheme: 'tel', path: widget.phone);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch $url';
      }
    } else if (status.isDenied) {
      // Handle the case when the permission is denied
      print('Phone permission denied');
    } else if (status.isPermanentlyDenied) {
      // Handle the case when the permission is permanently denied
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        backgroundColor: AppColors.secondaryLight,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.call),
            onPressed: _makeCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatRef.child(_chatId).orderByChild('timestamp').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                  List<Map<dynamic, dynamic>> messages = [];
                  snapshot.data!.snapshot.children.forEach((child) {
                    messages.add(child.value as Map<dynamic, dynamic>);
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var message = messages[index];
                      bool isMe = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              message['message'],
                              style: TextStyle(color: isMe ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(child: Text('No messages yet.'));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                  ),
                ),
                SizedBox(width: 8.0),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: AppColors.secondary.value),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}