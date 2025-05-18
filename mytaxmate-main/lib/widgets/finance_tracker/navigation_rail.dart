import 'package:flutter/material.dart';
import '../../main.dart';

class FinanceTrackerNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final VoidCallback onLogout;

  const FinanceTrackerNavigationRail({
    Key? key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      minWidth: 56.0,
      backgroundColor: Colors.white,
      elevation: 1,
      selectedIconTheme: IconThemeData(
        color: Theme.of(context).colorScheme.primary,
      ),
      selectedLabelTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
      unselectedLabelTextStyle: TextStyle(color: Colors.grey[600]),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.blueGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF003A6B).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.calculate, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.article_outlined),
          selectedIcon: Icon(Icons.article),
          label: Text('Tax News'),
        ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () {
                    onDestinationSelected(2); // Redirect to Tax News
                  },
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 10),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
      labelType: NavigationRailLabelType.selected,
    );
  }
}
