import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/streak_provider.dart';
import '../../theme/app_theme.dart';

/// Compact streak indicator: flame icon with the current streak count inside.
class TaskStreakBadge extends ConsumerWidget {
  const TaskStreakBadge({
    super.key,
    required this.taskId,
    this.color,
    this.size = 22,
  });

  final String taskId;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(taskStreakProvider(taskId));
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final active = streak.current > 0;
    final iconColor =
        active ? accent : AppSemanticColors.textFaint(context);
    final textColor =
        active ? Colors.white : AppSemanticColors.textMuted(context);

    return Semantics(
      label: active
          ? '${streak.current} day streak'
          : 'No active streak',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: size,
              color: iconColor,
            ),
            Positioned(
              bottom: size * 0.06,
              child: Text(
                '${streak.current}',
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: textColor,
                  shadows: active
                      ? const [
                          Shadow(
                            offset: Offset(0, 0.5),
                            blurRadius: 1,
                            color: Color(0x66000000),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
