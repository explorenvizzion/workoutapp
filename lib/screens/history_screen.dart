import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sets_editor_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await sb
            .from('workouts')
            .select('id, title, started_at, ended_at')
            .order('started_at', ascending: false)
            .limit(50),
      );
      items = rows;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final w = items[i];
                    final started = DateTime.parse(w['started_at']).toLocal();
                    final ended = w['ended_at'] != null
                        ? DateTime.parse(w['ended_at']).toLocal()
                        : null;
                    return ListTile(
                      title: Text(w['title'] ?? 'Workout ${w['id']}'),
                      subtitle: Text(
                        ended == null
                            ? 'Started ${started.toString()} — in progress'
                            : 'Started ${started.toString()} • Finished ${ended.toString()}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SetsEditorScreen(workoutId: w['id'] as int),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
