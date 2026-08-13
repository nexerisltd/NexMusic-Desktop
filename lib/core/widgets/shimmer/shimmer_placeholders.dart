import 'dart:math';

import 'package:flutter/material.dart';

import 'shimmer_host.dart';

/// A single skeleton "line of text". Width is randomised once per instance
/// (25%–75% of the available width) so a block of these doesn't look like a
/// perfectly uniform grid — mirrors NexMusic-Android's `TextPlaceholder`.
class TextPlaceholder extends StatefulWidget {
  final double height;
  final BorderRadius borderRadius;

  const TextPlaceholder({
    super.key,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  State<TextPlaceholder> createState() => _TextPlaceholderState();
}

class _TextPlaceholderState extends State<TextPlaceholder> {
  late final double _widthFraction =
      0.25 + Random().nextDouble() * 0.5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _widthFraction,
        child: ShimmerBlock(
          height: widget.height,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// Skeleton row matching a `ListTile`-style song/playlist row: a square
/// thumbnail on the left, title + subtitle placeholder lines on the right.
class ListItemPlaceholder extends StatelessWidget {
  final double thumbnailSize;
  final double itemHeight;

  const ListItemPlaceholder({
    super.key,
    this.thumbnailSize = 48,
    this.itemHeight = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            ShimmerBlock(
              width: thumbnailSize,
              height: thumbnailSize,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  TextPlaceholder(),
                  TextPlaceholder(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton tile matching an album/playlist grid card: a square artwork
/// placeholder with two text lines underneath.
class GridItemPlaceholder extends StatelessWidget {
  final double size;

  const GridItemPlaceholder({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: size,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBlock(
                width: size,
                height: size,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              const TextPlaceholder(),
              const TextPlaceholder(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a pill-shaped button or chip.
class ButtonPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const ButtonPlaceholder({super.key, this.width = 90, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return ShimmerBlock(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }
}

/// A horizontally-scrolling row of [GridItemPlaceholder]s, useful for
/// mimicking a home-screen carousel section while it loads.
class ShimmerCarouselRow extends StatelessWidget {
  final int count;
  final double itemSize;

  const ShimmerCarouselRow({super.key, this.count = 6, this.itemSize = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Artwork + spacer + two text lines (with their own padding) need
      // roughly itemSize + 50px; a generous buffer avoids overflow across
      // different platform/DPI text-metrics variance.
      height: itemSize + 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, index) => GridItemPlaceholder(size: itemSize),
      ),
    );
  }
}
