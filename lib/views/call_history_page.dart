import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/CallHistoryController.dart';
import '../controllers/auth_controller.dart';
import 'package:intl/intl.dart';

class CallHistoryPage extends StatelessWidget {
  final authC = Get.find<AuthController>();
  late final CallHistoryController chC;

  CallHistoryPage({super.key}) {
    chC = Get.put(
      CallHistoryController(currentUid: authC.firebaseUser.value!.uid),
    );
  }

  String formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call History', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF174F91),
        iconTheme: IconThemeData(color: Colors.white),   // ← back button color

      ),
      body: Obx(() {
        if (chC.loading.value) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF174F91)),
          );
        }

        if (chC.callHistory.isEmpty) {
          return Center(
            child: Text(
              'No call history',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.builder(
          itemCount: chC.callHistory.length,
          itemBuilder: (ctx, idx) {
            final data = chC.callHistory[idx].data() as Map<String, dynamic>;

            final isCaller = data['callerId'] == authC.firebaseUser.value!.uid;
            final counterpartUid = isCaller
                ? data['calleeId']
                : data['callerId'];

            final startedAt = (data['startedAt'] as Timestamp).toDate();
            final endedAt =
                (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return FutureBuilder(
              future: chC.getUserName(counterpartUid),
              builder: (context, snapshot) {
                final displayName = snapshot.data ?? "Loading...";

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: data['callType'] == 'audio'
                          ? Colors.blue
                          : Colors.green,
                      child: Icon(
                        data['callType'] == 'audio'
                            ? Icons.call
                            : Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                    title: Text('${isCaller ? "To" : "From"}: $displayName'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration: ${formatDuration(data['durationSeconds'] ?? 0)}',
                        ),
                        Text('Cost: ${data['costChargedToCaller'] ?? 0} coins'),
                        Text(
                          'Started: ${DateFormat.yMMMd().add_jm().format(startedAt)}',
                        ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat.jm().format(endedAt),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }
}
