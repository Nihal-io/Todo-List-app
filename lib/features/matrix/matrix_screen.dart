import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(quadrantColorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AxisLabel(left: 'NOT URGENT', right: 'URGENT'),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AxisLabelVertical(label: 'IMPORTANT'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _QuadrantCard(
                                  quadrant: MatrixQuadrant.schedule,
                                  color: colors[MatrixQuadrant.schedule]!,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuadrantCard(
                                  quadrant: MatrixQuadrant.doFirst,
                                  color: colors[MatrixQuadrant.doFirst]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _QuadrantCard(
                                  quadrant: MatrixQuadrant.eliminate,
                                  color: colors[MatrixQuadrant.eliminate]!,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuadrantCard(
                                  quadrant: MatrixQuadrant.delegate,
                                  color: colors[MatrixQuadrant.delegate]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const _AxisLabel(left: 'NOT IMPORTANT', right: 'NOT IMPORTANT'),
          ],
        ),
      ),
    );
  }
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({required this.quadrant, required this.color});

  final MatrixQuadrant quadrant;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              quadrant.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quadrant.subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            _icon(quadrant),
            size: 28,
            color: color.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  IconData _icon(MatrixQuadrant q) {
    switch (q) {
      case MatrixQuadrant.doFirst:
        return Icons.bolt_outlined;
      case MatrixQuadrant.schedule:
        return Icons.event_outlined;
      case MatrixQuadrant.delegate:
        return Icons.person_outlined;
      case MatrixQuadrant.eliminate:
        return Icons.delete_outline;
    }
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Expanded(child: _AxisText(text: left)),
          Expanded(child: _AxisText(text: right)),
        ],
      ),
    );
  }
}

class _AxisText extends StatelessWidget {
  const _AxisText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: AppSemanticColors.textFaint(context),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _AxisLabelVertical extends StatelessWidget {
  const _AxisLabelVertical({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppSemanticColors.textFaint(context),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
