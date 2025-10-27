import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://uzaglixigsdauaodvoer.supabase.co';
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseKey.isEmpty) {
    throw Exception('Missing SUPABASE_KEY. Pass it via --dart-define.');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

final sb = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true),
      home: StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = sb.auth.currentSession;
          if (session == null) return const AuthScreen();
          return const StartWorkoutScreen();
        },
      ),
    );
  }
}

/* ----------------------------- AUTH SCREEN ----------------------------- */
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> signUpOrIn({required bool isSignUp}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (isSignUp) {
        await sb.auth
            .signUp(email: email.text.trim(), password: password.text.trim());
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Account created. You are signed in.')));
      } else {
        await sb.auth.signInWithPassword(
            email: email.text.trim(), password: password.text.trim());
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(
              controller: password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: loading ? null : () => signUpOrIn(isSignUp: false),
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign in'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : () => signUpOrIn(isSignUp: true),
                child: const Text('Sign up'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/* ------------------------- START WORKOUT (Body parts) ------------------------- */
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

  Future<void> goPickExercises() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one body part.')));
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Fetch exercises that CONTAIN any of the selected body parts.
      final res = await sb
          .from('exercise_catalog')
          .select()
          .overlaps('body_parts', selected.toList()); // GIN index-friendly
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(
            exercises: List<Map<String, dynamic>>.from(res)),
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
      appBar: AppBar(
        title: const Text('Start Workout'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => sb.auth.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            onPressed: loading ? null : goPickExercises,
            icon: const Icon(Icons.navigate_next),
            label: Text(loading ? 'Loading...' : 'Pick exercises'),
          ),
        ]),
      ),
    );
  }
}

/* ----------------------------- EXERCISE PICKER ----------------------------- */
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

  Future<void> createWorkout() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one exercise.')));
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

      // 2) Add workout_exercises with sort_order
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

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => WorkoutCreatedScreen(
            workoutId: workoutId,
            exerciseNames:
                selected.values.map((e) => e['name'] as String).toList()),
      ));
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
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selected[id] = ex;
                          } else {
                            selected.remove(id);
                          }
                        });
                      }),
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
              onPressed: creating ? null : createWorkout,
              icon: const Icon(Icons.check),
              label: Text(creating ? 'Creating...' : 'Create workout'),
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- WORKOUT CREATED NOTE --------------------------- */
class WorkoutCreatedScreen extends StatelessWidget {
  final int workoutId;
  final List<String> exerciseNames;
  const WorkoutCreatedScreen(
      {super.key, required this.workoutId, required this.exerciseNames});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout created')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workout #$workoutId created',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Next: log sets & weights (grid editor).'),
          const SizedBox(height: 16),
          const Text('Exercises:'),
          const SizedBox(height: 8),
          ...exerciseNames.map((n) => Text('• $n')),
          const Spacer(),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => const StartWorkoutScreen(),
            )),
            child: const Text('Back to start'),
          ),
        ]),
      ),
    );
  }
}
