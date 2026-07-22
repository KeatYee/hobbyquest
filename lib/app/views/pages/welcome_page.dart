import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/constants/app_info.dart';
import '../../routes/app_routes.dart';
import '../widgets/rive_animation_widget.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              Text(
                AppInfo.brandLabel,
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                "Level up your real life.",
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(flex: 1),

              RiveAnimationWidget(
                assetPath: AppAssets.hobieRive,
                height: 300,
                fit: BoxFit.contain,
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Get.toNamed(
                      AppRoutes.LOGIN,
                      arguments: {'isRegistering': true},
                    );
                  },
                  child: const Text("GET STARTED"),
                ),
              ),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Get.toNamed(
                      AppRoutes.LOGIN,
                      arguments: {'isRegistering': false},
                    );
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
