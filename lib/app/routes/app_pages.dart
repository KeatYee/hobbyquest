import 'package:get/get.dart';
import 'app_routes.dart';

import '../views/pages/welcome_page.dart';
import '../views/pages/login_page.dart';
import '../views/pages/onboarding/onboarding_view.dart';
import '../views/pages/home_page.dart';
import '../views/pages/dashboard_page.dart';
import '../views/pages/quest_detail_page.dart';
import '../views/pages/user_profile_page.dart';
import '../views/pages/user_guild_posts_page.dart';
import '../views/pages/forest_page.dart';
import '../views/pages/goal_history_page.dart';
import '../views/pages/privacy_security_page.dart';
import '../views/pages/help_support_page.dart';
import '../views/pages/growth_letter_page.dart';
import '../bindings/onboarding_binding.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.WELCOME,
      page: () => const WelcomePage(),
      transition: Transition.fadeIn,
    ),
    GetPage(name: AppRoutes.LOGIN, page: () => const LoginPage()),
    GetPage(
      name: AppRoutes.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(name: AppRoutes.DASHBOARD, page: () => const DashboardPage()),
    GetPage(name: AppRoutes.HOME, page: () => const HomePage()),
    GetPage(
      name: AppRoutes.QUEST_DETAIL,
      page: () {
        final quest = Get.arguments;
        return QuestDetailPage(quest: quest);
      },
    ),
    GetPage(
      name: AppRoutes.USER_PROFILE,
      page: () {
        final userId = Get.arguments as String;
        return UserProfilePage(userId: userId);
      },
    ),
    GetPage(
      name: AppRoutes.USER_GUILD_POSTS,
      page: () {
        final arguments = Get.arguments;
        if (arguments is Map) {
          return UserGuildPostsPage(
            userId: arguments['userId']?.toString() ?? '',
            title: arguments['title']?.toString(),
          );
        }

        return UserGuildPostsPage(userId: arguments?.toString() ?? '');
      },
    ),
    GetPage(name: AppRoutes.FOREST, page: () => const ForestPage()),
    GetPage(name: AppRoutes.GOAL_HISTORY, page: () => const GoalHistoryPage()),
    GetPage(
      name: AppRoutes.PRIVACY_SECURITY,
      page: () => const PrivacySecurityPage(),
    ),
    GetPage(name: AppRoutes.HELP_SUPPORT, page: () => const HelpSupportPage()),
    GetPage(
      name: AppRoutes.GROWTH_LETTER,
      page: () => const GrowthLetterPage(),
    ),
  ];
}
