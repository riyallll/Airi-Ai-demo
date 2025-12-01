import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../services/notification_service.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Rxn<User> firebaseUser = Rxn<User>();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _inviteSub;

  // PRESENCE SYSTEM
  StreamSubscription<DatabaseEvent>? _connSub;
  DatabaseReference? _statusRef;

  @override
  void onInit() {
    firebaseUser.bindStream(_auth.authStateChanges());

    ever(firebaseUser, (User? u) {
      if (u != null) {
        _startInviteListener(u.uid);
        NotificationService.I.init(currentUid: u.uid);
        _startPresence(u.uid);
      } else {
        _stopInviteListener();
        _stopPresence();
      }
    });

    super.onInit();
  }


  void _startPresence(String uid) {
    final db = FirebaseDatabase.instance.ref();
    _statusRef = db.child("status/$uid");

    final online = {
      "state": "online",
      "last_changed": ServerValue.timestamp,
    };

    final offline = {
      "state": "offline",
      "last_changed": ServerValue.timestamp,
    };

    _connSub = db.child(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value == true;

      if (!connected) return;

      _statusRef!.onDisconnect().set(offline);
      _statusRef!.set(online);

      FirebaseFirestore.instance.collection("users").doc(uid).update({
        "isOnline": true,
        "lastSeen": FieldValue.serverTimestamp(),
      });
    });
  }

  void _stopPresence() {
    _connSub?.cancel();
    _connSub = null;
  }

  Future<void> _setOffline(String uid) async {
    final db = FirebaseDatabase.instance.ref();
    await db.child("status/$uid").set({
      "state": "offline",
      "last_changed": ServerValue.timestamp,
    });

    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "isOnline": false,
      "lastSeen": FieldValue.serverTimestamp(),
    });
  }


  void _startInviteListener(String myUid) {
    _stopInviteListener();
    final ref = FirebaseFirestore.instance.collection('call_invites').doc(myUid);

    _inviteSub = ref.snapshots().listen((snap) async {
      if (!snap.exists) return;

      final data = snap.data()!;
      NotificationService.I.showLocalIncomingCall(
        callerId: data['callerId'] ?? "",
        callerName: data['callerName'] ?? "Caller",
        channelId: data['channelId'] ?? AppConstants.channelName,
        callType: data['callType'] ?? "audio",
        roomId: data['roomId'] ?? "",
      );
    });
  }

  void _stopInviteListener() {
    _inviteSub?.cancel();
    _inviteSub = null;
  }

  @override
  void onClose() {
    _stopInviteListener();
    super.onClose();
  }

  Future<void> signUp(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': name,
      'email': email,
      'walletBalance': 500,
      'createdAt': FieldValue.serverTimestamp(),
      'blockedUsers': [],
      'status': 'available',
    });
  }

  Future<void> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await FirebaseFirestore.instance.collection('users')
        .doc(cred.user!.uid)
        .update({
      "isOnline": true,
      "lastSeen": FieldValue.serverTimestamp(),
      "status": "available",
    });
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _setOffline(uid);
    }
    await _auth.signOut();
    _stopPresence();
  }


  Future<void> blockUser(String targetUid) async {
    final currentUid = _auth.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUid);
    await ref.update({
      'blockedUsers': FieldValue.arrayUnion([targetUid])
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final currentUid = _auth.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUid);
    await ref.update({
      'blockedUsers': FieldValue.arrayRemove([targetUid])
    });
  }
}
