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
        slots[groveIndex] = entry.value
            .whereType<num>()
            .map((item) => item.toInt())
            .where((index) => index >= 0 && index < _spotCount)
            .toSet();
      }
    }
    return slots;
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
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .where((index) => index >= 0 && index < _spotCount)
        .toSet();
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
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous grove',
            onPressed: canGoBack
                ? () => setState(
                    () => _selectedGroveIndex =
                        availableGroves[currentPosition - 1],
                  )
                : null,
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
    return GestureDetector(
      onTap: () => _showTreeInfo(tree),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTreeAsset(width: 120, height: 120),
          const SizedBox(height: 2),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTreeInfo(tree),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 10,
                      color: AppColors.surface.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      tree.treeName,
                      style: TextStyle(
                        fontSize: AppFonts.micro,
                        color: AppColors.surface.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildTreeAsset(width: 100, height: 100)),
            const SizedBox(height: 12),
            Text(
              tree.treeName,
              style: const TextStyle(
                fontSize: AppFonts.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'XP Required: ${tree.xpRequired}',
              style: const TextStyle(
                fontSize: AppFonts.bodyLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Grown At: ${tree.grownAt != null ? '${tree.grownAt!.year}-${tree.grownAt!.month.toString().padLeft(2, '0')}-${tree.grownAt!.day.toString().padLeft(2, '0')}' : 'N/A'}',
              style: const TextStyle(
                fontSize: AppFonts.bodyLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quests Completed: ${tree.questsCompleted}',
              style: const TextStyle(
                fontSize: AppFonts.bodyLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Learning Time: ${tree.learningMinutes ~/ 60}h ${tree.learningMinutes % 60}m',
              style: const TextStyle(
                fontSize: AppFonts.bodyLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Get.back();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    Get.back();
                    renameTree();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Rename'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          'My Forest',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.titleLg,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
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
                        _buildGroveSelector(selectedGrove, availableGroves),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          margin: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _statItem(
                                  Icons.forest_rounded,
                                  '$treesGrown',
                                  'Trees Grown',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: AppColors.surface.withValues(alpha: 0.3),
                              ),
                              Expanded(
                                child: _statItem(
                                  Icons.flash_on_rounded,
                                  '$totalXp',
                                  'Total XP',
                                ),
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
