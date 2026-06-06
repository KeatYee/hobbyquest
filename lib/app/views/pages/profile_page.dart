import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/color_constants.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // ───────────────────────────────────────────
  //  Root scaffold
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: currentUser == null
          ? Center(
              child: Text(
                "Not logged in",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("No profile data found"));
                }

                final data      = snapshot.data!.data() as Map<String, dynamic>;
                final userModel = UserModel.fromJson(data, currentUser.uid);

                // Derive XP data right here so hero + stats share one fetch
                final totalXP = data['totalXP'] ??
                    (((data['level'] ?? 1) - 1) * 1000 + (data['currentXp'] ?? 0));
                final level = (totalXP ~/ 1000) + 1;
                final xp    = totalXP % 1000;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Hero ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _HeroHeader(
                        currentUser: currentUser,
                        userModel: userModel,
                        level: level,
                        xp: xp,
                        totalXP: totalXP,
                      ),
                    ),
                    // ── Body ──────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStatsSection(level, totalXP, xp),
                          const SizedBox(height: 24),
                          _buildAccountSection(currentUser, userModel),
                          const SizedBox(height: 24),
                          _buildGeneralSection(),
                          const SizedBox(height: 28),
                          _buildLogoutButton(context),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ───────────────────────────────────────────
  //  Stats section
  // ───────────────────────────────────────────
  Widget _buildStatsSection(int level, int totalXP, int xp) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<QuerySnapshot>(
      future: uid != null
          ? FirebaseFirestore.instance
              .collection('guild_posts')
              .where('userId', isEqualTo: uid)
              .get()
          : Future.value(null as QuerySnapshot),
      builder: (context, postSnap) {
        final guildPostCount = (postSnap.hasData && postSnap.data != null)
            ? postSnap.data!.docs.length
            : 0;
        final xpToNext = 1000 - xp;

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
                        value: "LVL $level",
                        label: "Rank",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.flash_on_rounded,
                        iconColor: AppColors.warning,
                        bgColor: AppColors.warning.withOpacity(0.12),
                        value: totalXP.toString(),
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
                        icon: Icons.rocket_launch_rounded,
                        iconColor: AppColors.error,
                        bgColor: AppColors.error.withOpacity(0.08),
                        value: "$xpToNext XP",
                        label: "Next Level",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.forum_rounded,
                        iconColor: AppColors.info,
                        bgColor: AppColors.info.withOpacity(0.1),
                        value: guildPostCount.toString(),
                        label: "Guild Posts",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────
  //  Account section
  // ───────────────────────────────────────────
  Widget _buildAccountSection(User currentUser, UserModel userModel) {
    return _SectionCard(
      label: "ACCOUNT",
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.email_outlined,
            iconColor: AppColors.primary,
            title: "Email",
            subtitle: currentUser.email ?? "No email",
            onTap: () {},
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.badge_outlined,
            iconColor: AppColors.secondary,
            title: "Avatar Name",
            subtitle: userModel.nickname,
            onTap: () {},
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.success,
            title: "Birth Date",
            subtitle: userModel.birthDate.isNotEmpty
                ? userModel.birthDate
                : "Not set",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  //  General settings section
  // ───────────────────────────────────────────
  Widget _buildGeneralSection() {
    return _SectionCard(
      label: "SETTINGS",
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.warning,
            title: "Notifications",
            subtitle: "Manage your alerts",
            onTap: () => Get.snackbar("Coming Soon", "Notification settings coming soon!"),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.info,
            title: "Privacy & Security",
            subtitle: "Control your data",
            onTap: () => Get.snackbar("Coming Soon", "Privacy settings coming soon!"),
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.help_outline,
            iconColor: AppColors.success,
            title: "Help & Support",
            subtitle: "Get help with HobbyQuest",
            onTap: () => Get.snackbar("Coming Soon", "Support coming soon!"),
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
            fontSize: 15,
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
  //  Backend — UNCHANGED
  // ───────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _performLogout();
            },
            child: Text(
              "Logout",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text("Logging out...", style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      await GoogleSignIn.instance.signOut();
      print("--- GOOGLE SIGN-OUT SUCCESS ---");

      await FirebaseAuth.instance.signOut();
      print("--- FIREBASE SIGN-OUT SUCCESS ---");

      Get.back();

      Get.snackbar(
        "Logged Out",
        "See you next time, adventurer!",
        backgroundColor: AppColors.accent,
        colorText: AppColors.textOnPrimary,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed(AppRoutes.WELCOME);
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      print("--- LOGOUT ERROR: $e ---");
      Get.snackbar(
        "Logout Failed",
        "Error: $e",
        backgroundColor: AppColors.error,
        colorText: AppColors.textOnPrimary,
      );
    }
  }
}

// ═══════════════════════════════════════════════
//  Hero header widget
// ═══════════════════════════════════════════════
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
                          fontSize: 13,
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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textOnPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
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
                child: SvgPicture.string(
                  avatarSvg,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
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
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$xp / 1000 XP",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                "${1000 - xp} to next level",
                style: const TextStyle(
                  fontSize: 11,
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

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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
            style: const TextStyle(
              fontSize: 11,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
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