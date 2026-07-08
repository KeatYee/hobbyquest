import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../controllers/growth_letter_controller.dart';
import '../../controllers/guild_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../models/growth_letter_model.dart';
import '../dialogs/add_guild_post_dialog.dart';

class GrowthLetterPage extends StatefulWidget {
  const GrowthLetterPage({super.key});

  static const Color _paper = Color(0xFFFFFBEE);
  static const Color _paperEdge = Color(0xFFE8D8B8);
  static const Color _ink = Color(0xFF3B342D);
  static const Color _faintLine = Color(0xFFEEDFC3);

  @override
  State<GrowthLetterPage> createState() => _GrowthLetterPageState();
}

class _GrowthLetterPageState extends State<GrowthLetterPage> {
  final GlobalKey _letterImageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    return Obx(() {
      final user = profileController.userModel.value;

      if (user == null) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      final controller = Get.isRegistered<GrowthLetterController>()
          ? Get.find<GrowthLetterController>()
          : Get.put(GrowthLetterController(user: user));

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'GROWTH LETTER',
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
        body: SafeArea(
          top: false,
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final currentLetter = controller.letter.value;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentLetter == null)
                    const _EmptyLetterCard()
                  else
                    RepaintBoundary(
                      key: _letterImageKey,
                      child: _LetterCard(letter: currentLetter),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: controller.isGenerating.value
                          ? null
                          : () => controller.writeLetter(),
                      icon: controller.isGenerating.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 19),
                      label: Text(
                        controller.isGenerating.value
                            ? 'Writing...'
                            : 'Check For Growth Letter',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppFonts.button,
                        ),
                      ),
                    ),
                  ),
                  if (currentLetter != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _showShareToGuildSheet(
                          context,
                          currentLetter,
                          _letterImageKey,
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('Add to Guild'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppFonts.button,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: controller.showDemoLetter,
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Show Demo Letter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppFonts.button,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    });
  }

  Future<void> _showShareToGuildSheet(
    BuildContext context,
    GrowthLetterModel letter,
    GlobalKey letterImageKey,
  ) async {
    final guildController = Get.isRegistered<GuildController>()
        ? Get.find<GuildController>()
        : Get.put(GuildController(), permanent: true);

    if (guildController.categories.isEmpty && !guildController.isLoading.value) {
      await guildController.loadAllData();
      if (!mounted) return;
    }

    if (guildController.categories.isEmpty) {
      AppDialogs.info(
        'Guild Not Ready',
        'Please try again after the guild finishes loading.',
        durationSeconds: 3,
      );
      return;
    }

    final hobby = letter.hobby.trim().isNotEmpty ? letter.hobby.trim() : 'Growth';
    var categoryId = '';
    for (final category in guildController.categories) {
      if (category.hobbyNames.any(
        (name) => name.toLowerCase() == hobby.toLowerCase(),
      )) {
        categoryId = category.id;
        break;
      }
    }
    if (categoryId.isEmpty) {
      categoryId = guildController.categories.first.id;
    }

    final imageFile = await _captureLetterImage(letterImageKey, letter);
    if (!mounted || imageFile == null) return;

    final title = 'My weekly Growth Letter';
    final body = 'Sharing my weekly Growth Letter from HobbyQuest.\n\n'
        '${letter.questCount} quests - ${letter.reflectionCount} reflections';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddGuildPostDialog(
          hobby: hobby,
          categoryId: categoryId,
          initialTitle: title,
          initialBody: body,
          initialImageFile: imageFile,
        ),
      ),
    );
  }

  Future<XFile?> _captureLetterImage(
    GlobalKey letterImageKey,
    GrowthLetterModel letter,
  ) async {
    try {
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = letterImageKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw const FormatException('Letter image is not ready yet.');
      }

      final image = await renderObject.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Letter image was empty.');
      }

      final safeId = (letter.id.isEmpty ? 'growth_letter' : letter.id)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final path = [
        Directory.systemTemp.path,
        'hobbyquest_growth_letter_$safeId.png',
      ].join(Platform.pathSeparator);

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      return XFile(
        file.path,
        name: 'growth_letter.png',
        mimeType: 'image/png',
      );
    } catch (e) {
      AppDialogs.error(
        'Image Not Ready',
        'Could not prepare the letter image. Please try again.',
        durationSeconds: 3,
      );
      print('--- ERROR: Failed to capture growth letter image: $e ---');
      return null;
    }
  }
}

class _EmptyLetterCard extends StatelessWidget {
  const _EmptyLetterCard();

  @override
  Widget build(BuildContext context) {
    return _LetterSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: GrowthLetterPage._paperEdge),
                ),
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A letter is still being written',
                  style: GoogleFonts.caveat(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    color: GrowthLetterPage._ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'After you complete quests and write reflections, HobbyQuest can turn your last 7 days into a short growth letter.',
            style: GoogleFonts.openSans(
              height: 1.45,
              fontSize: AppFonts.body,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Awaiting growth',
                  style: GoogleFonts.caveat(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  final GrowthLetterModel letter;

  const _LetterCard({required this.letter});

  @override
  Widget build(BuildContext context) {
    return _LetterSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E2B8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GrowthLetterPage._paperEdge),
                ),
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your weekly letter',
                      style: GoogleFonts.caveat(
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                        color: GrowthLetterPage._ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${letter.questCount} quests, ${letter.reflectionCount} reflections',
                      style: GoogleFonts.openSans(
                        color: AppColors.textSecondary,
                        fontSize: AppFonts.badge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CustomPaint(
            painter: const _PaperLinesPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
              child: Text(
                letter.letter,
                style: GoogleFonts.caveat(
                  color: GrowthLetterPage._ink,
                  fontSize: 25,
                  height: 1.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14D46A36),
                  border: Border.all(color: AppColors.primary, width: 1.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'HobbyQuest',
                  style: GoogleFonts.caveat(
                    color: AppColors.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterSurface extends StatelessWidget {
  final Widget child;

  const _LetterSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: GrowthLetterPage._paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrowthLetterPage._paperEdge, width: 1.2),
        boxShadow: [
          const BoxShadow(
            color: Color(0x1A6E4D2A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.55),
            blurRadius: 0,
            spreadRadius: -1,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: GrowthLetterPage._faintLine.withOpacity(0.55),
              size: 18,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PaperLinesPainter extends CustomPainter {
  const _PaperLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GrowthLetterPage._faintLine.withOpacity(0.58)
      ..strokeWidth = 1;

    const spacing = 33.0;
    for (double y = 31; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
