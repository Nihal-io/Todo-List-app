import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Add task',
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
              icon: Icons.task_alt_outlined,
              activeIcon: Icons.task_alt,
              label: 'Today',
              selected: currentIndex == 0,
              onTap: () => _onTap(0),
              color: theme.colorScheme.primary,
            ),
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Matrix',
              selected: currentIndex == 1,
              onTap: () => _onTap(1),
              color: theme.colorScheme.primary,
            ),
            // Center gap for FAB
            const SizedBox(width: 64),
            _NavItem(
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note,
              label: 'Calendar',
              selected: currentIndex == 2,
              onTap: () => _onTap(2),
              color: theme.colorScheme.primary,
            ),
            _NavItem(
              icon: Icons.tune_outlined,
              activeIcon: Icons.tune,
              label: 'Settings',
              selected: currentIndex == 3,
              onTap: () => _onTap(3),
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
              color: selected ? color : const Color(0xFFB0B0C8),
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : const Color(0xFFB0B0C8),
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
