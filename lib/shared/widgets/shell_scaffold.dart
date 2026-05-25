import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/calendar/add_item_sheet.dart';
import '../../providers/home_provider.dart';
import '../../providers/matrix_provider.dart';
import '../../providers/selected_day_provider.dart';
import '../../theme/app_theme.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final returningToHome = currentIndex != 0 && index == 0;
    final returningToMatrix = currentIndex != 1 && index == 1;
    if (returningToHome) {
      final next = ref.read(homeRevisitSignalProvider) + 1;
      ref.read(homeRevisitSignalProvider.notifier).state = next;
    }
    if (returningToMatrix) {
      final next = ref.read(matrixRevisitSignalProvider) + 1;
      ref.read(matrixRevisitSignalProvider.notifier).state = next;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final int currentIndex = navigationShell.currentIndex;

    return Scaffold(
      // Keep FAB + bottom bar fixed when a tab's search field opens the keyboard.
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final isOnCalendar = navigationShell.currentIndex == 2;
          final initialDate = isOnCalendar
              ? ref.read(selectedCalendarDayProvider)
              : DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );
          await showAddItemSheet(context, initialDate: initialDate);
          // No "Task added" toast — the new row appearing in the list is
          // the confirmation.
        },
        tooltip: 'Add task or event',
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => _onTap(0, ref),
              color: theme.colorScheme.primary,
            ),
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Grid View',
              selected: currentIndex == 1,
              onTap: () => _onTap(1, ref),
              color: theme.colorScheme.primary,
            ),
            // Center gap for FAB
            const SizedBox(width: 64),
            _NavItem(
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note,
              label: 'Calendar',
              selected: currentIndex == 2,
              onTap: () => _onTap(2, ref),
              color: theme.colorScheme.primary,
            ),
            _NavItem(
              icon: Icons.tune_outlined,
              activeIcon: Icons.tune,
              label: 'Settings',
              selected: currentIndex == 3,
              onTap: () => _onTap(3, ref),
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final inactive = AppSemanticColors.navInactive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? color : inactive,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : inactive,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
