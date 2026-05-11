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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            offset: const Offset(-1, -1),
            blurRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: AppTheme.liquidGlass(
              opacity: 0.45,
              radius: 36,
              baseColor: AppTheme.surfaceContainerHigh,
            ).copyWith(
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 16 : 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppTheme.primary.withValues(alpha: 0.12) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      transform: Matrix4.translationValues(0, isSelected ? -4.0 : 0, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                            size: isSelected ? 24 : 24,
                          ).animate(target: isSelected ? 1 : 0)
                           .scaleXY(end: 1.1, curve: AppTheme.aquamorphicCurve, duration: 400.ms),
                          
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: isSelected 
                                ? Column(
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary.withValues(alpha: 0.6),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
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
