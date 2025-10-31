import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sets_editor_screen.dart';

final sb = Supabase.instance.client;

class ExercisePickerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  const ExercisePickerScreen({super.key, required this.exercises});
  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final selected = <int, Map<String, dynamic>>{};
  bool creating = false;
  String? error;

  Future<void> _createWorkout() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one exercise.')),
      );
      return;
    }
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final userId = sb.auth.currentUser!.id;

      // 1) Create workout
      final workout = await sb
          .from('workouts')
          .insert({
            'user_id': userId,
            'title': 'Workout ${DateTime.now().toLocal()}',
          })
          .select()
          .single();
      final workoutId = workout['id'] as int;

      // 2) Add workout_exercises
      final rows = <Map<String, dynamic>>[];
      var order = 1;
      for (final ex in selected.values) {
        rows.add({
          'workout_id': workoutId,
          'exercise_id': ex['id'],
          'sort_order': order++
        });
      }
      await sb.from('workout_exercises').insert(rows);

      // 3) Go to sets editor
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => SetsEditorScreen(workoutId: workoutId)),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.exercises;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose exercises')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final ex = items[i];
                final id = ex['id'] as int;
                final isSel = selected.containsKey(id);
                return ListTile(
                  title: Text(ex['name'] as String),
                  subtitle: Text((ex['body_parts'] as List).join(' • ')),
                  trailing: Checkbox(
                    value: isSel,
                    onChanged: (v) => setState(() {
                      if (v == true)
                        selected[id] = ex;
                      else
                        selected.remove(id);
                    }),
                  ),
                  onTap: () => setState(() {
                    if (isSel) {
                      selected.remove(id);
                    } else {
                      selected[id] = ex;
                    }
                  }),
                );
              },
            ),
          ),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Colors.red))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: creating ? null : _createWorkout,
              icon: const Icon(Icons.check),
              label: Text(creating ? 'Creating...' : 'Create workout'),
            ),
          ),
        ],
      ),
    );
  }
}
