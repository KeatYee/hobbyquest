import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../models/tree_model.dart';

class ForestPage extends StatefulWidget {
  const ForestPage({super.key});

  @override
  State<ForestPage> createState() => _ForestPageState();
}

class _ForestPageState extends State<ForestPage> {
  static const int _spotCount = 6;

  Future<void> _onSwap(
    TreeModel dragged,
    ({TreeModel tree, DocumentReference ref}) target,
    List<({TreeModel tree, DocumentReference ref})> items,
  ) async {
    if (dragged.id == target.tree.id) return;
    try {
      final draggedEntry = items.firstWhere((e) => e.tree.id == dragged.id);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(draggedEntry.ref, {'treeIndex': target.tree.treeIndex});
      batch.update(target.ref, {'treeIndex': dragged.treeIndex});
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _onAssignToEmptySpot(
    TreeModel dragged,
    int spotIndex,
    List<({TreeModel tree, DocumentReference ref})> items,
  ) async {
    if (dragged.treeIndex == spotIndex) return;
    try {
      final draggedEntry = items.firstWhere((e) => e.tree.id == dragged.id);
      await draggedEntry.ref.update({'treeIndex': spotIndex});
    } catch (_) {}
  }

  Widget _buildEmptySpot(bool isHovered) {
    return Center(
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isHovered
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: isHovered
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.surface.withValues(alpha: 0.4),
            width: isHovered ? 2.5 : 2,
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
          _buildTreeAsset(),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTreeInfo(tree),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.surface.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
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
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tree.treeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'XP Required: ${tree.xpRequired}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Grown At: ${tree.grownAt != null ? '${tree.grownAt!.year}-${tree.grownAt!.month.toString().padLeft(2, '0')}-${tree.grownAt!.day.toString().padLeft(2, '0')}' : 'N/A'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreeAsset() {
    return Image.asset(
      'assets/images/mature_tree.png',
      width: 140,
      height: 140,
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.success,
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : Stack(
              children: [
                // Forest background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/forestBG.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                // Grid content
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

                    // Pair each doc with its TreeModel and DocumentReference
                    final items = docs.map((doc) {
                      final tree = TreeModel.fromJson(
                        doc.data() as Map<String, dynamic>,
                        docId: doc.id,
                      );
                      return (tree: tree, ref: doc.reference);
                    }).toList();

                    // Map treeIndex → entry for quick lookup
                    final occupied = <int, ({TreeModel tree, DocumentReference ref})>{};
                    for (final e in items) {
                      occupied[e.tree.treeIndex] = e;
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _spotCount,
                        itemBuilder: (context, spotIndex) {
                          final entry = occupied[spotIndex];
                          if (entry != null) {
                            return DragTarget<TreeModel>(
                              onAcceptWithDetails: (details) {
                                _onSwap(details.data, entry, items);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovered = candidateData.isNotEmpty &&
                                    candidateData.first?.id != null &&
                                    candidateData.first!.id != entry.tree.id;
                                return Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isHovered
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: isHovered
                                        ? Border.all(
                                            color: AppColors.primary, width: 2.5)
                                        : null,
                                  ),
                                  child: Opacity(
                                    opacity: isHovered ? 0.7 : 1.0,
                                    child: LongPressDraggable<TreeModel>(
                                      data: entry.tree,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        elevation: 8,
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.antiAlias,
                                        child: SizedBox(
                                          width: 160,
                                          height: 160,
                                          child: _buildTreeAsset(),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildTreeWithInfo(entry.tree),
                                      ),
                                      child: _buildTreeWithInfo(entry.tree),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            return DragTarget<TreeModel>(
                              onAcceptWithDetails: (details) {
                                _onAssignToEmptySpot(details.data, spotIndex, items);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovered = candidateData.isNotEmpty;
                                return _buildEmptySpot(isHovered);
                              },
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
