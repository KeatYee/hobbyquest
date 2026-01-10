import 'package:get/get.dart';
import '../controllers/auth_controller.dart'; // Make sure this path is correct!

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Inject AuthController immediately
    // permanent: true ensures it stays in memory throughout the entire app lifecycle
    Get.put(AuthController(), permanent: true);
  }
}