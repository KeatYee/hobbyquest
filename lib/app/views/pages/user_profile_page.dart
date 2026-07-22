import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../routes/app_routes.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "USER PROFILE",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.caption,
            letterSpacing: 2.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('publicProfiles')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwnProfile = currentUid == userId;
          final profileVisible = data['profileVisible'] as bool? ?? true;
          final postStatsVisible = data['postStatsVisible'] as bool? ?? true;
          final nickname = data['nickname']?.toString().trim() ?? 'Hero';
          final avatarSvg = data['avatarSvg']?.toString().trim() ?? '';
          final canViewProfile = isOwnProfile || profileVisible;
          final canViewStats = isOwnProfile || postStatsVisible;

          if (!canViewProfile) {
            return const _PrivateProfileState();
          }

          final totalXP =
              data['totalXP'] ??
              (((data['level'] ?? 1) - 1) * 1000 + (data['currentXp'] ?? 0));
          final level = (totalXP ~/ 1000) + 1;
          final xp = totalXP % 1000;

          return FutureBuilder<QuerySnapshot?>(
            future: canViewStats
                ? FirebaseFirestore.instance
                      .collection('guild_posts')
                      .where('userId', isEqualTo: userId)
                      .get()
                : Future<QuerySnapshot?>.value(null),
            builder: (context, postSnap) {
              final guildPostCount =
                  (canViewStats && postSnap.hasData && postSnap.data != null)
                  ? postSnap.data!.docs.length
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.primaryLight,
                        child: avatarSvg.isNotEmpty
                            ? ClipOval(
                                child: Image.asset(
                                  avatarSvg,
                                  width: 108,
                                  height: 108,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 54,
                                color: AppColors.primary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      nickname,
                      style: TextStyle(
                        fontSize: AppFonts.titlePage,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userId,
                      style: TextStyle(
                        fontSize: AppFonts.badge,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 36),

                    if (canViewStats)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.04,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
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
                                    bgColor: AppColors.warning.withOpacity(
                                      0.12,
                                    ),
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
                                    value: "${1000 - xp} XP",
                                    label: "Next Level",
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.forum_rounded,
                                    iconColor: AppColors.info,
                                    bgColor: AppColors.info.withValues(
                                      alpha: 0.1,
                                    ),
                                    value: guildPostCount.toString(),
                                    label: "Guild Posts",
                                    onTap: () => Get.toNamed(
                                      AppRoutes.USER_GUILD_POSTS,
                                      arguments: {
                                        'userId': userId,
                                        'title': '$nickname Posts',
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      const _StatsHiddenCard(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PrivateProfileState extends StatelessWidget {
  const _PrivateProfileState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Private profile",
              style: TextStyle(
                fontSize: AppFonts.title,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This adventurer has hidden their profile.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFonts.caption,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHiddenCard extends StatelessWidget {
  const _StatsHiddenCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Post stats are hidden by this user.",
              style: TextStyle(
                fontSize: AppFonts.caption,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
