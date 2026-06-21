import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(path: '/app/map',     icon: Icons.map_outlined,    activeIcon: Icons.map,    label: 'Jogar'),
    _TabItem(path: '/app/feed',    icon: Icons.dynamic_feed_outlined, activeIcon: Icons.dynamic_feed, label: 'Feed'),
    _TabItem(path: '/app/profile', icon: Icons.person_outline,  activeIcon: Icons.person, label: 'Eu'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        backgroundColor: _isMapTab(location) ? AppColors.bgDark : AppColors.bgLight,
        indicatorColor: AppColors.coral.withAlpha(30),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon:           Icon(t.icon),
                  selectedIcon:   Icon(t.activeIcon, color: AppColors.coral),
                  label:          t.label,
                ))
            .toList(),
      ),
    );
  }

  int _indexForLocation(String location) {
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  bool _isMapTab(String location) => location.startsWith('/app/map');
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.path, required this.icon, required this.activeIcon, required this.label});
}
