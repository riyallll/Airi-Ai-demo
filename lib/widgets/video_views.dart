// lib/widgets/video_views.dart
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class LocalVideoView extends StatelessWidget {
  final RtcEngine engine;
  const LocalVideoView({required this.engine, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0, sourceType: VideoSourceType.videoSourceCamera),
      ),
    );
  }
}

class RemoteVideoView extends StatelessWidget {
  final RtcEngine engine;
  final int uid;
  final String channelId;
  const RemoteVideoView({required this.engine, required this.uid, required this.channelId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }
}
