import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/user_controller.dart';
import '../services/call_service.dart';
import '../services/firestore_service.dart';
import 'call_history_page.dart';
import 'call_page.dart';
import '../controllers/call_controller.dart';

class HomePage extends StatelessWidget {
  final authC = Get.find<AuthController>();
  final userC = Get.put(UserController());
  final fsService = FirestoreService();

  /// Reactive list of blocked users (current user)
  final RxList<String> blockedUsers = <String>[].obs;

  HomePage() {
    userC.loadMore(); // initial load
    _loadCurrentUserBlocked();
  }

  void _showBlockPopup({required String targetUid, required bool isBlocked}) {
    Get.defaultDialog(
      title: isBlocked ? "Unblock User" : "Block User",
      middleText: isBlocked
          ? "Do you want to unblock this user?"
          : "Do you want to block this user?",
      barrierDismissible: true,
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () {
          _toggleBlock(targetUid);
          Get.back();
        },
        child: Text(
          isBlocked ? "Unblock" : "Block",
          style: TextStyle(color: Colors.white),
        ),
      ),
      cancel: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
        onPressed: () => Get.back(),
        child: Text("Cancel", style: TextStyle(color: Colors.black)),
      ),
    );
  }

  void _loadCurrentUserBlocked() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authC.firebaseUser.value!.uid)
        .get();
    blockedUsers.value = List<String>.from(doc.data()?['blockedUsers'] ?? []);
  }

  void _confirmLogout(BuildContext context) {
    Get.defaultDialog(
      title: 'Logout',
      middleText: 'Do you really want to logout?',
      barrierDismissible: true,
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF174F91),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () {
          authC.signOut();
          Get.back();
        },
        child: Text(
          'Yes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      cancel: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () => Get.back(),
        child: Text(
          'No',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Check if current user is blocked by target user
  bool _isBlockedByTarget(DocumentSnapshot<Map<String, dynamic>> targetDoc) {
    final blockedUsers = targetDoc.data()?['blockedUsers'] ?? [];
    final currentUid = authC.firebaseUser.value!.uid;
    return blockedUsers.contains(currentUid);
  }

  void _showBlockedMessage() {
    Get.snackbar(
      'Blocked',
      'You are blocked by this user.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade400,
      colorText: Colors.white,
      margin: EdgeInsets.all(12),
    );
  }

  void _toggleBlock(String targetUid) async {
    if (blockedUsers.contains(targetUid)) {
      await authC.unblockUser(targetUid);
      blockedUsers.remove(targetUid);
    } else {
      await authC.blockUser(targetUid);
      blockedUsers.add(targetUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = authC.firebaseUser.value!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Users',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF174F91),
        actions: [
          IconButton(
            onPressed: () => Get.to(() => CallHistoryPage()),
            icon: Icon(Icons.history, color: Colors.white),
          ),

          IconButton(
            onPressed: () => _confirmLogout(context),
            icon: Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Obx(() {
        final list = userC.users;
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length + 1,
          itemBuilder: (ctx, idx) {
            if (idx == list.length - 10 && !userC.endReached.value)
              userC.loadMore();

            if (idx == list.length) {
              if (userC.endReached.value) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No more users',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Color(0xFF174F91)),
                ),
              );
            }

            final doc = list[idx];
            final data = doc.data() as Map<String, dynamic>;
            if (data['uid'] == currentUid) return SizedBox.shrink();

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF174F91).withOpacity(0.9),
                    Color(0xFF174F91).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: GestureDetector(
                onLongPress: () {
                  final userId = data['uid'];
                  final bool isBlocked = blockedUsers.contains(userId);

                  _showBlockPopup(targetUid: userId, isBlocked: isBlocked);
                },
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Text(
                          (data['displayName']?.isNotEmpty ?? false)
                              ? data['displayName'][0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF174F91),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (data['isOnline'] ?? false)
                                ? Colors.green
                                : Colors.grey,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    data['displayName'] ?? 'No name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${data['email'] ?? ''} • ${data['walletBalance'] ?? 0} coins',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: Obx(() {
                    final hasBlockedTargetUser = blockedUsers.contains(
                      data['uid'],
                    );
                    final isBlockedByTargetUser = _isBlockedByTarget(doc);

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // AUDIO BUTTON (unchanged)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isBlockedByTargetUser || hasBlockedTargetUser
                                ? Colors.grey
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: isBlockedByTargetUser
                              ? _showBlockedMessage
                              : hasBlockedTargetUser
                              ? () {
                                  Get.snackbar(
                                    'Blocked',
                                    'You have blocked this user.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red.shade400,
                                    colorText: Colors.white,
                                    margin: EdgeInsets.all(12),
                                  );
                                }
                              : () async {
                                  final roomId = await fsService.createCallRoom(
                                    callerId: currentUid,
                                    calleeId: data['uid'],
                                    callType: 'audio',
                                  );

                                  await CallService.I.sendCallInvite(
                                    callerId: currentUid,
                                    callerName: data['displayName'] ?? 'Caller',
                                    calleeId: data['uid'],
                                    roomId: roomId,
                                    callType: 'audio',
                                  );

                                  if (Get.isRegistered<CallController>()) {
                                    Get.delete<CallController>(force: true);
                                  }
                                  Get.put(CallController());
                                  Get.to(
                                    () => CallPageWrapper(
                                      roomId: roomId,
                                      isCaller: true,
                                    ),
                                  );
                                },
                          child: Icon(
                            Icons.call,
                            color: isBlockedByTargetUser || hasBlockedTargetUser
                                ? Colors.white70
                                : Color(0xFF174F91),
                          ),
                        ),

                        SizedBox(width: 8),

                        // VIDEO BUTTON (unchanged)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isBlockedByTargetUser || hasBlockedTargetUser
                                ? Colors.grey
                                : Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: isBlockedByTargetUser
                              ? _showBlockedMessage
                              : hasBlockedTargetUser
                              ? () {
                                  Get.snackbar(
                                    'Blocked',
                                    'You have blocked this user.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red.shade400,
                                    colorText: Colors.white,
                                    margin: EdgeInsets.all(12),
                                  );
                                }
                              : () async {
                                  final roomId = await fsService.createCallRoom(
                                    callerId: currentUid,
                                    calleeId: data['uid'],
                                    callType: 'video',
                                  );

                                  await CallService.I.sendCallInvite(
                                    callerId: currentUid,
                                    callerName: data['displayName'] ?? 'Caller',
                                    calleeId: data['uid'],
                                    roomId: roomId,
                                    callType: 'video',
                                  );

                                  if (Get.isRegistered<CallController>()) {
                                    Get.delete<CallController>(force: true);
                                  }
                                  Get.put(CallController());
                                  Get.to(
                                    () => CallPageWrapper(
                                      roomId: roomId,
                                      isCaller: true,
                                    ),
                                  );
                                },
                          child: Icon(
                            Icons.videocam,
                            color: isBlockedByTargetUser || hasBlockedTargetUser
                                ? Colors.white70
                                : Colors.white,
                          ),
                        ),


                      ],
                    );
                  }),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
