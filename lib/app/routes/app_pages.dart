import 'package:get/get.dart';
import 'app_routes.dart';

// Imports for your screens and bindings
import '../views/pages/welcome_page.dart';
import '../views/pages/login_page.dart';
import '../views/pages/onboarding/onboarding_view.dart';
import '../views/pages/home_page.dart';
import '../views/pages/dashboard_page.dart';
import '../views/pages/quest_detail_page.dart';
import '../views/pages/user_profile_page.dart';
import '../bindings/onboarding_binding.dart';

class AppPages {
  // 1. The first page users see
  static const INITIAL = AppRoutes.WELCOME;

  // 2. The list of all pages
  static final routes = [
    GetPage(
      name: AppRoutes.WELCOME,
      page: () => const WelcomePage(),
      transition: Transition.fadeIn, // Nice fade effect for entry
    ),
    GetPage(
      name: AppRoutes.LOGIN,
      page: () => const LoginPage(),
      // We can pass arguments here if needed
    ),
    GetPage(
      name: AppRoutes.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.DASHBOARD,
      page: () => const DashboardPage(),
    ),
    GetPage(
      name: AppRoutes.HOME,
      page: () => const HomePage(),
    ),
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
  ];
}