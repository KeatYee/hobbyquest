import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'HELP & SUPPORT',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ContactCard(email: AppInfo.supportEmail),
            SizedBox(height: 12),
            _VersionCard(),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String email;

  const _ContactCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      icon: Icons.email_outlined,
      iconColor: AppColors.primary,
      title: 'Contact Us',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please contact us through this email for feedback, bugs, or support questions.',
            style: TextStyle(
              fontSize: AppFonts.caption,
              height: 1.4,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alternate_email_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    email,
                    style: const TextStyle(
                      fontSize: AppFonts.bodyLg,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.info,
      title: 'App Version',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  AppInfo.appName,
                  style: TextStyle(
                    fontSize: AppFonts.bodyLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppInfo.versionLabel,
                  style: TextStyle(
                    fontSize: AppFonts.caption,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              AppInfo.displayVersion,
              style: TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.badge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SupportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppFonts.body,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
