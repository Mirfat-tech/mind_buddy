// lib/features/day/daily_page_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/hobonichi_repo.dart';
import 'package:mind_buddy/paper/hobo_box.dart';
import 'package:mind_buddy/paper/paper_canvas.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';

import 'widgets/chat_box_widget.dart';
import 'widgets/journal_box_widget.dart';
import 'widgets/pomodoro_box_widget.dart';
import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'widgets/checklist_box_widget.dart';

import 'package:mind_buddy/services/mind_buddy_api.dart';

class DailyPageScreen extends StatefulWidget {
  const DailyPageScreen({super.key, required this.dayId});
  final String dayId;

  @override
  State<DailyPageScreen> createState() => _DailyPageScreenState();
}

class _DailyPageScreenState extends State<DailyPageScreen> {
  late final SupabaseClient supabase;
  late final HobonichiRepo repo;

  bool loading = true;
  String? pageId;
  String? coverId;

  List<Map<String, dynamic>> boxes = [];

  late final MindBuddyEnhancedApi _api;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
    repo = HobonichiRepo(supabase);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/signin');
      return;
    }

    await repo.ensureDayExists(dayId: widget.dayId, userId: user.id);

    coverId = await repo.getCoverForDay(dayId: widget.dayId, userId: user.id);

    final page = await repo.getOrCreateFirstPage(
      dayId: widget.dayId,
      userId: user.id,
    );

    pageId = page['id'] as String?;
    if (pageId != null) {
      boxes = await repo.listBoxes(pageId: pageId!);
    } else {
      boxes = [];
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _pickCover() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 8),
            for (final s in paperStyles)
              ListTile(
                title: Text(s.name),
                onTap: () => Navigator.pop(context, s.id),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );

    if (selected == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    await repo.setCoverForDay(
      dayId: widget.dayId,
      userId: user.id,
      coverId: selected,
    );

    await _load();
  }

  Future<void> _openAddSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: const [
              SizedBox(height: 8),
              _AddTile(
                value: 'journal',
                icon: Icons.edit_note,
                title: 'Journal box',
                subtitle: 'Write anything for this day',
              ),
              _AddTile(
                value: 'chat',
                icon: Icons.chat_bubble_outline,
                title: 'Chat box',
                subtitle: 'Talk to Mind Buddy about this day',
              ),
              _AddTile(
                value: 'checklist',
                icon: Icons.check_box_outlined,
                title: 'Checklist box',
                subtitle: 'Tick items off like Apple Notes',
              ),
              _AddTile(
                value: 'pomodoro',
                icon: Icons.timer_outlined,
                title: 'Pomodoro',
                subtitle: 'Focus timer (25/5)',
              ),
              _AddTile(
                value: 'logs',
                icon: Icons.table_chart_outlined,
                title: 'Logs table',
                subtitle: 'Movies / restaurants / books etc with ratings',
              ),
              SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (pageId == null) return;

    if (selected == 'journal') {
      await repo.addJournalBox(
        userId: user.id,
        pageId: pageId!,
        sortOrder: boxes.length,
      );
    } else if (selected == 'checklist') {
      await repo.addChecklistBox(
        userId: user.id,
        pageId: pageId!,
        sortOrder: boxes.length,
      );
    } else if (selected == 'pomodoro') {
      await repo.addPomodoroBox(
        userId: user.id,
        pageId: pageId!,
        sortOrder: boxes.length,
      );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final style = styleById(coverId);

    return PaperCanvas(
      style: style,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: MbGlowBackButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(widget.dayId),
          actions: [
            MbGlowIconButton(
              icon: Icons.palette_outlined,
              onPressed: _pickCover,
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HoboBox(
                      style: style,
                      title: 'DAY',
                      child: Row(
                        children: [
                          Text(
                            widget.dayId,
                            style: TextStyle(
                              color: style.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Page 1',
                            style: TextStyle(
                              color: style.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: boxes.length + 1, // +1 for the habit grid
                        itemBuilder: (_, i) {
                          // 0 = habit grid
                          if (i == 0) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: HabitMonthGrid(
                                month: DateTime.now(),
                                onManageTap: () {
                                  // If you want to go to your manage screen from here,
                                  // add your navigation here (GoRouter example):
                                  // context.push('/habits/manage');
                                },
                              ),
                            );
                          }

                          // boxes start at index 1 now
                          final box = boxes[i - 1];
                          final type = (box['type'] ?? '').toString().trim();

                          final contentRaw = box['content'];
                          final content = (contentRaw is Map)
                              ? contentRaw.cast<String, dynamic>()
                              : <String, dynamic>{};

                          if (type == 'journal') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HoboBox(
                                style: style,
                                title: 'JOURNAL',
                                child: JournalBoxWidget(
                                  box: box,
                                  initialText: (content['text'] ?? '')
                                      .toString(),
                                  onSave: (text) async {
                                    final newContent = <String, dynamic>{
                                      ...content,
                                      'text': text,
                                    };
                                    await repo.updateBoxContent(
                                      boxId: box['id'] as String,
                                      content: newContent,
                                    );
                                  },
                                ),
                              ),
                            );
                          }

                          if (type == 'chat') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HoboBox(
                                style: style,
                                title: 'CHAT',
                                child: ChatBoxWidget(
                                  dayId: widget.dayId,
                                  box: box,
                                  api: _api,
                                ),
                              ),
                            );
                          }

                          if (type == 'checklist') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onLongPress: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text(
                                        'Delete this checklist box?',
                                      ),
                                      content: const Text(
                                        'This removes the whole checklist box from the page.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (ok == true) {
                                    await repo.deleteBox(
                                      boxId: box['id'] as String,
                                    );
                                    await _load();
                                  }
                                },
                                child: HoboBox(
                                  style: style,
                                  title: 'CHECKLIST',
                                  child: ChecklistBoxWidget(
                                    box: box,
                                    initialItems:
                                        (content['items'] as List? ?? [])
                                            .map(
                                              (x) => ChecklistItem.fromJson(
                                                Map<String, dynamic>.from(x),
                                              ),
                                            )
                                            .toList(),
                                    onSaveItems: (items) async {
                                      final newContent = <String, dynamic>{
                                        ...content,
                                        'items': items
                                            .map((i) => i.toJson())
                                            .toList(),
                                      };
                                      await repo.updateBoxContent(
                                        boxId: box['id'] as String,
                                        content: newContent,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }

                          if (type == 'pomodoro') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HoboBox(
                                style: style,
                                title: 'POMODORO',
                                child: PomodoroBoxWidget(
                                  box: box,
                                  onSaveContent: (newContent) async {
                                    await repo.updateBoxContent(
                                      boxId: box['id'] as String,
                                      content: newContent,
                                    );
                                  },
                                ),
                              ),
                            );
                          }

                          // default / unknown
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: HoboBox(
                              style: style,
                              title: type.toUpperCase(),
                              child: Text(
                                '(unknown box type: $type)',
                                style: TextStyle(color: style.text),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _openAddSheet,
                        child: const Text('+ Add'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, value),
    );
  }
}
