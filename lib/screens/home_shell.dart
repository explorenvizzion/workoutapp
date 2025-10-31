import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'start_workout_screen.dart'; // your existing start (body-part) screen
import 'history_screen.dart'; // you added this earlier
import 'progress_screen.dart'; // NEW (created in step 3 below)

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = const [
      StartWorkoutScreen(), // Tab 0
      HistoryScreen(), // Tab 1
      ProgressScreen(), // Tab 2
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Start'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}
