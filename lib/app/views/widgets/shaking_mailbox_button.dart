import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/asset_constants.dart';

class ShakingMailboxButton extends StatefulWidget {
  final bool isShaking;
  final VoidCallback onTap;

  const ShakingMailboxButton({
    super.key,
    required this.isShaking,
    required this.onTap,
  });

  @override
  State<ShakingMailboxButton> createState() => _ShakingMailboxButtonState();
}

class _ShakingMailboxButtonState extends State<ShakingMailboxButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant ShakingMailboxButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isShaking != widget.isShaking) {
      _updateAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAnimation() {
    if (widget.isShaking) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: 'Growth Letter',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Image.asset(
              AppAssets.foxMailbox,
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );

    if (!widget.isShaking) return button;

    return AnimatedBuilder(
      animation: _controller,
      child: button,
      builder: (context, child) {
        final wave = math.sin(_controller.value * math.pi * 6);
        return Transform.translate(
          offset: Offset(wave * 2.4, 0),
          child: Transform.rotate(angle: wave * 0.08, child: child),
        );
      },
    );
  }
}
