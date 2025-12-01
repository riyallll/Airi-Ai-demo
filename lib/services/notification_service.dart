import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../views/call_page.dart';

/// Top-level background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.data['type'] == 'incoming_call') {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidDetails = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction(
            'accept', 'Accept', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction(
            'decline', 'Decline', showsUserInterface: true, cancelNotification: true),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Incoming Call',
      '${message.data['callerName']} is calling you',
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }
}

class NotificationService {
  NotificationService._private();
  static final NotificationService I = NotificationService._private();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  Future<void> init({required String currentUid}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        if (resp.payload != null && resp.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(resp.payload!));
            _handleNotificationTap(data, resp.actionId);
          } catch (e) {
            print('[Notification] payload parse error: $e');
          }
        }
      },
    );

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true);
    print('[Notification] permission: ${settings.authorizationStatus}');

    // Update FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      try {
        await _fs.collection('users').doc(currentUid).update({'fcmToken': token});
      } catch (e) {
        await _fs.collection('users').doc(currentUid).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
      }
    }

    _messaging.onTokenRefresh.listen((t) async {
      try {
        await _fs.collection('users').doc(currentUid).update({'fcmToken': t});
      } catch (_) {}
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'incoming_call') {
        showLocalIncomingCall(
          callerId: message.data['callerId'] ?? '',
          callerName: message.data['callerName'] ?? 'Caller',
          channelId: message.data['channelId'] ?? '',
          callType: message.data['callType'] ?? 'audio',
          roomId: message.data['roomId'] ?? '',
        );
      }
    });

    // When app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && message.data['type'] == 'incoming_call') {
        Get.to(() => CallPageWrapper(
          roomId: message.data['roomId'],
          isCaller: false,
        ));
      }
    });

    // When app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'incoming_call') {
        Get.to(() => CallPageWrapper(
          roomId: message.data['roomId'],
          isCaller: false,
        ));
      }
    });
  }

  /// Show incoming call notification with Accept/Decline buttons
  void showLocalIncomingCall({
    required String callerId,
    required String callerName,
    required String channelId,
    required String callType,
    required String roomId,
  }) async {
    final data = {
      'type': 'incoming_call',
      'callerId': callerId,
      'callerName': callerName,
      'channelId': channelId,
      'callType': callType,
      'roomId': roomId,
    };

    final payload = jsonEncode(data);

    final androidDetails = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction('accept', 'Accept',
            showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('decline', 'Decline',
            showsUserInterface: true, cancelNotification: true),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final platform = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Incoming Call',
      '$callerName is calling you',
      platform,
      payload: payload,
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data, String? actionId) async {
    final roomId = data['roomId'] ?? '';
    final channelId = data['channelId'] ?? '';
    final callType = data['callType'] ?? 'audio';
    final callerId = data['callerId'] ?? '';

    if (actionId == 'accept') {
      Get.to(() => CallPageWrapper(roomId: roomId, isCaller: false));
    } else if (actionId == 'decline') {
      try {
        await _fs.collection('call_invites').doc(roomId).delete();
      } catch (e) {
        print('[Notification] Failed to delete call invite: $e');
      }
    } else {
      // fallback: user tapped notification body
      Get.to(() => CallPageWrapper(roomId: roomId, isCaller: false));
    }
  }

  Future<void> cancelAll() => _local.cancelAll();
}
