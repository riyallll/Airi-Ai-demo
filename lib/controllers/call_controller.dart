// lib/controllers/call_controller.dart
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import 'auth_controller.dart';

class CallController extends GetxController {
  RtcEngine? engine;
  Timer? timer;
  var elapsedSec = 0.obs;
  var chargedCoins = 0.obs;
  String roomId = '';
  String callType = 'audio';
  var remoteUid = RxnInt();
  var localJoined = false.obs;
  String currentChannelId = AppConstants.channelName;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Initialize engine and join channel for roomIdArg
  Future<void> initAndJoin(String roomIdArg, bool isCaller) async {
    roomId = roomIdArg;

    try {
      final doc = await _fs.collection('call_rooms').doc(roomId).get();
      if (doc.exists) {
        final data = doc.data()!;
        callType = (data['callType'] ?? 'audio') as String;
        currentChannelId = (data['channelId'] ?? AppConstants.channelName) as String;
      } else {
        // fallback
        callType = 'audio';
        currentChannelId = AppConstants.channelName;
      }
    } catch (e) {
      currentChannelId = AppConstants.channelName;
      callType = 'audio';
    }

    engine = createAgoraRtcEngine();
    await engine!.initialize(RtcEngineContext(appId: AppConstants.agoraAppId));

    engine!.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          print('[Agora][Error] $err : $msg');
        },

        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state,
            ConnectionChangedReasonType reason) {
          print('[Agora][Connection] ${connection.channelId} state=$state reason=$reason');
        },

        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('[Agora] Joined channel ${connection.channelId} (elapsed:$elapsed)');
          localJoined.value = true;
          // set speaker after join — wrap in try so we don't crash app if platform returns error
          try {
            engine?.setEnableSpeakerphone(true);
          } catch (e) {
            print('[Agora] setEnableSpeakerphone error (ignored): $e');
          }
        },

        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          print('[Agora] Remote user joined uid=$uid');
          remoteUid.value = uid;
          // we do not need to call setupRemoteVideo when using AgoraVideoView.remote (but safe to call)
          try {
            engine!.setupRemoteVideo(VideoCanvas(uid: uid));
          } catch (e) {
            // ignore
          }
        },

        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          print('[Agora] Remote user offline uid=$uid reason=$reason');
          remoteUid.value = null;
        },

        onLocalVideoStateChanged: (
            VideoSourceType source,
            LocalVideoStreamState state,
            LocalVideoStreamReason reason,
            ) {
          print('[Agora] LocalVideoState source=$source state=$state reason=$reason');
        },


        onRemoteVideoStateChanged:
            (RtcConnection connection, int uid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          print('[Agora] RemoteVideoState uid=$uid state=$state reason=$reason elapsed=$elapsed');
        },
      ),
    );

    if (callType == 'video') {
      await engine!.enableVideo();
      // Do NOT rely solely on engine.setupLocalVideo — AgoraVideoView widget will render local frames.
      // Setting encoder is optional - keep reasonable defaults
      await engine!.setVideoEncoderConfiguration(VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 30,
      ));
      // Start preview (safe)
      try {
        await engine!.startPreview();
      } catch (e) {
        print('[Agora] startPreview error: $e');
      }
    } else {
      // For audio-only, ensure audio enabled
      try {
        await engine!.enableAudio();
      } catch (_) {}
    }

    if (isCaller) {
      try {
        await _fs.collection('call_rooms').doc(roomId).update({
          'status': 'ongoing',
          'startedAt': FieldValue.serverTimestamp(),
          'channelId': currentChannelId,
        });
      } catch (e) {
        print('[CallRoom] update error: $e');
      }
    } else {
      final auth = Get.find<AuthController>();
      final myUid = auth.firebaseUser.value?.uid;
      if (myUid != null) {
        try {
          await _fs.collection('users').doc(myUid).update({'status': 'in_call'});
        } catch (e) {}
      }
    }

    try {
      await engine!.joinChannel(
        token: AppConstants.agoraToken,
        channelId: currentChannelId,
        uid: 0, // using 0 so server assigns a uid — token must match channel & allow uid 0
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      print('[Agora] joinChannel failed: $e');
      rethrow;
    }

    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      elapsedSec.value++;
      if (elapsedSec.value % 60 == 0) {
        await deductPerMinute();
      }
    });
  }

  Future<void> deductPerMinute() async {
    final auth = Get.find<AuthController>();
    final callerId = auth.firebaseUser.value?.uid;
    if (callerId == null) return;
    final cost = (callType == 'video') ? AppConstants.videoCostPerMinute : AppConstants.audioCostPerMinute;
    final userRef = _fs.collection('users').doc(callerId);

    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return;
        int balance = (snap.data()!['walletBalance'] ?? 0) as int;
        if (balance < cost) {
          await _fs.collection('call_rooms').doc(roomId).update({'status': 'ended'});
          return;
        }
        int newBalance = balance - cost;
        tx.update(userRef, {'walletBalance': newBalance});
        await _fs.collection('wallet_transactions').add({
          'txId': DateTime.now().millisecondsSinceEpoch.toString(),
          'userId': callerId,
          'type': 'debit',
          'amount': cost,
          'reason': 'call_charge',
          'relatedCallId': roomId,
          'timestamp': FieldValue.serverTimestamp(),
          'balanceAfter': newBalance
        });
        chargedCoins.value += cost;
      });
    } catch (e) {
      print('[Billing] transaction failed: $e');
    }

    final latest = await userRef.get();
    final latestBalance = (latest.data()!['walletBalance'] ?? 0) as int;
    if (latestBalance <= 0) {
      await _fs.collection('call_rooms').doc(roomId).update({'status': 'ended'});
    }
  }

  Future<void> endCallManually() async {
    timer?.cancel();
    try {
      await _fs.collection('call_rooms').doc(roomId).update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
    } catch (e) {}
    await writeCallHistory();
    try {
      await engine?.leaveChannel();
    } catch (e) {}
    try {
      await engine?.release();
    } catch (e) {}
  }

  Future<void> writeCallHistory() async {
    try {
      final room = await _fs.collection('call_rooms').doc(roomId).get();
      if (!room.exists) return;
      final data = room.data()!;
      await _fs.collection('call_history').doc(roomId).set({   // use doc(roomId) to match your design
        'callId': roomId,
        'callerId': data['callerId'],
        'calleeId': data['calleeId'],
        'participants': [data['callerId'], data['calleeId']], // ✅ add this
        'callType': data['callType'],
        'startedAt': data['startedAt'],
        'endedAt': FieldValue.serverTimestamp(),
        'durationSeconds': elapsedSec.value,
        'costChargedToCaller': chargedCoins.value,
      });

      await _fs.collection('users').doc(data['callerId']).update({'status': 'available'});
      await _fs.collection('users').doc(data['calleeId']).update({'status': 'available'});
    } catch (e) {
      print('[CallHistory] write failed: $e');
    }
  }

  @override
  void onClose() {
    if (engine != null) {
      try { engine!.leaveChannel(); } catch (_) {}
      try { engine!.stopPreview(); } catch (_) {}
      try { engine!.release(); } catch (_) {}
    }

    timer?.cancel();
    engine = null;

    super.onClose();
  }


}
