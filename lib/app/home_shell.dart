import 'package:flutter/material.dart';

import '../features/directory/presentation/directory_list_screen.dart';
import '../features/directory/presentation/my_profile_screen.dart';
import '../features/events/presentation/events_screen.dart';
import '../features/home/presentation/home_dashboard_screen.dart';
import '../features/news/presentation/news_feed_screen.dart';
import '../features/volunteering/presentation/my_commitments_screen.dart';

/// Bottom-nav shell for approved members.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  void _navigateToTab(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  late final List<Widget Function()> _tabBuilders = [
    () => HomeDashboardScreen(onNavigateToTab: _navigateToTab),
    () => const NewsFeedScreen(),
    () => const EventsScreen(),
    () => const MyCommitmentsScreen(),
    () => const DirectoryListScreen(),
    () => const MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabBuilders.length; i++)
            _visited.contains(i) ? _tabBuilders[i]() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _navigateToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'News'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Events'),
          NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'Volunteer'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Directory'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
