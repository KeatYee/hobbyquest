import 'package:get/get.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    // Inject OnboardingController when entering the onboarding route
    // permanent: false means it will be disposed when leaving the route
    Get.put(OnboardingController());
  }
}
