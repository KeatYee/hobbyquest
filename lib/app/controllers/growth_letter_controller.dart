import 'dart:async';

import 'package:get/get.dart';

import 'home_controller.dart';
import '../models/growth_letter_model.dart';
import '../models/user_model.dart';
import '../services/growth_letter_service.dart';

class GrowthLetterController extends GetxController {
  GrowthLetterController({required this.user});

  final UserModel user;
  final GrowthLetterService _service = GrowthLetterService();

  final isLoading = true.obs;
  final letter = Rxn<GrowthLetterModel>();
  final loadError = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadOrWriteLetter();
  }

  Future<void> loadOrWriteLetter() async {
    try {
      isLoading.value = true;
      loadError.value = null;
      final loadedLetter = await _service.generateWeeklyGrowthLetter(
        user: user,
      );
      letter.value = loadedLetter;
      await _markCurrentLetterRead(loadedLetter);
    } catch (e) {
      letter.value = null;
      loadError.value =
          'We could not load your Growth Letter. Check your connection and try again.';
      Get.log('Failed to load Growth Letter: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _markCurrentLetterRead(GrowthLetterModel? currentLetter) async {
    if (currentLetter == null ||
        currentLetter.id.isEmpty ||
        currentLetter.id == 'demo' ||
        currentLetter.readAt != null) {
      _syncDashboardUnread(null);
      return;
    }

    try {
      await _service.markGrowthLetterRead(
        uid: currentLetter.uid,
        letterId: currentLetter.id,
      );
      _syncDashboardUnread(null);
    } catch (e) {
      print('--- WARNING: Failed to mark growth letter read: $e ---');
      _syncDashboardUnread(currentLetter);
    }
  }

  void _syncDashboardUnread(GrowthLetterModel? unreadLetter) {
    if (!Get.isRegistered<HomeController>()) return;
    final homeController = Get.find<HomeController>();
    homeController.hasAvailableGrowthLetter.value =
        unreadLetter != null &&
        unreadLetter.id != 'demo' &&
        unreadLetter.readAt == null;
    unawaited(homeController.refreshGrowthLetterAvailability());
  }
}
