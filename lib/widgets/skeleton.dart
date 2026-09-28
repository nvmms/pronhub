import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class VideoSkeletonGrid extends StatelessWidget {
  const VideoSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      final columns = (constraints.maxWidth / 220).floor().clamp(2, 8);
      final cardWidth = (constraints.maxWidth - spacing * (columns + 1)) / columns;
      return GridView.builder(
        padding: const EdgeInsets.all(spacing),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          mainAxisExtent: cardWidth * 9 / 16 + 98,
        ),
        itemCount: columns * 3,
        itemBuilder: (context, index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox()),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: 110, height: 12),
            const SizedBox(height: 8),
            const SkeletonBox(width: 75, height: 12),
          ],
        ),
      );
    },
  );
}

class CategorySkeletonGrid extends StatelessWidget {
  const CategorySkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 180).floor().clamp(2, 6);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 155,
        ),
        itemCount: columns * 3,
        itemBuilder: (context, index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SizedBox(width: double.infinity, child: SkeletonBox()),
            ),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: 70, height: 12),
          ],
        ),
      );
    },
  );
}
