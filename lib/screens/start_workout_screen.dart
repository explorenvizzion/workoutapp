import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_picker_screen.dart';

final sb = Supabase.instance.client;

const kBodyParts = [
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quads',
  'hamstrings',
  'glutes',
  'calves',
  'core'
];

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({super.key});
  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  final selected = <String>{};
  bool loading = false;
  String? error;

  Future<void> _goPickExercises() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one body part.')),
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await sb
          .from('exercise_catalog')
          .select()
          .overlaps('body_parts', selected.toList());
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(
          exercises: List<Map<String, dynamic>>.from(res),
        ),
      ));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = sb.auth.currentUser;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Hello ${user?.email ?? ''}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Choose body parts',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final part in kBodyParts)
                FilterChip(
                  selected: selected.contains(part),
                  onSelected: (v) => setState(
                      () => v ? selected.add(part) : selected.remove(part)),
                  label: Text(part),
                )
            ],
          ),
          const Spacer(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton.icon(
            onPressed: loading ? null : _goPickExercises,
            icon: const Icon(Icons.navigate_next),
            label: Text(loading ? 'Loading...' : 'Pick exercises'),
          ),
        ]),
      ),
    );
  }
}
