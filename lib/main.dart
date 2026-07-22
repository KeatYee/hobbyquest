import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rive/rive.dart';
import 'core/themes/app_theme.dart';
import 'core/constants/app_info.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/bindings/initial_binding.dart';
import 'app/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await RiveNative.init();
  runApp(const HobbyQuestApp());
}

class HobbyQuestApp extends StatelessWidget {
  const HobbyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.WELCOME,
      getPages: AppPages.routes,

      initialBinding: InitialBinding(),

      defaultTransition: Transition.cupertino,
    );
  }
}
