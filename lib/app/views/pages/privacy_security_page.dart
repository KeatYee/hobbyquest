import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../controllers/profile_controller.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ProfileController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "PRIVACY & SECURITY",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.caption,
            letterSpacing: 2.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacySwitchTile(
                icon: Icons.person_search_outlined,
                iconColor: AppColors.info,
                title: "Profile visibility",
                subtitle: ctrl.profileVisible.value
                    ? "Other users can view your profile"
                    : "Your profile is hidden from other users",
                value: ctrl.profileVisible.value,
                isUpdating: ctrl.isUpdatingPrivacy.value,
                onChanged: ctrl.updateProfileVisibility,
              ),
              const SizedBox(height: 12),
              _PrivacySwitchTile(
                icon: Icons.query_stats_rounded,
                iconColor: AppColors.warning,
                title: "Post stats visibility",
                subtitle: ctrl.postStatsVisible.value
                    ? "Post reactions and reviews are visible"
                    : "Post reactions and reviews are hidden",
                value: ctrl.postStatsVisible.value,
                isUpdating: ctrl.isUpdatingPrivacy.value,
                onChanged: ctrl.updatePostStatsVisibility,
              ),
              const SizedBox(height: 12),
              _PrivacyActionTile(
                icon: Icons.policy_outlined,
                iconColor: AppColors.success,
                title: "Privacy Policy",
                subtitle: "How HobbyQuest uses your data",
                onTap: () => _showPrivacyPolicyDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPrivacyPolicyDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Privacy Policy",
                      style: TextStyle(
                        fontSize: AppFonts.title,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Text(
                    "HobbyQuest stores your account profile, quest progress, guild posts, reactions, reviews, notification preference, and privacy settings so the app can run your learning journey.\n\nYour profile visibility setting controls whether other users can view your public profile. Your post stats visibility setting controls whether other users can see reaction and review stats on your guild posts.\n\nWe use Firebase services for authentication, database storage, cloud functions, and push notifications. We do not sell your personal data.\n\nYou can update these privacy settings anytime from this screen. You can also delete your account from the profile page, which removes your account data handled by the app.",
                    style: TextStyle(
                      fontSize: AppFonts.badge,
                      height: 1.45,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}


class _PrivacySwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool isUpdating;
  final Future<bool> Function(bool enabled) onChanged;

  const _PrivacySwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppFonts.body,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: AppFonts.badge,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isUpdating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.primary,
                ),
        ],
      ),
    );
  }
}

class _PrivacyActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrivacyActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppFonts.body,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppFonts.badge,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
