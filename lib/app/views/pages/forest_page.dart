import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../../core/constants/asset_constants.dart';
import '../../controllers/home_controller.dart';
import '../../models/tree_model.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../services/category_service.dart';

class ForestPage extends StatefulWidget {
  const ForestPage({super.key});

  @override
  State<ForestPage> createState() => _ForestPageState();
}

class _ForestPageState extends State<ForestPage> {
  static const int _spotCount = TreeModel.forestSpotCount;
  int? _selectedGroveIndex;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    if (arguments is Map) {
      final requestedIndex = (arguments['groveIndex'] as num?)?.toInt();
      if (requestedIndex != null && requestedIndex > 0) {
        _selectedGroveIndex = requestedIndex;
      }
    }
  }

  int _activeGroveIndex() {
    if (!Get.isRegistered<HomeController>()) return 1;
    final index = Get.find<HomeController>().user.value?.currentGroveIndex ?? 1;
    return index < 1 ? 1 : index;
  }

  Map<int, Set<int>> _readGroveSlots(dynamic value) {
    final slots = <int, Set<int>>{};
    if (value is Map) {
      for (final entry in value.entries) {
        final groveIndex = int.tryParse(entry.key.toString()) ?? 0;
        if (groveIndex < 1 || entry.value is! List) continue;
        final buffer = <int>{};
        for (final item in (entry.value as List)) {
          if (item is num) {
            final idx = item.toInt();
            if (idx >= 0 && idx < _spotCount) buffer.add(idx);
          }
        }
        slots[groveIndex] = buffer;
      }
    }
    return slots;
  }

  void _showNoOtherGrovesAlert() {
    AppDialogs.warning(
      'No other groves',
      'There are no other groves available to switch to right now.',
    );
  }

  Future<void> _onSwap(
    TreeModel dragged,
    ({TreeModel tree, DocumentReference ref}) target,
    List<({TreeModel tree, DocumentReference ref})> items,
  ) async {
    if (dragged.id == target.tree.id) return;
    try {
      final draggedEntry = items.firstWhere((e) => e.tree.id == dragged.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final draggedSnapshot = await transaction.get(draggedEntry.ref);
        final targetSnapshot = await transaction.get(target.ref);
        if (!draggedSnapshot.exists || !targetSnapshot.exists) {
          throw StateError('One of the trees no longer exists.');
        }

        final draggedData = Map<String, dynamic>.from(
          draggedSnapshot.data() as Map,
        );
        final targetData = Map<String, dynamic>.from(
          targetSnapshot.data() as Map,
        );
        final draggedIndex = (draggedData['treeIndex'] as num?)?.toInt() ?? 0;
        final targetIndex = (targetData['treeIndex'] as num?)?.toInt() ?? 0;

        transaction.update(draggedEntry.ref, {'treeIndex': targetIndex});
        transaction.update(target.ref, {'treeIndex': draggedIndex});
      });
    } catch (e) {
      AppDialogs.error('Could not move tree', e.toString());
    }
  }

  Future<void> _onAssignToEmptySpot(
    TreeModel dragged,
    int spotIndex,
    List<({TreeModel tree, DocumentReference ref})> items,
  ) async {
    if (dragged.treeIndex == spotIndex) return;
    if (spotIndex < 0 || spotIndex >= _spotCount) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final draggedEntry = items.firstWhere((e) => e.tree.id == dragged.id);
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);

      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final draggedSnapshot = await transaction.get(draggedEntry.ref);
        final userData = userSnapshot.data();
        if (userData == null || !draggedSnapshot.exists) {
          throw StateError('The forest changed. Please try again.');
        }

        final draggedData = Map<String, dynamic>.from(
          draggedSnapshot.data() as Map,
        );
        final currentIndex =
            (draggedData['treeIndex'] as num?)?.toInt() ?? dragged.treeIndex;
        final groveSlots = _readGroveSlots(
          userData['occupiedTreeSlotsByGrove'],
        );
        final occupiedSlots = groveSlots.putIfAbsent(
          dragged.groveIndex,
          () => dragged.groveIndex == 1
              ? _readOccupiedSlots(userData['occupiedTreeSlots'])
              : <int>{},
        )..addAll(items.map((entry) => entry.tree.treeIndex));

        if (occupiedSlots.contains(spotIndex) && spotIndex != currentIndex) {
          throw StateError('That forest spot is no longer empty.');
        }

        occupiedSlots
          ..remove(currentIndex)
          ..add(spotIndex);
        transaction.update(draggedEntry.ref, {'treeIndex': spotIndex});
        final userUpdate = <String, dynamic>{
          'occupiedTreeSlotsByGrove': {
            for (final entry in groveSlots.entries)
              entry.key.toString(): entry.value.toList()..sort(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (dragged.groveIndex == 1) {
          userUpdate['occupiedTreeSlots'] = occupiedSlots.toList()..sort();
        }
        transaction.update(userRef, userUpdate);
      });
    } catch (e) {
      AppDialogs.error('Could not move tree', e.toString());
    }
  }

  Set<int> _readOccupiedSlots(dynamic value) {
    if (value is! List) return <int>{};
    final result = <int>{};
    for (final item in value) {
      if (item is num) {
        final idx = item.toInt();
        if (idx >= 0 && idx < _spotCount) result.add(idx);
      }
    }
    return result;
  }

  Widget _buildGroveSelector(int selectedGrove, List<int> availableGroves) {
    final currentPosition = availableGroves.indexOf(selectedGrove);
    final canGoBack = currentPosition > 0;
    final canGoForward =
        currentPosition >= 0 && currentPosition < availableGroves.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 104, 24, 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous grove',
            onPressed: () {
              if (canGoBack) {
                setState(() => _selectedGroveIndex = availableGroves[currentPosition - 1]);
              } else {
                _showNoOtherGrovesAlert();
              }
            },
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FOREST GROVE',
                  style: TextStyle(
                    fontSize: AppFonts.label,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Grove $selectedGrove',
                  style: const TextStyle(
                    fontSize: AppFonts.bodyLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next grove',
            onPressed: canGoForward
                ? () => setState(
                    () => _selectedGroveIndex =
                        availableGroves[currentPosition + 1],
                  )
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySpot(bool isHovered) {
    return Center(
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isHovered
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: isHovered
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.surface.withValues(alpha: 0.2),
            width: isHovered ? 1.5 : 1,
          ),
        ),
        child: Icon(
          Icons.eco_outlined,
          size: 28,
          color: AppColors.surface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTreeWithInfo(TreeModel tree) {
    return Semantics(
      button: true,
      label: '${tree.treeName}, mature tree. Tap to view tree badge.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTreeInfo(tree),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTreeAsset(width: 120, height: 120),
                const SizedBox(height: 2),
                Container(
                  width: 104,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.9),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.softShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tree.treeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppFonts.micro,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTreeInfo(TreeModel tree) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    void renameTree() async {
      final newName = await AppDialogs.input(
        title: 'Rename Tree',
        initialValue: tree.treeName,
        hintText: 'Enter new name',
        confirmLabel: 'Save',
      );
      if (newName != null && newName.isNotEmpty && uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('tree')
            .doc(tree.id)
            .update({'treeName': newName});
      }
    }

    AppDialogs.custom(
      barrierDismissible: true,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTreeBadgeHero(tree),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GROWTH RECORD',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFonts.label,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _treeStatTile(
                            icon: Icons.bolt_rounded,
                            value: '${tree.xpRequired}',
                            label: 'XP earned',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _treeStatTile(
                            icon: Icons.flag_rounded,
                            value: '${tree.questsCompleted}',
                            label: 'Quests',
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _treeStatTile(
                            icon: Icons.schedule_rounded,
                            value: _formatLearningTime(tree.learningMinutes),
                            label: 'Learning',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _treeDetailRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Fully grown',
                      value: _formatTreeDate(tree.grownAt),
                    ),
                    const SizedBox(height: 8),
                    _treeDetailRow(
                      icon: Icons.park_rounded,
                      label: 'Forest home',
                      value:
                          'Grove ${tree.groveIndex} | Spot ${tree.treeIndex + 1}',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () {
                              Get.back();
                              renameTree();
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Rename tree'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreeBadgeHero(TreeModel tree) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: AppColors.secondary,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'MATURE TREE',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: AppFonts.label,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 142,
            height: 142,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.75),
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: _buildTreeAsset(width: 122, height: 122),
          ),
          const SizedBox(height: 12),
          Text(
            tree.treeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFonts.titleLg,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeStatTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFonts.bodyLg,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFonts.micro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFonts.micro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.caption,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLearningTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
  }

  String _formatTreeDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.textPrimary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppFonts.body,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFonts.micro,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTreeAsset({double width = 140, double height = 140}) {
    return Image.asset(
      AppAssets.treeMature,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'FOREST',
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
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.success,
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.5,
                    child: Image.asset(
                      AppAssets.forestBackground,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('tree')
                      .orderBy('treeIndex')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final allItems = docs.map((doc) {
                      final tree = TreeModel.fromJson(
                        doc.data() as Map<String, dynamic>,
                        docId: doc.id,
                      );
                      return (tree: tree, ref: doc.reference);
                    }).toList();

                    final activeGrove = _activeGroveIndex();
                    final availableGroves = <int>{
                      activeGrove,
                      ...allItems.map((entry) => entry.tree.groveIndex),
                      if (Get.isRegistered<HomeController>())
                        ...?Get.find<HomeController>()
                            .user
                            .value
                            ?.completedGroveIndexes,
                    }.where((index) => index > 0).toList()..sort();
                    final selectedGrove =
                        availableGroves.contains(_selectedGroveIndex)
                        ? _selectedGroveIndex!
                        : activeGrove;
                    final items = allItems
                        .where(
                          (entry) => entry.tree.groveIndex == selectedGrove,
                        )
                        .toList();

                    final occupied =
                        <int, ({TreeModel tree, DocumentReference ref})>{};
                    for (final e in items) {
                      occupied[e.tree.treeIndex] = e;
                    }

                    final treesGrown = items
                        .where((e) => e.tree.grownAt != null)
                        .length;
                    final totalXp = items.fold<int>(
                      0,
                      (acc, e) => acc + e.tree.xpRequired,
                    );

                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(24, 104, 24, 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous grove',
                                onPressed: () {
                                  if (availableGroves.indexOf(selectedGrove) > 0) {
                                    setState(
                                      () => _selectedGroveIndex =
                                          availableGroves[
                                              availableGroves.indexOf(selectedGrove) - 1
                                            ],
                                    );
                                  } else {
                                    _showNoOtherGrovesAlert();
                                  }
                                },
                                icon: const Icon(Icons.chevron_left_rounded),
                                color: AppColors.primary,
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Grove $selectedGrove',
                                      style: const TextStyle(
                                        fontSize: AppFonts.bodyLg,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _statItem(
                                          Icons.forest_rounded,
                                          '$treesGrown',
                                          'Trees',
                                        ),
                                        const SizedBox(width: 16),
                                        _statItem(
                                          Icons.flash_on_rounded,
                                          '$totalXp',
                                          'XP',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next grove',
                                onPressed: () {
                                  final grovePosition = availableGroves.indexOf(selectedGrove);
                                  if (grovePosition >= 0 &&
                                      grovePosition < availableGroves.length - 1) {
                                    setState(
                                      () => _selectedGroveIndex =
                                          availableGroves[grovePosition + 1],
                                    );
                                  } else {
                                    _showNoOtherGrovesAlert();
                                  }
                                },
                                icon: const Icon(Icons.chevron_right_rounded),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.78,
                                  ),
                              itemCount: _spotCount,
                              itemBuilder: (context, spotIndex) {
                                final entry = occupied[spotIndex];
                                if (entry != null) {
                                  return DragTarget<TreeModel>(
                                    onAcceptWithDetails: (details) {
                                      _onSwap(details.data, entry, items);
                                    },
                                    builder:
                                        (context, candidateData, rejectedData) {
                                          final isHovered =
                                              candidateData.isNotEmpty &&
                                              candidateData.first?.id != null &&
                                              candidateData.first!.id !=
                                                  entry.tree.id;
                                          return Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isHovered
                                                  ? AppColors.primary
                                                        .withValues(alpha: 0.15)
                                                  : Colors.transparent,
                                              border: isHovered
                                                  ? Border.all(
                                                      color: AppColors.primary,
                                                      width: 2.5,
                                                    )
                                                  : null,
                                            ),
                                            child: Opacity(
                                              opacity: isHovered ? 0.7 : 1.0,
                                              child:
                                                  LongPressDraggable<TreeModel>(
                                                    data: entry.tree,
                                                    feedback: Material(
                                                      color: Colors.transparent,
                                                      elevation: 8,
                                                      shape:
                                                          const CircleBorder(),
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: SizedBox(
                                                        width: 160,
                                                        height: 160,
                                                        child:
                                                            _buildTreeAsset(),
                                                      ),
                                                    ),
                                                    childWhenDragging: Opacity(
                                                      opacity: 0.3,
                                                      child: _buildTreeWithInfo(
                                                        entry.tree,
                                                      ),
                                                    ),
                                                    child: _buildTreeWithInfo(
                                                      entry.tree,
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                  );
                                } else {
                                  return DragTarget<TreeModel>(
                                    onAcceptWithDetails: (details) {
                                      _onAssignToEmptySpot(
                                        details.data,
                                        spotIndex,
                                        items,
                                      );
                                    },
                                    builder:
                                        (context, candidateData, rejectedData) {
                                          final isHovered =
                                              candidateData.isNotEmpty;
                                          return _buildEmptySpot(isHovered);
                                        },
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
