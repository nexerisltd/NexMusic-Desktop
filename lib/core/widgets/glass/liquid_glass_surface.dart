import 'dart:ui';

import 'package:flutter/material.dart';

/// A reusable "frosted glass" surface: blurs whatever sits behind it, tints
/// it with a translucent colour, and adds a soft diagonal sheen plus a thin
/// bright edge — the combination that reads as "glass" rather than just
/// "blurred".
///
/// This is the Flutter/desktop counterpart to NexMusic-Android's
/// `component/backdrop` system (Blur + Highlight + InnerShadow layered on a
/// `RuntimeShader`). Flutter has no direct equivalent to Android's
/// RenderEffect/RuntimeShader pipeline, so this recreates the same visual
/// language — blur, tint, sheen, rim light — using standard [BackdropFilter]
/// and layered gradients instead.
///
/// Wrap any panel that floats above album art or a blurred background with
/// this widget: the queue drawer, the mini-player bar, bottom sheets, etc.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;

  /// Overall opacity of the tint colour laid over the blurred backdrop.
  /// Lower = clearer glass, higher = more opaque/frosted.
  final double tintOpacity;

  /// Tint colour. Defaults to the current [ColorScheme.surface], so panels
  /// automatically pick up the accent colour set in Appearance settings.
  final Color? tintColor;

  /// Whether to draw a thin bright rim around the edge, simulating light
  /// catching the border of a glass pane. Turn off for surfaces that
  /// already sit inside another bordered container.
  final bool showEdgeHighlight;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 24,
    this.tintOpacity = 0.35,
    this.tintColor,
    this.showEdgeHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? Theme.of(context).colorScheme.surface;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Stack(
          children: [
            // Colour tint over the blurred backdrop.
            Positioned.fill(
              child: ColoredBox(color: tint.withValues(alpha: tintOpacity)),
            ),
            // Diagonal sheen: brighter near the top-left, fading to a
            // faint shadow at the bottom-right — mimics light hitting a
            // curved glass surface.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.06),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            if (showEdgeHighlight)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
