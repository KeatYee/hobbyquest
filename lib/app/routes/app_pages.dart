import 'package:get/get.dart';
import 'app_routes.dart';

// Imports for your screens and bindings
import '../views/pages/welcome_page.dart';
import '../views/pages/login_page.dart';
import '../views/pages/onboarding/onboarding_view.dart';
// import '../views/pages/home_page.dart'; // Uncomment when you create Home

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
      // We will add OnboardingBinding() here later!
    ),
    // GetPage(name: AppRoutes.HOME, page: () => const HomePage()),
  ];
}