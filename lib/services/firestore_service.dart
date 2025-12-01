import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class FirestoreService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final DatabaseReference presenceRef = FirebaseDatabase.instance.ref('presence');

  Future<String> createCallRoom({
    required String callerId,
    required String calleeId,
    required String callType, // 'audio' or 'video'
  }) async {
    final roomId = Uuid().v4();
    // We write channelId explicitly to AppConstants.channelName to stay in-sync with the static token
    await _fs.collection('call_rooms').doc(roomId).set({
      'roomId': roomId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callType': callType,
      'channelId': AppConstants.channelName,
      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _fs.collection('users').doc(calleeId).update({'status': 'ringing'});
    return roomId;
  }
}
