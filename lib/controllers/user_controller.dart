import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class UserController extends GetxController {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  final RxList<DocumentSnapshot<Map<String, dynamic>>> users =
      <DocumentSnapshot<Map<String, dynamic>>>[].obs;

  QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
  var endReached = false.obs;
  var loading = false.obs;

  // Store listeners for real-time updates
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _userSubs = {};

  @override
  void onClose() {
    // Cancel all user listeners
    _userSubs.forEach((key, sub) => sub.cancel());
    super.onClose();
  }

  Future<void> loadMore({int limit = 15}) async {
    if (loading.value || endReached.value) return;
    loading.value = true;

    Query<Map<String, dynamic>> q =
    _fs.collection('users').orderBy('displayName').limit(limit);

    if (lastDoc != null) {
      q = q.startAfterDocument(lastDoc!);
    }

    final snap = await q.get();

    if (snap.docs.isEmpty) {
      endReached.value = true;
    } else {
      for (var doc in snap.docs) {
        users.add(doc);

        if (!_userSubs.containsKey(doc.id)) {
          final sub = _fs
              .collection('users')
              .doc(doc.id)
              .snapshots()
              .listen((updatedSnap) {
            final index = users.indexWhere((e) => e.id == updatedSnap.id);
            if (index != -1) {
              users[index] = updatedSnap; // type safe now
            }
          });
          _userSubs[doc.id] = sub;
        }
      }

      lastDoc = snap.docs.last;
    }

    loading.value = false;
  }
}
