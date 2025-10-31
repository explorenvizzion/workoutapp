import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sb = Supabase.instance.client;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> prs = [];
  List<Map<String, dynamic>> monthly = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Query PRs view
      final prRows =
          await sb.from('v_best_lifts').select('name, best_weight_lb');
      // Query monthly volume view
      final volRows = await sb
          .from('v_monthly_volume')
          .select('month, total_volume')
          .order('month');

      prs = List<Map<String, dynamic>>.from(prRows);
      monthly = List<Map<String, dynamic>>.from(volRows);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Progress unavailable.\n\n$error\n\nTip: Make sure the SQL views exist (v_best_lifts, v_monthly_volume).',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personal Records', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Exercise')),
              DataColumn(label: Text('Best (lb)')),
            ],
            rows: [
              for (final r in prs)
                DataRow(cells: [
                  DataCell(Text('${r['name']}')),
                  DataCell(Text('${r['best_weight_lb'] ?? '-'}')),
                ])
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Monthly Volume', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Month')),
              DataColumn(label: Text('Total Volume')),
            ],
            rows: [
              for (final r in monthly)
                DataRow(cells: [
                  DataCell(Text(_formatMonth(r['month']))),
                  DataCell(Text('${r['total_volume'] ?? 0}')),
                ])
            ],
          ),
        ),
      ]),
    );
  }

  String _formatMonth(dynamic iso) {
    try {
      final dt = DateTime.parse(iso as String).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '$iso';
    }
  }
}
