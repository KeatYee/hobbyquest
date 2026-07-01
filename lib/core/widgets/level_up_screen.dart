import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'video_loader.dart';
import '../constants/color_constants.dart';
import '../constants/font_constants.dart';

/// A full-screen level-up celebration overlay with a jumping fox video.
class LevelUpScreen extends StatefulWidget {
  final int newLevel;

  const LevelUpScreen({super.key, required this.newLevel});

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  late final ConfettiController _ctrTL; // top-left
  late final ConfettiController _ctrTR; // top-right
  late final ConfettiController _ctrBL; // bottom-left
  late final ConfettiController _ctrBR; // bottom-right

  @override
  void initState() {
    super.initState();
    _ctrTL = ConfettiController(duration: const Duration(seconds: 2));
    _ctrTR = ConfettiController(duration: const Duration(seconds: 2));
    _ctrBL = ConfettiController(duration: const Duration(seconds: 2));
    _ctrBR = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _ctrTL.dispose();
    _ctrTR.dispose();
    _ctrBL.dispose();
    _ctrBR.dispose();
    super.dispose();
  }

  void _onContinue() {
    _ctrTL.play();
    _ctrTR.play();
    _ctrBL.play();
    _ctrBR.play();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  static const _confettiColors = [
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.orange,
    Colors.purple,
  ];

  Widget _buildConfetti(Alignment alignment, ConfettiController controller) {
    return Align(
      alignment: alignment,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        colors: _confettiColors,
        numberOfParticles: 20,
        gravity: 0.15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Expanded(child: SizedBox.shrink()),
            const VideoLoader(
              size: 300,
              videoAsset: 'assets/videos/fox_jump.mp4',
            ),
            const SizedBox(height: 24),
            Text(
              'Level Up!',
              style: TextStyle(
                fontSize: AppFonts.titlePage,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You reached Level ${widget.newLevel}',
              style: const TextStyle(
                fontSize: AppFonts.body,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: _onContinue,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: AppFonts.button, fontWeight: FontWeight.w700),
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        // Four corners confetti
        _buildConfetti(Alignment.topLeft, _ctrTL),
        _buildConfetti(Alignment.topRight, _ctrTR),
        _buildConfetti(Alignment.bottomLeft, _ctrBL),
        _buildConfetti(Alignment.bottomRight, _ctrBR),
      ],
    ),
  );
  }
}
