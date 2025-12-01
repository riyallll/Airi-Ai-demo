import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class CallHistoryController extends GetxController {
  final String currentUid;

  CallHistoryController({required this.currentUid});

  var callHistory = <DocumentSnapshot>[].obs;
  var loading = true.obs;

  Map<String, Map<String, dynamic>> userCache = {};

  @override
  void onInit() {
    super.onInit();
    fetchCallHistory();
  }

  /// Fetch call history documents
  void fetchCallHistory() async {
    loading.value = true;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('call_history')
          .where('participants', arrayContains: currentUid)
          .orderBy('startedAt', descending: true)
          .get();

      callHistory.value = snapshot.docs;
    } catch (e) {
      print('Error fetching call history: $e');
      callHistory.clear();
    } finally {
      loading.value = false;
    }
  }

  /// Fetch user name (cached)
  Future<String> getUserName(String uid) async {
    if (userCache.containsKey(uid)) {
      return userCache[uid]!["displayName"] ?? uid;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();

      if (doc.exists) {
        userCache[uid] = doc.data()!;
        return doc["displayName"] ?? uid;
      }
    } catch (e) {
      print("Error fetching user: $e");
    }
    return uid;
  }
}
