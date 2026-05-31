import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/dashboard_controller.dart';
import '../../../core/constants/color_constants.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'guild_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller
    final DashboardController controller = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: AppColors.background,
      
      // ✅ IndexedStack preserves the state of pages (scrolling, text inputs)
      body: Obx(() => IndexedStack(
        index: controller.tabIndex.value,
        children: const [
          HomePage(),                      // Index 0: Your detailed Home Page
          Center(child: Text("Map Content")),   // Index 1: Placeholder
          GuildPage(), // Index 2: Guild
          ProfilePage(),                        // Index 3: Profile with Logout
        ],
      )),

      // ✅ Bottom Navigation Bar with your Theme Colors
      bottomNavigationBar: Obx(() => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
          ],
        ),
        child: BottomNavigationBar(
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
              label: "HQ"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined), 
              activeIcon: Icon(Icons.map_rounded),
              label: "Map"
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
        ),
      )),
    );
  }
}