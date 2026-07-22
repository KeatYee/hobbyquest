import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/controllers/home_controller.dart';
import '../constants/color_constants.dart';
import '../constants/font_constants.dart';
import '../constants/asset_constants.dart';
import '../utils/dialog_utils.dart';
import 'video_loader.dart';

/// A full-screen celebration overlay shown when the user completes
/// all quests in the current milestone. On "Continue", it generates
/// the next milestone's quests (replacing the old ones) and returns.
class MilestoneCompleteScreen extends StatefulWidget {
  const MilestoneCompleteScreen({super.key});

  @override
  State<MilestoneCompleteScreen> createState() =>
      _MilestoneCompleteScreenState();
}

class _MilestoneCompleteScreenState extends State<MilestoneCompleteScreen> {
  final HomeController _homeCtrl = Get.find<HomeController>();
  bool _isAdvancing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Container(
              color: AppColors.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  const VideoLoader(
                    size: 300,
                    videoAsset: AppAssets.foxKeepGoingVideo,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Milestone Complete!',
                    style: TextStyle(
                      fontSize: AppFonts.titleLg,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: _isAdvancing ? null : _onContinue,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isAdvancing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Text(
                            'Go to Next Milestone',
                            style: TextStyle(
                              fontSize: AppFonts.button,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    setState(() => _isAdvancing = true);
    try {
      final advanced = await _homeCtrl.advanceToNextMilestone();
      if (!advanced) {
        throw StateError('The next milestone is not ready yet.');
      }
      if (!mounted) return;
      setState(() => _isAdvancing = false);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAdvancing = false);
      AppDialogs.error(
        'Could not continue',
        'Your progress is safe. Please try again.',
      );
    }
  }
}
