import 'package:flutter/material.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/components/circle_button.dart';

class CounterCard extends StatelessWidget {
  const CounterCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    this.unit = '',
    this.maxValue = 99,
    required this.onIncrement,
    required this.onDecrement,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String unit;
  final int maxValue;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final disabledDecrement = value <= 0;
    final disabledIncrement = value >= maxValue;

    return Material(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(48),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),

            // 文字
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value$unit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
              ],
            ),
            const Spacer(),

            // 减号
            CircleButton(
              icon: Icons.remove,
              onTap: disabledDecrement ? null : onDecrement,
              color: color,
            ),
            const SizedBox(width: 12),

            // 加号
            CircleButton(
              icon: Icons.add,
              onTap: disabledIncrement ? null : onIncrement,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}