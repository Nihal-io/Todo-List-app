import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/color_palettes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(resolvedSettingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final quadrantColors = ref.watch(quadrantColorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
        children: [
          const _SectionHeader('Appearance'),
          _SettingTile(
            title: 'Theme',
            subtitle: _themeModeLabel(settings.themeMode),
            child: _ThemeModePicker(
              value: settings.themeMode,
              onChanged: notifier.setThemeMode,
            ),
          ),
          _SettingTile(
            title: 'Color palette',
            subtitle: settings.palette.label,
            child: _PalettePicker(
              value: settings.palette,
              onChanged: notifier.setPalette,
            ),
          ),
          _SettingTile(
            title: 'Text size',
            subtitle: settings.textScale.label,
            child: _SegmentedEnumPicker<TextScalePref>(
              values: TextScalePref.values,
              selected: settings.textScale,
              labelFor: (v) {
                switch (v) {
                  case TextScalePref.small:
                    return 'S';
                  case TextScalePref.medium:
                    return 'M';
                  case TextScalePref.large:
                    return 'L';
                }
              },
              onChanged: notifier.setTextScale,
            ),
          ),
          _SettingTile(
            title: 'Density',
            subtitle: settings.density.label,
            child: _SegmentedEnumPicker<DensityPref>(
              values: DensityPref.values,
              selected: settings.density,
              labelFor: (v) => v.label,
              onChanged: notifier.setDensity,
            ),
          ),
          const SizedBox(height: 8),
          const _SectionHeader('Home screen'),
          _SwitchTile(
            title: 'Progress card',
            subtitle: "Show today's completion summary",
            value: settings.showProgressCard,
            onChanged: notifier.setShowProgressCard,
          ),
          _SwitchTile(
            title: 'Overdue panel',
            subtitle: 'Highlight tasks past their deadline',
            value: settings.showOverduePanel,
            onChanged: notifier.setShowOverduePanel,
          ),
          _SwitchTile(
            title: 'Current / Upcoming toggle',
            subtitle:
                'Hide to always show only current tasks below the dashboard',
            value: settings.showSectionToggle,
            onChanged: notifier.setShowSectionToggle,
          ),
          const SizedBox(height: 8),
          const _SectionHeader('Calendar'),
          _SettingTile(
            title: 'First day of week',
            subtitle: settings.firstDayOfWeek.label,
            child: _SegmentedEnumPicker<FirstDayOfWeekPref>(
              values: FirstDayOfWeekPref.values,
              selected: settings.firstDayOfWeek,
              labelFor: (v) {
                switch (v) {
                  case FirstDayOfWeekPref.sunday:
                    return 'Sun';
                  case FirstDayOfWeekPref.monday:
                    return 'Mon';
                }
              },
              onChanged: notifier.setFirstDayOfWeek,
            ),
          ),
          _DateFormatTile(
            value: settings.dateFormat,
            onChanged: notifier.setDateFormat,
          ),
          const SizedBox(height: 8),
          const _SectionHeader('Grid view'),
          const _GridViewInfoCard(),
          _SwitchTile(
            title: 'Axis labels',
            subtitle: 'Show Urgent / Important guides around the grid',
            value: settings.showGridAxisLabels,
            onChanged: notifier.setShowGridAxisLabels,
          ),
          _SwitchTile(
            title: 'Include events',
            subtitle: 'Show calendar events in their assigned quadrant',
            value: settings.showGridEvents,
            onChanged: notifier.setShowGridEvents,
          ),
          _SwitchTile(
            title: 'Overdue highlight',
            subtitle: 'Red tint and OVERDUE tag on past-deadline items',
            value: settings.showGridOverdueHighlight,
            onChanged: notifier.setShowGridOverdueHighlight,
          ),
          _SwitchTile(
            title: 'Urgency badges',
            subtitle: 'Date and urgency pills on each grid tile',
            value: settings.showGridUrgencyBadges,
            onChanged: notifier.setShowGridUrgencyBadges,
          ),
          _SettingTile(
            title: 'Soon threshold',
            subtitle:
                'Items within ${settings.gridSoonThreshold.label} show as soon',
            child: _SegmentedEnumPicker<GridSoonThresholdPref>(
              values: GridSoonThresholdPref.values,
              selected: settings.gridSoonThreshold,
              labelFor: (v) => v.label,
              onChanged: notifier.setGridSoonThreshold,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Quadrant colors',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppSemanticColors.textMuted(context),
              ),
            ),
          ),
          for (final q in MatrixQuadrant.values)
            _QuadrantColorTile(
              quadrant: q,
              currentColor: quadrantColors[q] ?? q.color,
              isOverridden: settings.quadrantColorOverrides.containsKey(q),
              onPick: (color) => notifier.setQuadrantColor(q, color),
              onReset: () => notifier.resetQuadrantColor(q),
            ),
          const SizedBox(height: 8),
          const _SectionHeader('Notifications'),
          _SwitchTile(
            title: 'Local reminders',
            subtitle: settings.notificationsEnabled
                ? 'Notifies you when a task or event starts'
                : 'Off — no reminders will be sent',
            value: settings.notificationsEnabled,
            onChanged: (v) async {
              await notifier.setNotificationsEnabled(v);
              if (v) {
                final service = ref.read(notificationServiceProvider);
                await service.requestPermission();
              }
            },
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Reset'),
          _ResetAllTile(onReset: notifier.resetAll),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Follow system';
    }
  }
}

// ---------------------------------------------------------------------------
// Layout primitives
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppSemanticColors.textStrong(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppSemanticColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom pickers
// ---------------------------------------------------------------------------

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.brightness_auto_outlined),
        ),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _SegmentedEnumPicker<T extends Enum> extends StatelessWidget {
  const _SegmentedEnumPicker({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: [
        for (final v in values)
          ButtonSegment<T>(value: v, label: Text(labelFor(v))),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.value, required this.onChanged});

  final AppPalette value;
  final ValueChanged<AppPalette> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppPalette.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = AppPalette.values[i];
          final selected = p == value;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: Tooltip(
              message: p.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.seedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppSemanticColors.textStrong(context)
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: p.seedColor.withValues(alpha: 0.35),
                      blurRadius: selected ? 10 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check, size: 22, color: Colors.white)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateFormatTile extends StatelessWidget {
  const _DateFormatTile({required this.value, required this.onChanged});

  final DateFormatPref value;
  final ValueChanged<DateFormatPref> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingTile(
      title: 'Date format',
      subtitle: value.label,
      child: Column(
        children: [
          for (final v in DateFormatPref.values)
            _RadioRow<DateFormatPref>(
              value: v,
              groupValue: value,
              label: v.label,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final String label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? primary
                      : AppSemanticColors.subtleBorder(context),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppSemanticColors.textStrong(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid view info card
// ---------------------------------------------------------------------------

class _GridViewInfoCard extends StatelessWidget {
  const _GridViewInfoCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.grid_view_rounded, size: 22, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eisenhower grid',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tasks auto-sort by urgency within each quadrant. '
                  'Tap a title to edit; tap the checkbox to complete. '
                  'Completed items stay crossed off until you leave and '
                  'return to Grid View.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Matrix quadrant color picker
// ---------------------------------------------------------------------------

class _QuadrantColorTile extends StatelessWidget {
  const _QuadrantColorTile({
    required this.quadrant,
    required this.currentColor,
    required this.isOverridden,
    required this.onPick,
    required this.onReset,
  });

  final MatrixQuadrant quadrant;
  final Color currentColor;
  final bool isOverridden;
  final ValueChanged<Color> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showDialog<Color>(
            context: context,
            builder: (_) => _ColorPickerDialog(
              title: quadrant.label,
              initialColor: currentColor,
              allowReset: isOverridden,
              defaultColor: quadrant.color,
            ),
          );
          if (picked == null) return;
          if (picked == quadrant.color && isOverridden) {
            onReset();
          } else if (picked != currentColor) {
            onPick(picked);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppSemanticColors.tileBorder(context),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quadrant.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppSemanticColors.textStrong(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOverridden
                          ? '${quadrant.subtitle}  ·  Custom'
                          : quadrant.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppSemanticColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isOverridden)
                IconButton(
                  tooltip: 'Reset to default',
                  icon: const Icon(Icons.refresh),
                  onPressed: onReset,
                ),
              Icon(
                Icons.chevron_right,
                color: AppSemanticColors.textFaint(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.title,
    required this.initialColor,
    required this.allowReset,
    required this.defaultColor,
  });

  final String title;
  final Color initialColor;
  final bool allowReset;
  final Color defaultColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  /// Curated swatch grid — no extra dependency required.
  static const _palette = <Color>[
    Color(0xFFEF5350), // red
    Color(0xFFEC407A), // pink
    Color(0xFFAB47BC), // purple
    Color(0xFF7E57C2), // deep purple
    Color(0xFF5C6BC0), // indigo
    Color(0xFF42A5F5), // blue
    Color(0xFF26A69A), // teal
    Color(0xFF66BB6A), // green
    Color(0xFF9CCC65), // light green
    Color(0xFFFFA726), // orange
    Color(0xFFFF7043), // deep orange
    Color(0xFF8D6E63), // brown
    Color(0xFF90A4AE), // blue grey
    Color(0xFF546E7A), // slate
    Color(0xFFFFCA28), // amber
    Color(0xFF26C6DA), // cyan
  ];

  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => setState(() => _selected = c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selected.toARGB32() == c.toARGB32()
                          ? AppSemanticColors.textStrong(context)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: _selected.toARGB32() == c.toARGB32()
                      ? const Icon(Icons.check, size: 22, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.allowReset)
          TextButton(
            onPressed: () => Navigator.of(context).pop(widget.defaultColor),
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reset all
// ---------------------------------------------------------------------------

class _ResetAllTile extends StatelessWidget {
  const _ResetAllTile({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Icon(Icons.restore, color: error),
        title: Text(
          'Reset all settings to defaults',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: error,
          ),
        ),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Reset settings?'),
              content: const Text(
                'This will restore every appearance, home, calendar, and '
                'grid view setting to its default value. Your tasks will '
                'not be affected.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            ),
          );
          if (confirmed ?? false) onReset();
        },
      ),
    );
  }
}
