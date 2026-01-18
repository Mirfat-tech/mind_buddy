// lib/features/day/widgets/logs_table_widget.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogsTableWidget extends StatelessWidget {
  const LogsTableWidget({super.key, required this.dayId});

  final String dayId;

  static const String tTemplates = 'log_templates_v2';

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    final supabase = Supabase.instance.client;
    final res = await supabase.from(tTemplates).select().order('name');
    return (res as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadTemplates(),
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) return Text('Load templates error: ${snap.error}');
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final templates = snap.data!;
        if (templates.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No templates found. Seed log_templates_v2 first.'),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemCount: templates.length,
          itemBuilder: (context, i) {
            final t = templates[i];
            final templateId = (t['id'] ?? '').toString(); // UUID
            final templateKey = (t['template_key'] ?? '').toString(); // "sleep"
            final name = (t['name'] ?? templateKey).toString();

            return InkWell(
              onTap: () => context.push(
                '/templates/$templateId/logs/$dayId?key=$templateKey',
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
