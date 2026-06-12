import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../models/user_model.dart';

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
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
            .collection('users')
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
          final userModel = UserModel.fromJson(data, userId);

          final totalXP = data['totalXP'] ??
              (((data['level'] ?? 1) - 1) * 1000 + (data['currentXp'] ?? 0));
          final level = (totalXP ~/ 1000) + 1;
          final xp = totalXP % 1000;

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('guild_posts')
                .where('userId', isEqualTo: userId)
                .get(),
            builder: (context, postSnap) {
              final guildPostCount = (postSnap.hasData && postSnap.data != null)
                  ? postSnap.data!.docs.length
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.primaryLight,
                        child: userModel.avatarSvg.isNotEmpty
                            ? ClipOval(
                                child: SvgPicture.string(
                                  userModel.avatarSvg,
                                  width: 108,
                                  height: 108,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.person_rounded,
                                size: 54, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nickname
                    Text(
                      userModel.nickname,
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

                    // Stats
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
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
                                  value: "${1000 - xp} XP",
                                  label: "Next Level",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.forum_rounded,
                                  iconColor: const Color(0xFF6C63FF),
                                  bgColor: const Color(0xFF6C63FF).withOpacity(0.1),
                                  value: guildPostCount.toString(),
                                  label: "Guild Posts",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

// ── Reusable stat tile (same style as ProfilePage) ──
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
        ],
      ),
    );
  }
}
