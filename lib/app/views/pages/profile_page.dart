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

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: currentUser == null
          ? Center(
              child: Text("Not logged in", style: TextStyle(color: AppColors.textSecondary)),
            )
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("No profile data found"));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final userModel = UserModel.fromJson(data, currentUser.uid);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar and avatar name only
                      Center(
                        child: Column(
                          children: [
                            _buildAvatar(userModel.avatarSvg),
                            const SizedBox(height: 16),
                            Text(
                              userModel.nickname,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // User Stats Section
                      _buildStatsSection(),
                      const SizedBox(height: 40),

                      // Account Settings Section
                      _buildAccountSettingsSection(currentUser, userModel),
                      const SizedBox(height: 40),

                      // General Settings Section
                      _buildSettingsSection(),
                      const SizedBox(height: 40),

                      // Logout Button
                      _buildLogoutButton(context),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAvatar(String avatarSvg) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.primaryLight,
        child: avatarSvg.isNotEmpty
            ? ClipOval(
                child: SvgPicture.string(
                  avatarSvg,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text("No profile data found");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final totalXP = data['totalXP'] ?? (((data['level'] ?? 1) - 1) * 1000 + (data['currentXp'] ?? 0));
        final level = (totalXP ~/ 1000) + 1;
        final xp = totalXP % 1000;
        final xpToNextLevel = 1000 - xp;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "QUEST STATS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("Level", level.toString(), Icons.stars_rounded, AppColors.primary),
                  _buildStatItem("Total XP", totalXP.toString(), Icons.flash_on_rounded, Colors.amber),
                  _buildStatItem("Next Level", xpToNextLevel.toString(), Icons.rocket_launch_rounded, Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "SETTINGS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.notifications_outlined,
          title: "Notifications",
          subtitle: "Manage your alerts",
          onTap: () => Get.snackbar("Coming Soon", "Notification settings coming soon!"),
        ),
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: "Privacy & Security",
          subtitle: "Control your data",
          onTap: () => Get.snackbar("Coming Soon", "Privacy settings coming soon!"),
        ),
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: "Help & Support",
          subtitle: "Get help with HobbyQuest",
          onTap: () => Get.snackbar("Coming Soon", "Support coming soon!"),
        ),
      ],
    );
  }

  Widget _buildAccountSettingsSection(User currentUser, UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ACCOUNT SETTINGS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.email_outlined,
          title: "Email",
          subtitle: currentUser.email ?? "No email",
          onTap: () {},
        ),
        _buildSettingsTile(
          icon: Icons.badge_outlined,
          title: "Avatar Name",
          subtitle: userModel.nickname,
          onTap: () {},
        ),
        _buildSettingsTile(
          icon: Icons.calendar_today_outlined,
          title: "Birth Date",
          subtitle: userModel.birthDate.isNotEmpty ? userModel.birthDate : "Not set",
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout_rounded),
        label: const Text("LOGOUT"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // Close dialog first
              await _performLogout();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading
      Get.dialog(
        Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Logging out..."),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Sign out from Google Sign-In
      await GoogleSignIn.instance.signOut();
      print("--- GOOGLE SIGN-OUT SUCCESS ---");

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      print("--- FIREBASE SIGN-OUT SUCCESS ---");

      // Close loading dialog
      Get.back();

      // Show success message
      Get.snackbar(
        "Logged Out",
        "See you next time, adventurer!",
        backgroundColor: AppColors.accent,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Navigate to Welcome page
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed(AppRoutes.WELCOME);
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      print("--- LOGOUT ERROR: $e ---");
      Get.snackbar(
        "Logout Failed",
        "Error: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
