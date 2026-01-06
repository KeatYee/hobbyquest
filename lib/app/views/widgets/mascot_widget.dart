import 'dart:async'; // Required for the Timer
import 'package:flutter/material.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/constants/color_constants.dart';

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
    // If the message changes (e.g. error msg), restart the effect
    if (oldWidget.message != widget.message) {
      _startTypewriterEffect();
    }
  }

  void _startTypewriterEffect() {
    // Reset
    _timer?.cancel();
    setState(() {
      _currentIndex = 0;
    });

    // Start Timer: Add 1 character every 30 milliseconds
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_currentIndex < widget.message.length) {
        setState(() {
          _currentIndex++;
        });
      } else {
        timer.cancel(); // Stop when done
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Clean up memory
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
        // 🦊 1. The Fox
        Image.asset(
          imagePath,
          height: 120,
          fit: BoxFit.contain,
        ),
        
        // 💬 2. The Speech Bubble Group
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // A. The Main White Box
            Container(
              margin: const EdgeInsets.only(top: 12, left: 10, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                // Soft Shadow
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              // Use RichText to keep layout stable while animating colors
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                    fontFamily: 'OpenSans', // Ensure font matches app theme
                  ),
                  children: [
                    // 1. Visible Text (Black)
                    TextSpan(
                      text: widget.message.substring(0, _currentIndex),
                    ),
                    // 2. Invisible Text (Transparent)
                    // This keeps the bubble size constant so it doesn't "jump"
                    TextSpan(
                      text: widget.message.substring(_currentIndex),
                      style: const TextStyle(color: Colors.transparent),
                    ),
                  ],
                ),
              ),
            ),
            
            // B. The Triangle Tail (Pointing Up)
            Positioned(
              top: 4, 
              child: CustomPaint(
                painter: _BubbleTailPainter(color: Colors.white),
                size: const Size(24, 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 🎨 Custom Painter to draw the Speech Bubble Tail
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color..style = PaintingStyle.fill;
    var path = Path();
    
    // Draw an upside-down triangle
    path.moveTo(0, size.height); // Bottom Left
    path.lineTo(size.width, size.height); // Bottom Right
    path.lineTo(size.width / 2, 0); // Top Center (Tip)
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}