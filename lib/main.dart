import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';

// Import your new Core & Route files
import 'core/themes/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/bindings/initial_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HobbyQuestApp());
}

class HobbyQuestApp extends StatelessWidget {
  const HobbyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HobbyQuest',
      debugShowCheckedModeBanner: false,

      // 1. Apply the new Fox Theme 
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