import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/dashboard_controller.dart';
import '../../../core/constants/color_constants.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'guild_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller
    final DashboardController controller = Get.put(DashboardController());
    controller.applyRouteArguments(Get.arguments);

    return Scaffold(
      backgroundColor: AppColors.background,
      
      // ✅ IndexedStack preserves the state of pages (scrolling, text inputs)
      body: Obx(() => IndexedStack(
        index: controller.tabIndex.value,
        children: const [
          HomePage(),                      // Index 0: Your detailed Home Page
          MapPage(),                       // Index 1: Map
          GuildPage(), // Index 2: Guild
          ProfilePage(),                        // Index 3: Profile with Logout
        ],
      )),

      // ✅ Bottom Navigation Bar with your Theme Colors
      bottomNavigationBar: Obx(() => BottomNavigationBar(
          currentIndex: controller.tabIndex.value,
          onTap: controller.changeTabIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface, // Pure White
          selectedItemColor: AppColors.primary, // Orange
          unselectedItemColor: AppColors.textSecondary, // Grey
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), 
              activeIcon: Icon(Icons.dashboard_rounded),
              label: "Home"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forest_outlined), 
              activeIcon: Icon(Icons.forest_rounded),
              label: "Forest"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined), 
              activeIcon: Icon(Icons.shield_rounded),
              label: "Guild"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded), 
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile"
            ),
          ],
      )),
    );
  }
}
