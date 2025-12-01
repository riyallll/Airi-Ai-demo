import 'package:agora_firebase_app/views/call_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'constants.dart';
import 'controllers/auth_controller.dart';
import 'controllers/call_controller.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';
import 'services/notification_service.dart'; // <-- make sure this path is correct

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // MethodChannel for native call actions (if needed)
  const platform = MethodChannel('com.example.agora_firebase_app/call');
  platform.setMethodCallHandler((call) async {
    if (call.method == 'openCallScreen') {
      final roomId = call.arguments['roomId'] as String;
      Get.to(() => CallPageWrapper(roomId: roomId, isCaller: false));
    }
  });

  // Register AuthController
  Get.put(AuthController());

  // Initialize notifications
  final authC = Get.find<AuthController>();
  final currentUid = authC.firebaseUser.value?.uid ?? '';
  if (currentUid.isNotEmpty) {
    await NotificationService.I.init(currentUid: currentUid);
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Agora Call App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => RootPage()),

        GetPage(
          name: '/incoming_call',
          page: () {
            final params = Get.parameters;
            final roomId = params['roomId'] ?? '';

            if (Get.isRegistered<CallController>()) {
              Get.delete<CallController>(force: true);
            }
            Get.put(CallController());

            return CallPageWrapper(roomId: roomId, isCaller: false);
          },
        ),
      ],
    );
  }
}

class RootPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthController authC = Get.find<AuthController>();
    return Obx(() {
      if (authC.firebaseUser.value == null) return LoginPage();
      return HomePage();
    });
  }
}
