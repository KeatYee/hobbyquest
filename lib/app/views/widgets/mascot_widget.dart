import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/constants/font_constants.dart';

class MascotWidget extends StatefulWidget {
  final String emotion;
  final String message;

  const MascotWidget({
    super.key,
    this.emotion = 'happy',
    required this.message,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTypewriterEffect();
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _startTypewriterEffect();
    }
  }

  void _startTypewriterEffect() {
    _timer?.cancel();
    setState(() {
      _currentIndex = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_currentIndex < widget.message.length) {
        setState(() {
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String imagePath = AppAssets.foxHappy;
    if (widget.emotion == 'thinking') imagePath = AppAssets.foxThinking;
    if (widget.emotion == 'sad') imagePath = AppAssets.foxSad;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(imagePath, height: 120, fit: BoxFit.contain),

        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, left: 10, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                    fontFamily: AppFonts.familyPrimary,
                  ),
                  children: [
                    TextSpan(text: widget.message.substring(0, _currentIndex)),
                    TextSpan(
                      text: widget.message.substring(_currentIndex),
                      style: const TextStyle(color: Colors.transparent),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 4,
              child: CustomPaint(
                painter: _BubbleTailPainter(color: AppColors.surface),
                size: const Size(24, 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    var path = Path();

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width / 2, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
