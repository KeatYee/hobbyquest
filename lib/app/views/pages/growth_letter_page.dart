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
                  if (currentLetter != null) ...[
                    const SizedBox(height: 16),
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
        '${letter.questCount} quest${letter.questCount == 1 ? '' : 's'} - '
        '${letter.weeklyStreakDays} day${letter.weeklyStreakDays == 1 ? '' : 's'} week streak';

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
                  style: GoogleFonts.openSans(
                    fontWeight: FontWeight.w800,
                    fontSize: AppFonts.bodyLg,
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
                  style: GoogleFonts.openSans(
                    color: AppColors.primary,
                    fontSize: AppFonts.badge,
                    fontWeight: FontWeight.w800,
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
    final greeting = _letterGreeting;
    final body = _letterBody;

    return _LetterSurface(
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
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GrowthStampChop(
                label: 'Strongest growth',
                value: letter.strongestGrowth,
                icon: Icons.trending_up_rounded,
                angle: -0.035,
              ),
              _GrowthStampChop(
                label: 'Focus area',
                value: letter.focusArea,
                icon: Icons.center_focus_strong_rounded,
                angle: 0.025,
              ),
              _GrowthStampChop(
                label: 'Next week',
                value: letter.nextWeekFocus,
                icon: Icons.flag_rounded,
                angle: -0.02,
              ),
              _GrowthStampChop(
                label: 'Total quests',
                value:
                    '${letter.questCount} quest${letter.questCount == 1 ? '' : 's'}',
                icon: Icons.assignment_turned_in_rounded,
                angle: 0.03,
              ),
              _GrowthStampChop(
                label: 'Week streak',
                value:
                    '${letter.weeklyStreakDays} day${letter.weeklyStreakDays == 1 ? '' : 's'}',
                icon: Icons.local_fire_department_rounded,
                angle: -0.025,
              ),
            ],
          ),
          const SizedBox(height: 24),
          CustomPaint(
            painter: const _PaperLinesPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (greeting.isNotEmpty) ...[
                    Text(
                      greeting,
                      style: GoogleFonts.caveat(
                        color: GrowthLetterPage._ink,
                        fontSize: 27,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    body,
                    style: GoogleFonts.openSans(
                      color: GrowthLetterPage._ink,
                      fontSize: AppFonts.body,
                      height: 1.68,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: -0.08,
              child: Text(
                'HobbyQuest',
                style: GoogleFonts.caveat(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _letterGreeting {
    final text = letter.letter.trim();
    if (text.isEmpty) return '';

    final lines = text.split(RegExp(r'\r?\n'));
    final firstLine = lines.first.trim();
    if (firstLine.toLowerCase().startsWith('dear ')) {
      return firstLine;
    }
    return '';
  }

  String get _letterBody {
    final text = letter.letter.trim();
    final greeting = _letterGreeting;
    if (greeting.isEmpty) return text;

    return text.substring(greeting.length).trimLeft();
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

class _GrowthStampChop extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double angle;

  const _GrowthStampChop({
    required this.label,
    required this.value,
    required this.icon,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    const stampColor = AppColors.primary;

    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        painter: const _StampChopPainter(color: stampColor),
        child: Container(
          width: 148,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
          decoration: BoxDecoration(
            color: stampColor.withOpacity(0.045),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: stampColor.withOpacity(0.9)),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.openSans(
                        color: stampColor.withOpacity(0.76),
                        fontSize: 8.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.openSans(
                        color: GrowthLetterPage._ink,
                        fontSize: AppFonts.badge,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
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
}

class _StampChopPainter extends CustomPainter {
  final Color color;

  const _StampChopPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = color.withOpacity(0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    final innerPaint = Paint()
      ..color = color.withOpacity(0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    final inner = RRect.fromRectAndRadius(
      Offset(3.5, 3.5) & Size(size.width - 7, size.height - 7),
      const Radius.circular(4),
    );

    canvas.drawRRect(outer, outerPaint);
    canvas.drawRRect(inner, innerPaint);

    final markPaint = Paint()
      ..color = color.withOpacity(0.22)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    const markLength = 8.0;
    canvas.drawLine(
      const Offset(8, 5),
      Offset(8 + markLength, 5),
      markPaint,
    );
    canvas.drawLine(
      Offset(size.width - 8 - markLength, size.height - 5),
      Offset(size.width - 8, size.height - 5),
      markPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StampChopPainter oldDelegate) {
    return oldDelegate.color != color;
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
