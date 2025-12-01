  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:get/get.dart';
  import 'package:permission_handler/permission_handler.dart';
  import '../constants.dart';
  import '../controllers/call_controller.dart';
  import '../controllers/auth_controller.dart';
  import '../widgets/video_views.dart';

  class CallPageWrapper extends StatefulWidget {
    final String roomId;
    final bool isCaller;

    const CallPageWrapper({
      required this.roomId,
      required this.isCaller,
      Key? key,
    }) : super(key: key);

    @override
    State<CallPageWrapper> createState() => _CallPageWrapperState();
  }

  class _CallPageWrapperState extends State<CallPageWrapper> {
    late CallController callC;
    bool isMuted = false;
    bool isSpeakerOn = true;

    @override
    void initState() {
      super.initState();

      if (!Get.isRegistered<CallController>()) {
        callC = Get.put(CallController());
      } else {
        callC = Get.find<CallController>();
      }

      initPermissionsAndJoin();
    }


    Future<void> initPermissionsAndJoin() async {
      await [Permission.microphone, Permission.camera].request();
      try {
        await callC.initAndJoin(widget.roomId, widget.isCaller);
      } catch (e) {
        print('[CallPage] initAndJoin failed: $e');
        Get.snackbar('Call error', e.toString());
      }
    }

    @override
    Widget build(BuildContext context) {
      final authC = Get.find<AuthController>();
      return Scaffold(
        body: SafeArea(
          child: Obx(() {
            final engine = callC.engine;
            final remote = callC.remoteUid.value;
            final channelId = callC.currentChannelId;
            final joined = callC.localJoined.value;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF174F91), Colors.blue.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Main remote / waiting view
                  Positioned.fill(
                    child: engine == null
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : (callC.callType == 'video'
                              ? (remote == null
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Waiting for remote...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            if (!joined)
                                              Text(
                                                'Joining...',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16,
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    : RemoteVideoView(
                                        engine: engine,
                                        uid: remote,
                                        channelId: channelId,
                                      ))
                              : const Center(
                                  child: Icon(
                                    Icons.mic,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                )),
                  ),

                  // Small local preview
                  Positioned(
                    right: 16,
                    top: 48,
                    width: 120,
                    height: 160,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: engine == null
                          ? Container()
                          : (callC.callType == 'video'
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: LocalVideoView(engine: engine),
                                  )
                                : Center(
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )),
                    ),
                  ),

                  // Top info card
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(
                            () => Text(
                              'Elapsed: ${Duration(seconds: callC.elapsedSec.value).toString().split('.').first}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Obx(
                            () => Text(
                              'Charged: ${callC.chargedCoins.value} coins',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom controls
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // mute
                        FloatingActionButton(
                          heroTag: 'mute',
                          backgroundColor: isMuted ? Colors.red : Colors.white,
                          onPressed: () {
                            setState(() => isMuted = !isMuted);
                            callC.engine?.muteLocalAudioStream(isMuted);
                          },
                          child: Icon(
                            isMuted ? Icons.mic_off : Icons.mic,
                            color: isMuted ? Colors.white : Color(0xFF174F91),
                          ),
                        ),

                        // switch camera
                        if (callC.callType == 'video')
                          FloatingActionButton(
                            heroTag: 'switch',
                            backgroundColor: Colors.white,
                            onPressed: () {
                              callC.engine?.switchCamera();
                            },
                            child: Icon(
                              Icons.switch_camera,
                              color: Color(0xFF174F91),
                            ),
                          ),

                        // speaker
                        FloatingActionButton(
                          heroTag: 'speaker',
                          backgroundColor: isSpeakerOn
                              ? Colors.white
                              : Colors.red,
                          onPressed: () async {
                            setState(() => isSpeakerOn = !isSpeakerOn);
                            try {
                              await callC.engine?.setEnableSpeakerphone(
                                isSpeakerOn,
                              );
                            } catch (e) {
                              print('[CallPage] setEnableSpeakerphone error: $e');
                            }
                          },
                          child: Icon(
                            isSpeakerOn
                                ? Icons.volume_up
                                : Icons.hearing_disabled,
                            color: isSpeakerOn ? Color(0xFF174F91) : Colors.white,
                          ),
                        ),

                        // end call
                        FloatingActionButton(
                          heroTag: 'end',
                          backgroundColor: Colors.red,
                          onPressed: () async {
                            await callC.endCallManually();
                            Get.delete<CallController>(
                              force: true,
                            ); // <- important
                            Get.back();
                          },
                          child: const Icon(Icons.call_end, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    }
  }
