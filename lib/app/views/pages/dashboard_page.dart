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
        () => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              key: const Key('dashboard-navigation'),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.softShadow,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BottomNavigationBar(
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
                  items: [
                    _navigationItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Home',
                    ),
                    _navigationItem(
                      icon: Icons.forest_outlined,
                      activeIcon: Icons.forest_rounded,
                      label: 'Forest',
                    ),
                    _navigationItem(
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield_rounded,
                      label: 'Guild',
                    ),
                    _navigationItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navigationItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(padding: const EdgeInsets.all(7), child: Icon(icon)),
      activeIcon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(activeIcon),
      ),
      label: label,
    );
  }
}
