import 'package:flutter/material.dart';
import '../constants/asset_constants.dart';
import '../constants/color_constants.dart';
import '../constants/font_constants.dart';
import 'video_loader.dart';

/// A full-screen white loading overlay with a looping video and "Loading..." text.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(child: SizedBox.shrink()),
          const VideoLoader(size: 300, videoAsset: AppAssets.foxRunVideo),
          const SizedBox(height: 24),
          const Text(
            'Loading...',
            style: TextStyle(
              fontSize: AppFonts.body,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
