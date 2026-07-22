import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../models/guild_post_model.dart';

class UserGuildPostsPage extends StatelessWidget {
  final String userId;
  final String? title;

  const UserGuildPostsPage({super.key, required this.userId, this.title});

  @override
  Widget build(BuildContext context) {
    final pageTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'GUILD POSTS';

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
          pageTitle.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.caption,
            letterSpacing: 2.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<_UserGuildPostsData>(
        future: _loadUserGuildPosts(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load posts',
              subtitle: 'Please try again later.',
            );
          }

          final data = snapshot.data ?? const _UserGuildPostsData.empty();
          if (data.isPrivate) {
            return const _EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Private profile',
              subtitle: 'This adventurer has hidden their guild posts.',
            );
          }

          if (data.posts.isEmpty) {
            return const _EmptyState(
              icon: Icons.forum_outlined,
              title: 'No guild posts yet',
              subtitle: 'Posts shared to the guild will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            physics: const BouncingScrollPhysics(),
            itemCount: data.posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _UserGuildPostCard(
              post: data.posts[index],
              profiles: data.profiles,
            ),
          );
        },
      ),
    );
  }
}

Future<_UserGuildPostsData> _loadUserGuildPosts(String userId) async {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) {
    return const _UserGuildPostsData.empty();
  }

  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  final ownerSnapshot = await FirebaseFirestore.instance
      .collection('publicProfiles')
      .doc(trimmedUserId)
      .get();
  final ownerProfile = _UserSummary.fromFirestore(
    trimmedUserId,
    ownerSnapshot.data(),
  );

  if (currentUid != trimmedUserId && !ownerProfile.profileVisible) {
    return _UserGuildPostsData(
      posts: const [],
      profiles: {trimmedUserId: ownerProfile},
      isPrivate: true,
    );
  }

  final postSnapshot = await FirebaseFirestore.instance
      .collection('guild_posts')
      .where('userId', isEqualTo: trimmedUserId)
      .get();

  final posts =
      postSnapshot.docs
          .map((doc) => GuildPostModel.fromJson(doc.data(), doc.id))
          .where((post) => post.title.trim().isNotEmpty)
          .toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

  final userIds = <String>{};
  for (final post in posts) {
    final authorId = post.userId.trim();
    if (authorId.isNotEmpty) {
      userIds.add(authorId);
    }

    for (final ids in post.reactions.values) {
      userIds.addAll(ids.map((id) => id.trim()).where((id) => id.isNotEmpty));
    }
    userIds.addAll(
      post.peerReviews.keys.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );
  }

  final profiles = <String, _UserSummary>{trimmedUserId: ownerProfile};
  await Future.wait(
    userIds.where((id) => !profiles.containsKey(id)).map((id) async {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('publicProfiles')
            .doc(id)
            .get();
        profiles[id] = _UserSummary.fromFirestore(id, snapshot.data());
      } catch (_) {
        profiles[id] = _UserSummary.fallback(id);
      }
    }),
  );

  return _UserGuildPostsData(posts: posts, profiles: profiles);
}

class _UserGuildPostsData {
  final List<GuildPostModel> posts;
  final Map<String, _UserSummary> profiles;
  final bool isPrivate;

  const _UserGuildPostsData({
    required this.posts,
    required this.profiles,
    this.isPrivate = false,
  });

  const _UserGuildPostsData.empty()
    : posts = const [],
      profiles = const {},
      isPrivate = false;
}

class _UserSummary {
  final String id;
  final String name;
  final String avatarSvg;
  final bool profileVisible;
  final bool postStatsVisible;

  const _UserSummary({
    required this.id,
    required this.name,
    required this.avatarSvg,
    this.profileVisible = true,
    this.postStatsVisible = true,
  });

  factory _UserSummary.fromFirestore(String id, Map<String, dynamic>? data) {
    final nickname = data?['nickname']?.toString().trim() ?? '';
    final displayName = data?['displayName']?.toString().trim() ?? '';
    return _UserSummary(
      id: id,
      name: nickname.isNotEmpty
          ? nickname
          : (displayName.isNotEmpty ? displayName : _shortUserId(id)),
      avatarSvg: data?['avatarSvg']?.toString().trim() ?? '',
      profileVisible: data?['profileVisible'] as bool? ?? true,
      postStatsVisible: data?['postStatsVisible'] as bool? ?? true,
    );
  }

  factory _UserSummary.fallback(String id) {
    return _UserSummary(
      id: id,
      name: _shortUserId(id),
      avatarSvg: '',
      profileVisible: true,
      postStatsVisible: true,
    );
  }
}

class _UserGuildPostCard extends StatelessWidget {
  final GuildPostModel post;
  final Map<String, _UserSummary> profiles;

  const _UserGuildPostCard({required this.post, required this.profiles});

  @override
  Widget build(BuildContext context) {
    final reactionCount = post.reactions.values.fold<int>(
      0,
      (sum, users) => sum + users.length,
    );
    final hasImage = post.imageUrl.trim().isNotEmpty;
    final author = profiles[post.userId] ?? _UserSummary.fallback(post.userId);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final canViewStats = currentUid == author.id || author.postStatsVisible;
    final avatarLabel = author.name.trim().isNotEmpty
        ? author.name.trim().characters.first.toUpperCase()
        : '?';
    final hasAuthorAvatar = author.avatarSvg.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: hasAuthorAvatar
                    ? ClipOval(
                        child: Image.asset(
                          author.avatarSvg,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      )
                    : Text(
                        avatarLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.hobby.trim().isNotEmpty ? post.hobby : 'Guild'} \u2022 ${_formatTime(post.createdAt) ?? 'Guild'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFonts.badge,
                      ),
                    ),
                  ],
                ),
              ),
              if (canViewStats)
                PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'stats') {
                      _showStatsDialog(context, post, profiles);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'stats',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bar_chart,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'View Stats',
                            style: TextStyle(
                              fontSize: AppFonts.caption,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            style: const TextStyle(
              height: 1.4,
              color: AppColors.textSecondary,
              fontSize: AppFonts.bodyLg,
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (canViewStats)
            _GuildMetricsRow(post: post, reactionCount: reactionCount)
          else
            _MetricPill(
              icon: Icons.visibility_off_outlined,
              label: 'Post stats hidden',
            ),
          if (canViewStats && reactionCount > 0) ...[
            const SizedBox(height: 16),
            _SectionLabel(
              icon: Icons.favorite_outline_rounded,
              label: 'Reacted by',
            ),
            const SizedBox(height: 8),
            _ReactionGroups(post: post, profiles: profiles),
          ],
        ],
      ),
    );
  }
}

void _showStatsDialog(
  BuildContext context,
  GuildPostModel post,
  Map<String, _UserSummary> profiles,
) {
  final avg = _averageRatingsFrom(post);
  final reviewerIds = post.peerReviews.keys.toList();

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Peer Review Stats',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppFonts.title,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (avg.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.caption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else ...[
              _ReviewChart(averageRatings: avg),
              const SizedBox(height: 16),
              if (reviewerIds.isNotEmpty) ...[
                const Divider(height: 1),
                const SizedBox(height: 8),
                const Text(
                  'Reviewed by',
                  style: TextStyle(
                    fontSize: AppFonts.caption,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                _ReviewerList(post: post, profiles: profiles),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReactionGroups extends StatelessWidget {
  final GuildPostModel post;
  final Map<String, _UserSummary> profiles;

  const _ReactionGroups({required this.post, required this.profiles});

  @override
  Widget build(BuildContext context) {
    final entries = post.reactions.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        final users = entry.value
            .map((id) => profiles[id] ?? _UserSummary.fallback(id))
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _EmojiBadge(emoji: entry.key),
              ...users.map((user) => _UserChip(user: user)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GuildMetricsRow extends StatelessWidget {
  final GuildPostModel post;
  final int reactionCount;

  const _GuildMetricsRow({required this.post, required this.reactionCount});

  @override
  Widget build(BuildContext context) {
    final reactionEntries = post.reactions.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reactionEntries.isEmpty)
          _MetricPill(
            icon: Icons.favorite_outline_rounded,
            label: '$reactionCount reactions',
          )
        else
          ...reactionEntries.map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary.withOpacity(0.24)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: AppFonts.button),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    entry.value.length.toString(),
                    style: const TextStyle(
                      fontSize: AppFonts.caption,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _MetricPill(
          icon: Icons.rate_review_outlined,
          label: '${post.peerReviews.length} reviews',
        ),
      ],
    );
  }
}

class _ReviewerList extends StatelessWidget {
  final GuildPostModel post;
  final Map<String, _UserSummary> profiles;

  const _ReviewerList({required this.post, required this.profiles});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: post.peerReviews.entries.map((entry) {
        final user = profiles[entry.key] ?? _UserSummary.fallback(entry.key);
        final displayName = user.name.trim().isNotEmpty
            ? user.name.trim()
            : 'Anonymous';
        final hasAvatar = user.avatarSvg.trim().isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: hasAvatar
                  ? ClipOval(
                      child: Image.asset(
                        user.avatarSvg,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    )
                  : Text(
                      displayName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: AppFonts.label,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: AppFonts.caption,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ReviewChart extends StatelessWidget {
  final Map<String, double> averageRatings;

  const _ReviewChart({required this.averageRatings});

  @override
  Widget build(BuildContext context) {
    final axes = averageRatings.keys.take(5).toList();
    if (axes.length < 3) {
      return _ReviewBars(averageRatings: averageRatings);
    }

    return SizedBox(
      height: 280,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          dataSets: [
            RadarDataSet(
              fillColor: Colors.transparent,
              borderColor: AppColors.primary,
              borderWidth: 2.5,
              entryRadius: 3,
              dataEntries: axes
                  .map((axis) => RadarEntry(value: averageRatings[axis] ?? 0))
                  .toList(),
            ),
          ],
          getTitle: (index, _) => RadarChartTitle(text: axes[index], angle: 0),
          titleTextStyle: const TextStyle(
            fontSize: AppFonts.badge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titlePositionPercentageOffset: 0.15,
          borderData: FlBorderData(show: false),
          radarBorderData: BorderSide.none,
          tickBorderData: BorderSide.none,
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 0,
          ),
          gridBorderData: BorderSide.none,
        ),
      ),
    );
  }
}

class _ReviewBars extends StatelessWidget {
  final Map<String, double> averageRatings;

  const _ReviewBars({required this.averageRatings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: averageRatings.entries.map((entry) {
          final value = entry.value.clamp(0.0, 5.0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppFonts.badge,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: value / 5.0,
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: AppFonts.badge,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFonts.caption,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.badge,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  final String emoji;

  const _EmojiBadge({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: AppFonts.body)),
    );
  }
}

class _UserChip extends StatelessWidget {
  final _UserSummary user;

  const _UserChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarSvg.trim().isNotEmpty;
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim().characters.first.toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 9, 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: hasAvatar
                ? ClipOval(
                    child: Image.asset(
                      user.avatarSvg,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      fontSize: AppFonts.label,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: AppFonts.badge,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFonts.title,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFonts.caption,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, double> _averageRatingsFrom(GuildPostModel post) {
  final totals = <String, double>{};
  final counts = <String, int>{};

  for (final review in post.peerReviews.values) {
    for (final entry in review.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      counts[entry.key] = (counts[entry.key] ?? 0) + 1;
    }
  }

  return totals.map((key, value) => MapEntry(key, value / counts[key]!));
}

String _shortUserId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return 'Unknown';
  if (trimmed.length <= 8) return trimmed;
  return '${trimmed.substring(0, 8)}...';
}

String? _formatTime(DateTime? createdAt) {
  if (createdAt == null) return null;
  final difference = DateTime.now().difference(createdAt);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
