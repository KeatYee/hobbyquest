import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rive/rive.dart';
import 'core/themes/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/bindings/initial_binding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await RiveNative.init();
  // Safe loading for .env
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

      // 1. Apply the Theme
      theme: AppTheme.lightTheme,

      // 2. Set up Named Routes
      initialRoute: AppRoutes.WELCOME,
      getPages: AppPages.routes,

      // 3. Global Dependencies
      initialBinding: InitialBinding(),

      // 4. Smooth Transitions
      defaultTransition: Transition.cupertino,
    );
  }
}
