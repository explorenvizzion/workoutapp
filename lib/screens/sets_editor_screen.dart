import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'history_screen.dart'; // you'll add this file below

final sb = Supabase.instance.client;

/* ---------------------------- Data model helper ---------------------------- */
class SetRow {
  int setNumber;
  double? weight;
  int? reps;
  double? rpe;
  bool isWarmup;
  int? id; // from DB if already saved

  SetRow({
    required this.setNumber,
    this.weight,
    this.reps,
    this.rpe,
    this.isWarmup = false,
    this.id,
  });
}

/* ------------------------------- Data loaders ------------------------------ */
Future<List<Map<String, dynamic>>> fetchWorkoutExercises(int workoutId) async {
  // 1) workout_exercises
  final wes = List<Map<String, dynamic>>.from(
    await sb
        .from('workout_exercises')
        .select('id, exercise_id, sort_order')
        .eq('workout_id', workoutId)
        .order('sort_order'),
  );

  if (wes.isEmpty) return wes;

  // 2) exercise names
  final exerciseIds = wes.map((e) => e['exercise_id']).toList();
  final exRows = List<Map<String, dynamic>>.from(
    await sb
        .from('exercise_catalog')
        .select('id, name')
        .inFilter('id', exerciseIds),
  );
  final nameById = {for (final e in exRows) e['id']: e['name']};

  // attach names + placeholder sets list
  for (final we in wes) {
    we['exercise_name'] = nameById[we['exercise_id']];
    we['sets'] = <SetRow>[];
  }
  return wes;
}

Future<void> fetchExistingSets(Map<String, dynamic> we) async {
  final weId = we['id'] as int;
  final rows = List<Map<String, dynamic>>.from(
    await sb
        .from('sets')
        .select('id, set_number, weight, reps, rpe, is_warmup')
        .eq('workout_exercise_id', weId)
        .order('set_number'),
  );

  we['sets'] = rows
      .map((s) => SetRow(
            id: s['id'] as int?,
            setNumber: s['set_number'] as int,
            weight: (s['weight'] as num?)?.toDouble(),
            reps: s['reps'] as int?,
            rpe: (s['rpe'] as num?)?.toDouble(),
            isWarmup: (s['is_warmup'] as bool?) ?? false,
          ))
      .toList();
}

/* ------------------------------ Editor screen ------------------------------ */
class SetsEditorScreen extends StatefulWidget {
  final int workoutId;
  const SetsEditorScreen({super.key, required this.workoutId});

  @override
  State<SetsEditorScreen> createState() => _SetsEditorScreenState();
}

class _SetsEditorScreenState extends State<SetsEditorScreen> {
  bool loading = true;
  String? error;
  // each item: { id, exercise_id, exercise_name, sort_order, sets: List<SetRow> }
  List<Map<String, dynamic>> wes = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      wes = await fetchWorkoutExercises(widget.workoutId);
      for (final we in wes) {
        await fetchExistingSets(we);
        if ((we['sets'] as List).isEmpty) {
          we['sets'] = List.generate(3, (i) => SetRow(setNumber: i + 1));
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _addRow(Map<String, dynamic> we) {
    final sets = we['sets'] as List<SetRow>;
    final nextNum = (sets.isEmpty ? 0 : sets.last.setNumber) + 1;
    sets.add(SetRow(setNumber: nextNum));
    setState(() {});
  }

  void _dupLastRow(Map<String, dynamic> we) {
    final sets = we['sets'] as List<SetRow>;
    if (sets.isEmpty) {
      _addRow(we);
      return;
    }
    final last = sets.last;
    sets.add(SetRow(
      setNumber: last.setNumber + 1,
      weight: last.weight,
      reps: last.reps,
      rpe: last.rpe,
      isWarmup: last.isWarmup,
    ));
    setState(() {});
  }

  void _deleteRow(Map<String, dynamic> we, int index) {
    final sets = we['sets'] as List<SetRow>;
    sets.removeAt(index);
    for (var i = 0; i < sets.length; i++) {
      sets[i].setNumber = i + 1; // keep contiguous numbering
    }
    setState(() {});
  }

  Future<void> _saveAll() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final upserts = <Map<String, dynamic>>[];
      final toDelete = <int>[];

      for (final we in wes) {
        final weId = we['id'] as int;

        // existing sets to detect deletions
        final existing = List<Map<String, dynamic>>.from(
          await sb
              .from('sets')
              .select('id, set_number')
              .eq('workout_exercise_id', weId),
        );
        final existingBySetNum = {
          for (final r in existing) r['set_number'] as int: r['id'] as int
        };

        final currentNums = <int>{};
        for (final SetRow sr in (we['sets'] as List<SetRow>)) {
          currentNums.add(sr.setNumber);
          upserts.add({
            'workout_exercise_id': weId,
            'set_number': sr.setNumber,
            'weight': sr.weight,
            'reps': sr.reps,
            'rpe': sr.rpe,
            'is_warmup': sr.isWarmup,
          });
        }

        // anything that exists but is no longer present → delete
        for (final entry in existingBySetNum.entries) {
          if (!currentNums.contains(entry.key)) {
            toDelete.add(entry.value);
          }
        }
      }

      if (upserts.isNotEmpty) {
        await sb
            .from('sets')
            .upsert(upserts, onConflict: 'workout_exercise_id,set_number');
      }
      if (toDelete.isNotEmpty) {
        await sb.from('sets').delete().inFilter('id', toDelete);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log your sets'),
        actions: [
          IconButton(onPressed: _saveAll, icon: const Icon(Icons.save)),
          IconButton(
            tooltip: 'Finish workout',
            onPressed: () async {
              await _saveAll();
              await Supabase.instance.client.from('workouts').update({
                'ended_at': DateTime.now().toUtc().toIso8601String()
              }).eq('id', widget.workoutId);
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.flag),
          ),
        ],
      ),
      body: error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : ListView.builder(
              itemCount: wes.length,
              itemBuilder: (context, i) => _exerciseCard(wes[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAll,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
    );
  }

  Widget _exerciseCard(Map<String, dynamic> we) {
    final sets = we['sets'] as List<SetRow>;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(we['exercise_name'] as String,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Set #')),
                DataColumn(label: Text('Weight')),
                DataColumn(label: Text('Reps')),
                DataColumn(label: Text('RPE')),
                DataColumn(label: Text('Warm-up')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (var idx = 0; idx < sets.length; idx++)
                  _setRow(we, sets[idx], idx),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => _addRow(we),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _dupLastRow(we),
              icon: const Icon(Icons.copy),
              label: const Text('Duplicate last'),
            ),
          ]),
        ]),
      ),
    );
  }

  DataRow _setRow(Map<String, dynamic> we, SetRow sr, int index) {
    final weightCtrl = TextEditingController(text: sr.weight?.toString() ?? '');
    final repsCtrl = TextEditingController(text: sr.reps?.toString() ?? '');
    final rpeCtrl = TextEditingController(text: sr.rpe?.toString() ?? '');

    void parseAndSet() {
      sr.weight =
          weightCtrl.text.isEmpty ? null : double.tryParse(weightCtrl.text);
      sr.reps = repsCtrl.text.isEmpty ? null : int.tryParse(repsCtrl.text);
      sr.rpe = rpeCtrl.text.isEmpty ? null : double.tryParse(rpeCtrl.text);
    }

    return DataRow(cells: [
      DataCell(Text(sr.setNumber.toString())),
      DataCell(SizedBox(
        width: 80,
        child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: weightCtrl,
          onChanged: (_) => parseAndSet(),
          decoration: const InputDecoration(hintText: 'lb/kg', isDense: true),
        ),
      )),
      DataCell(SizedBox(
        width: 60,
        child: TextField(
          keyboardType: TextInputType.number,
          controller: repsCtrl,
          onChanged: (_) => parseAndSet(),
          decoration: const InputDecoration(hintText: 'reps', isDense: true),
        ),
      )),
      DataCell(SizedBox(
        width: 60,
        child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: rpeCtrl,
          onChanged: (_) => parseAndSet(),
          decoration: const InputDecoration(hintText: 'RPE', isDense: true),
        ),
      )),
      DataCell(Checkbox(
        value: sr.isWarmup,
        onChanged: (v) {
          sr.isWarmup = v ?? false;
          setState(() {});
        },
      )),
      DataCell(IconButton(
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _deleteRow(we, index),
      )),
    ]);
  }
}

//history//


