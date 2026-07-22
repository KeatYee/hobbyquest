import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/dashboard_controller.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'guild_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.put(DashboardController());
    controller.applyRouteArguments(Get.arguments);

    return Scaffold(
      backgroundColor: AppColors.background,

      body: Obx(
        () => IndexedStack(
          index: controller.tabIndex.value,
          children: const [HomePage(), MapPage(), GuildPage(), ProfilePage()],
        ),
      ),

      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          currentIndex: controller.tabIndex.value,
          onTap: controller.changeTabIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppFonts.badge,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: AppFonts.badge,
          ),
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forest_outlined),
              activeIcon: Icon(Icons.forest_rounded),
              label: "Forest",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded),
              label: "Guild",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
