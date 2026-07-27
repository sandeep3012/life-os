import 'package:flutter/material.dart';

class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.ratio,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
  });

  final double ratio;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: strokeWidth,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          CircularProgressIndicator(
            value: ratio.clamp(0, 1),
            strokeWidth: strokeWidth,
            color: color,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(ratio * 100).round()}%',
            style: const TextStyle(
              fontFamily: 'PlexMono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
