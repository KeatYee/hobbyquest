import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/controllers/home_controller.dart';
import '../constants/font_constants.dart';
import 'video_loader.dart';

/// A full-screen celebration overlay shown when the user completes
/// all quests in the current milestone. On "Continue", it generates
/// the next milestone's quests (replacing the old ones) and returns.
class MilestoneCompleteScreen extends StatefulWidget {
  const MilestoneCompleteScreen({super.key});

  @override
  State<MilestoneCompleteScreen> createState() => _MilestoneCompleteScreenState();
}

class _MilestoneCompleteScreenState extends State<MilestoneCompleteScreen> {
  final HomeController _homeCtrl = Get.find<HomeController>();
  bool _isAdvancing = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: SizedBox.shrink()),
                const VideoLoader(
                  size: 300,
                  videoAsset: 'assets/videos/fox_keepgoing.mp4',
                ),
                const SizedBox(height: 20),
                Text(
                  'Milestone Complete!',
                  style: TextStyle(
                    fontSize: AppFonts.titleLg,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: _isAdvancing ? null : _onContinue,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
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
                            color: Colors.white,
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
    );
  }

  Future<void> _onContinue() async {
    setState(() => _isAdvancing = true);
    await _homeCtrl.advanceToNextMilestone();
    if (mounted) Navigator.of(context).pop();
  }
}
