import 'package:flutter/material.dart';

/// Wraps a subtree that should display shimmering loading placeholders.
///
/// Mirrors NexMusic-Android's `ShimmerHost` (built on the `valentinilk/shimmer`
/// library): a single looping sweep animation is shared by every descendant
/// placeholder so all skeletons pulse in sync, instead of each one running
/// its own independent (and visually noisy) animation.
class ShimmerHost extends StatefulWidget {
  final Widget child;

  const ShimmerHost({super.key, required this.child});

  @override
  State<ShimmerHost> createState() => _ShimmerHostState();
}

class _ShimmerHostState extends State<ShimmerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 800ms sweep + 250ms pause, restarting from the start each loop —
    // matches the timing used on NexMusic-Android's shimmer theme.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(controller: _controller, child: widget.child);
  }
}

class _ShimmerScope extends InheritedWidget {
  final AnimationController controller;

  const _ShimmerScope({required this.controller, required super.child});

  static AnimationController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The base skeleton block every placeholder is built from. Paints a soft
/// surface-tint gradient that sweeps left-to-right in sync with the nearest
/// [ShimmerHost]. Falls back to a static tint if no [ShimmerHost] is found
/// above it in the tree, so it never throws if used standalone.
class ShimmerBlock extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final controller = _ShimmerScope.of(context);

    if (controller == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.35),
          borderRadius: borderRadius,
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Sweep the highlight band from off-screen left to off-screen right.
        final sweep = -1.6 + controller.value * 3.2;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + sweep, 0),
              end: Alignment(1 + sweep, 0),
              colors: [
                base.withValues(alpha: 0.25),
                base.withValues(alpha: 0.55),
                base.withValues(alpha: 0.25),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
