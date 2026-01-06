import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../routes/app_routes.dart'; 

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Helper to get text theme
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 1. THE HERO TITLE
              // Uses "displayLarge" which we set to Fredoka in app_theme.dart
              Text(
                "HOBBY QUEST",
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              
              // 2. THE SUBTITLE
              // Uses "bodyLarge" which we set to OpenSans in app_theme.dart
              Text(
                "Level up your real life.",
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(flex: 1), 

              // 🦊 3. THE GIANT MASCOT
              Image.asset(
                AppAssets.foxHappy,
                height: 300,
                fit: BoxFit.contain,
              ),

              const Spacer(flex: 2),

              // 4. BUTTON: GET STARTED
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.LOGIN, arguments: {'isRegistering': true});
                  },
                  // Style is already defined in app_theme.dart, so we don't need much here!
                  child: const Text("GET STARTED"),
                ),
              ),
              const SizedBox(height: 15),

              // 5. BUTTON: LOGIN
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.LOGIN, arguments: {'isRegistering': false});
                  },
                  child: const Text("I ALREADY HAVE AN ACCOUNT"),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}