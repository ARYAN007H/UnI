import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class LiquidGlassPill extends StatelessWidget {
  final List<LiquidPillItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassPill({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppTheme.liquidGlass(
            opacity: 0.35,
            radius: 32,
            baseColor: AppTheme.surfaceContainerHigh,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onItemSelected(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedContainer(
                    duration: AppTheme.aquamorphicDuration,
                    curve: AppTheme.aquamorphicCurve,
                    padding: EdgeInsets.all(isSelected ? 12 : 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primary.withValues(alpha: 0.2) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      item.icon,
                      color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                      size: isSelected ? 28 : 24,
                    ).animate(target: isSelected ? 1 : 0)
                     .scaleXY(end: 1.15, curve: AppTheme.aquamorphicCurve, duration: 400.ms)
                     .tint(color: AppTheme.primary, end: 1),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class LiquidPillItem {
  final IconData icon;
  final String label;

  const LiquidPillItem({
    required this.icon,
    required this.label,
  });
}
