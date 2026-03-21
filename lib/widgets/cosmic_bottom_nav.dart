import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CosmicBottomNavItem {
  final IconData icon;
  final String label;

  const CosmicBottomNavItem({required this.icon, required this.label});
}

class CosmicBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CosmicBottomNavItem> items;

  const CosmicBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final barTheme = Theme.of(context).bottomNavigationBarTheme;
    final selectedColor = barTheme.selectedItemColor ?? AdminAppTheme.gold;
    final unselectedColor =
        barTheme.unselectedItemColor ?? Colors.white.withValues(alpha: 0.86);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: Container(
        height: 80 + bottomInset,
        padding: EdgeInsets.only(
          left: 8,
          top: 8,
          right: 8,
          bottom: bottomInset,
        ),
        color: barTheme.backgroundColor ?? AdminAppTheme.gold,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List<Widget>.generate(items.length, (int index) {
            final item = items[index];
            return _NavItem(
              icon: item.icon,
              label: item.label,
              index: index,
              currentIndex: currentIndex,
              onTap: onTap,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color selectedColor;
  final Color unselectedColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 24,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: AdminAppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
