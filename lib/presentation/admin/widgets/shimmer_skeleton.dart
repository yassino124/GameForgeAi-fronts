import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/admin_theme.dart';

class ShimmerCard extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  const ShimmerCard({
    super.key,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 120,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Shimmer.fromColors(
        baseColor: AdminTheme.bgTertiary,
        highlightColor: AdminTheme.bgSecondary.withOpacity(0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerTableRow extends StatelessWidget {
  final List<double> columnWidths;

  const ShimmerTableRow({super.key, required this.columnWidths});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        border: Border(bottom: BorderSide(color: AdminTheme.borderGlow)),
      ),
      child: Shimmer.fromColors(
        baseColor: AdminTheme.bgTertiary,
        highlightColor: AdminTheme.bgSecondary.withOpacity(0.8),
        child: Row(
          children: columnWidths.map((width) {
            return Expanded(
              flex: (width * 100).round(),
              child: Container(
                height: 14,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const ShimmerList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => itemBuilder(context, index),
      ),
    );
  }
}

class ShimmerChart extends StatelessWidget {
  final double? width;
  final double? height;

  const ShimmerChart({super.key, this.width, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Shimmer.fromColors(
        baseColor: AdminTheme.bgTertiary,
        highlightColor: AdminTheme.bgSecondary.withOpacity(0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
