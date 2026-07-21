import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/guild_controller.dart';
import '../services/push_notification_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.putAsync(() => PushNotificationService().init(), permanent: true);
    Get.put(AuthController(), permanent: true);
    Get.put(GuildController(), permanent: true);
  }
}
