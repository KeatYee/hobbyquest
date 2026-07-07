import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../models/user_model.dart';
import '../../controllers/profile_controller.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../routes/app_routes.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // ───────────────────────────────────────────
  //  Root scaffold
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || controller.userModel.value == null) {
          return Center(
            child: Text(
              "No profile data found",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final userModel = controller.userModel.value!;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                currentUser: currentUser,
                userModel: userModel,
                level: controller.level,
                xp: controller.xp,
                totalXP: controller.totalXP,
              ),
            ),
            // ── Body ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildAccountSection(context, currentUser, userModel),
                  const SizedBox(height: 24),
                  _buildGeneralSection(context),
                  const SizedBox(height: 28),
                  _buildLogoutButton(context),
                  const SizedBox(height: 12),
                  _buildDeleteAccountButton(context),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────────────────────────────────────────
  //  Stats section
  // ───────────────────────────────────────────
  Widget _buildStatsSection() {
    final ctrl = Get.find<ProfileController>();

    return _SectionCard(
      label: "ADVENTURE STATS",
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.stars_rounded,
                    iconColor: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                    value: "LVL ${ctrl.level}",
                    label: "Rank",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.flash_on_rounded,
                    iconColor: AppColors.warning,
                    bgColor: AppColors.warning.withOpacity(0.12),
                    value: ctrl.totalXP.toString(),
                    label: "Total XP",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: AppColors.warning,
                    bgColor: AppColors.warning.withOpacity(0.12),
                    value: "${ctrl.streak} day${ctrl.streak == 1 ? '' : 's'}",
                    label: "Streak",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                    () => _StatTile(
                      icon: Icons.forum_rounded,
                      iconColor: AppColors.info,
                      bgColor: AppColors.info.withOpacity(0.1),
                      value: ctrl.guildPostCount.toString(),
                      label: "Guild Posts",
                      onTap: () => Get.toNamed(
                        AppRoutes.USER_GUILD_POSTS,
                        arguments: {
                          'userId': ctrl.uid,
                          'title': 'My Guild Posts',
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Account section
  // ───────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context, User currentUser, UserModel userModel) {
    return _SectionCard(
      label: "ACCOUNT",
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.email_outlined,
            iconColor: AppColors.primary,
            title: "Email",
            subtitle: currentUser.email ?? "No email",
            onTap: () => _showEditEmailDialog(context),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.badge_outlined,
            iconColor: AppColors.secondary,
            title: "Avatar Name",
            subtitle: userModel.nickname,
            onTap: () => _showEditNameDialog(context),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.success,
            title: "Birth Date",
            subtitle: userModel.birthDate.isNotEmpty
                ? userModel.birthDate
                : "Not set",
            onTap: () => _showEditBirthDateDialog(context),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  //  General settings section
  // ───────────────────────────────────────────
  Widget _buildGeneralSection(BuildContext context) {
    final ctrl = Get.find<ProfileController>();

    return _SectionCard(
      label: "SETTINGS",
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: AppColors.info,
            title: "Goal History",
            subtitle: "View your past goals",
            onTap: () => Get.toNamed(AppRoutes.GOAL_HISTORY),
          ),
          const _TileDivider(),
          Obx(
            () => _NotificationSettingsTile(
              isEnabled: ctrl.notificationsEnabled.value,
              isUpdating: ctrl.isUpdatingNotifications.value,
              onChanged: ctrl.updateNotificationsEnabled,
            ),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.info,
            title: "Privacy & Security",
            subtitle: "Visibility and policy",
            onTap: () => Get.toNamed(AppRoutes.PRIVACY_SECURITY),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.help_outline,
            iconColor: AppColors.success,
            title: "Help & Support",
            subtitle: "Get help with HobbyQuest",
            onTap: () => AppDialogs.info('Coming Soon', 'Support coming soon!'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Logout button
  // ───────────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
        label: Text(
          "Log Out",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AppFonts.button,
            letterSpacing: 0.3,
            color: AppColors.error,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.35), width: 1.5),
          backgroundColor: AppColors.error.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Delete account button
  // ───────────────────────────────────────────
  Widget _buildDeleteAccountButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => _handleDeleteAccount(context),
        icon: Icon(Icons.delete_forever_rounded, size: 20, color: AppColors.error),
        label: Text(
          "Delete Account",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AppFonts.button,
            letterSpacing: 0.3,
            color: AppColors.error.withOpacity(0.7),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.18), width: 1),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Backend
  // ───────────────────────────────────────────
  void _handleDeleteAccount(BuildContext context) async {
    final confirmed = await AppDialogs.dangerConfirm(
      title: 'Delete Account',
      message: 'This will permanently delete your account and all data. '
          'This action cannot be undone.',
      confirmText: 'DELETE',
      confirmLabel: 'Delete',
    );
    if (confirmed == true) Get.find<ProfileController>().deleteAccount();
  }
  // ───────────────────────────────────────────
  //  Backend
  // ───────────────────────────────────────────
  void _handleLogout(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      confirmColor: AppColors.error,
    );
    if (confirmed == true) Get.find<ProfileController>().logout();
  }
}

// ═══════════════════════════════════════════════
//  Edit Dialogs
// ═══════════════════════════════════════════════
extension _EditDialogs on ProfilePage {
  void _showEditNameDialog(BuildContext context) async {
    final result = await AppDialogs.input(
      title: 'Edit Avatar Name',
      initialValue: Get.find<ProfileController>().nickname,
      hintText: 'Enter your display name',
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
        if (value.trim().length < 2) return 'Name must be at least 2 characters';
        if (value.trim().length > 50) return 'Name must be 50 characters or less';
        return null;
      },
    );
    if (result != null && result.isNotEmpty) {
      await Get.find<ProfileController>().updateNickname(result);
    }
  }

  void _showEditEmailDialog(BuildContext context) async {
    final result = await AppDialogs.input(
      title: 'Change Email',
      initialValue: Get.find<ProfileController>().email,
      hintText: 'Enter new email address',
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Email cannot be empty';
        final trimmed = value.trim();
        if (!trimmed.contains('@') || !trimmed.contains('.')) return 'Enter a valid email address';
        if (trimmed.indexOf('@') == 0) return 'Email must have a username before @';
        if (trimmed.lastIndexOf('.') < trimmed.indexOf('@')) return 'Email must have a domain after @';
        return null;
      },
    );
    if (result != null && result.isNotEmpty) {
      await Get.find<ProfileController>().changeEmail(result);
    }
  }

  void _showEditBirthDateDialog(BuildContext context) async {
    final controller = Get.find<ProfileController>();
    final result = await AppDialogs.datePicker(
      title: 'Edit Birth Date',
      initialValue: controller.birthDate,
    );
    if (result != null && result.isNotEmpty) {
      await controller.updateBirthDate(result);
    }
  }
}
class _HeroHeader extends StatelessWidget {
  final User currentUser;
  final UserModel userModel;
  final int level;
  final int xp;
  final int totalXP;

  const _HeroHeader({
    required this.currentUser,
    required this.userModel,
    required this.level,
    required this.xp,
    required this.totalXP,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = xp / 1000.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Gradient background ─────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // App-bar row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textOnPrimary,
                          size: 20,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        "PROFILE",
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: AppFonts.caption,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(width: 48), // visual balance
                    ],
                  ),
                ),

                // Avatar + name area with decorative circles
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: 28,
                        top: 8,
                        child: _Circle(size: 90, opacity: 0.08),
                      ),
                      Positioned(
                        left: 18,
                        bottom: 16,
                        child: _Circle(size: 56, opacity: 0.06),
                      ),
                      Positioned(
                        left: 90,
                        top: 6,
                        child: _Circle(size: 30, opacity: 0.05),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatar(userModel.avatarSvg),
                          const SizedBox(height: 12),
                          Text(
                            userModel.nickname,
                            style: TextStyle(
                              fontSize: AppFonts.valueLg,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textOnPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser.email ?? '',
                            style: TextStyle(
                              fontSize: AppFonts.badge,
                              color: AppColors.textOnPrimary.withOpacity(0.72),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── XP card — floats over the hero/body seam ─
        Positioned(
          left: 20,
          right: 20,
          bottom: -52,
          child: _XPCard(level: level, xp: xp, progress: progress),
        ),

        // Spacer so scroll body starts below the floating card
        const SizedBox(height: 52),
      ],
    );
  }

  Widget _buildAvatar(String avatarSvg) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textOnPrimary, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.textShadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 46,
        backgroundColor: AppColors.textOnPrimary.withOpacity(0.2),
        child: avatarSvg.isNotEmpty
            ? ClipOval(
                child: Image.asset(
                  avatarSvg,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                size: 46,
                color: AppColors.textOnPrimary,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  XP Progress card
// ═══════════════════════════════════════════════
class _XPCard extends StatelessWidget {
  final int level;
  final int xp;
  final double progress;

  const _XPCard({
    required this.level,
    required this.xp,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.textShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Level badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "LVL  $level",
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: AppFonts.badge,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$xp / 1000 XP",
                    style: TextStyle(
                      fontSize: AppFonts.caption,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                "${1000 - xp} to next level",
                style: TextStyle(
                  fontSize: AppFonts.micro,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress track
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 8,
                  width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Stat tile
// ═══════════════════════════════════════════════
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: AppFonts.button,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.micro,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: content,
        ),
      ),
    );
}

}

// ═══════════════════════════════════════════════
//  Section card wrapper
// ═══════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _SectionCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFonts.micro,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.textShadow,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  Settings tile
// ═══════════════════════════════════════════════
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppFonts.bodyLg,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppFonts.badge,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════
class _NotificationSettingsTile extends StatelessWidget {
  final bool isEnabled;
  final bool isUpdating;
  final Future<bool> Function(bool enabled) onChanged;

  const _NotificationSettingsTile({
    required this.isEnabled,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isEnabled ? AppColors.warning : AppColors.textSecondary;

    return InkWell(
      onTap: isUpdating ? null : () => onChanged(!isEnabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppFonts.bodyLg,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEnabled
                        ? "Guild alerts are enabled"
                        : "Guild alerts are disabled",
                    style: TextStyle(
                      fontSize: AppFonts.badge,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isUpdating)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              )
            else
              Switch.adaptive(
                value: isEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: onChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 70,
      endIndent: 0,
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textOnPrimary.withOpacity(opacity),
      ),
    );
  }
}
