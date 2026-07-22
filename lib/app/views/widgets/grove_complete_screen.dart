import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';

class GroveCompleteScreen extends StatelessWidget {
  final int completedGroveIndex;
  final int treeCount;
  final int totalQuestXp;
  final VoidCallback onExploreNextGrove;

  const GroveCompleteScreen({
    super.key,
    required this.completedGroveIndex,
    required this.treeCount,
    required this.totalQuestXp,
    required this.onExploreNextGrove,
  });

  static Future<void> show({
    required BuildContext context,
    required int completedGroveIndex,
    required int treeCount,
    required int totalQuestXp,
    required VoidCallback onExploreNextGrove,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Grove complete',
      pageBuilder: (_, __, ___) => GroveCompleteScreen(
        completedGroveIndex: completedGroveIndex,
        treeCount: treeCount,
        totalQuestXp: totalQuestXp,
        onExploreNextGrove: onExploreNextGrove,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.background,
        systemNavigationBarColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Semantics(
                label: 'Grove $completedGroveIndex complete',
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.softShadow,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.park_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'GROVE COMPLETE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: AppFonts.label,
                          letterSpacing: 1,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Grove $completedGroveIndex is thriving',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: AppFonts.titleLg,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You have filled every place in this grove. Your next tree will begin a new chapter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFonts.bodyLg,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _stat('$treeCount', 'Trees planted')),
                          Container(
                            width: 1,
                            height: 38,
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: _stat('$totalQuestXp', 'Quest XP grown'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onExploreNextGrove,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            'EXPLORE GROVE ${completedGroveIndex + 1}',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.valueLg,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppFonts.micro,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
