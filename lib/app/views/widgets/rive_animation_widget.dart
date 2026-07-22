import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../../../core/constants/color_constants.dart';

/// Reusable Rive animation widget with basic loading/error handling.
class RiveAnimationWidget extends StatefulWidget {
  final String assetPath;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Alignment alignment;
  final String? artboard;
  final String? stateMachine;
  final bool useSharedTexture;
  final Widget? loading;
  final Widget? error;
  final VoidCallback? onLoaded;
  final void Function(Object error)? onFailed;

  const RiveAnimationWidget({
    super.key,
    required this.assetPath,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.artboard,
    this.stateMachine,
    this.useSharedTexture = false,
    this.loading,
    this.error,
    this.onLoaded,
    this.onFailed,
  });

  @override
  State<RiveAnimationWidget> createState() => _RiveAnimationWidgetState();
}

class _RiveAnimationWidgetState extends State<RiveAnimationWidget> {
  late final FileLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = FileLoader.fromAsset(widget.assetPath, riveFactory: Factory.rive);
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = RiveWidgetBuilder(
      fileLoader: _loader,
      artboardSelector: widget.artboard != null
          ? ArtboardSelector.byName(widget.artboard!)
          : const ArtboardDefault(),
      stateMachineSelector: widget.stateMachine != null
          ? StateMachineSelector.byName(widget.stateMachine!)
          : const StateMachineDefault(),
      builder: (context, state) => switch (state) {
        RiveLoading() => widget.loading ?? const SizedBox.shrink(),
        RiveFailed() => _buildError(state.error),
        RiveLoaded() => RiveWidget(
          controller: state.controller,
          fit: _mapFit(widget.fit),
          alignment: widget.alignment,
          useSharedTexture: widget.useSharedTexture,
        ),
      },
    );

    if (widget.height != null || widget.width != null) {
      child = SizedBox(
        height: widget.height,
        width: widget.width,
        child: child,
      );
    }

    return child;
  }

  Widget _buildError(Object error) {
    widget.onFailed?.call(error);
    return widget.error ?? const Icon(Icons.error, color: AppColors.error);
  }

  /// Map Flutter BoxFit to Rive Fit.
  Fit _mapFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.fill:
        return Fit.fill;
      case BoxFit.cover:
        return Fit.cover;
      case BoxFit.contain:
        return Fit.contain;
      case BoxFit.fitWidth:
        return Fit.fitWidth;
      case BoxFit.fitHeight:
        return Fit.fitHeight;
      case BoxFit.none:
        return Fit.none;
      case BoxFit.scaleDown:
        return Fit.scaleDown;
    }
  }
}
