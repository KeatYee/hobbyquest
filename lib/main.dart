import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rive/rive.dart';
import 'core/themes/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/bindings/initial_binding.dart';
import 'app/services/push_notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await RiveNative.init();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. Falling back to mock AI data.");
  }
  runApp(const HobbyQuestApp());
}

class HobbyQuestApp extends StatelessWidget {
  const HobbyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HobbyQuest',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.WELCOME,
      getPages: AppPages.routes,

      initialBinding: InitialBinding(),

      defaultTransition: Transition.cupertino,
    );
  }
}
