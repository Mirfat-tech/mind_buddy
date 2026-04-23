import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mind_buddy/services/daily_quote_service.dart';

enum StudyBuddyMessageKind {
  defaultStatus,
  quote,
  hourlyBreakReminder,
  sessionCompletePrompt,
}

enum StudyBuddyQuoteContext { focus, breakTime, encouragement, completion }

class StudyBuddyLiveSnapshot {
  const StudyBuddyLiveSnapshot({
    required this.mode,
    required this.running,
    required this.sessionStudySeconds,
    required this.sessionBreakSeconds,
  });

  final String mode;
  final bool running;
  final int sessionStudySeconds;
  final int sessionBreakSeconds;

  int get combinedSessionSeconds => sessionStudySeconds + sessionBreakSeconds;
}

class StudyBuddyMessageView {
  const StudyBuddyMessageView({
    required this.kind,
    required this.title,
    required this.body,
    this.detail,
    this.highlighted = false,
    this.quoteCredit,
  });

  final StudyBuddyMessageKind kind;
  final String title;
  final String body;
  final String? detail;
  final bool highlighted;
  final String? quoteCredit;
}

class StudyBuddyDetailView {
  const StudyBuddyDetailView({
    required this.title,
    required this.focusSummary,
    required this.breakSummary,
    required this.supportiveMessage,
    this.prompt,
    this.showLogActions = true,
  });

  final String title;
  final String focusSummary;
  final String breakSummary;
  final String supportiveMessage;
  final String? prompt;
  final bool showLogActions;
}

class StudyBuddyMessageController extends ChangeNotifier {
  StudyBuddyMessageController();

  static const Duration _temporaryMessageDuration = Duration(seconds: 4);

  Timer? _temporaryTimer;
  List<String> _quotes = DailyQuoteService.defaultQuotes;
  StudyBuddyLiveSnapshot _snapshot = const StudyBuddyLiveSnapshot(
    mode: 'focus',
    running: false,
    sessionStudySeconds: 0,
    sessionBreakSeconds: 0,
  );
  StudyBuddyMessageView? _temporaryView;
  bool _screenActive = true;
  bool _seededFromSnapshot = false;
  int _lastHourlyBreakReminder = 0;
  int _lastQuoteMilestone = 0;
  bool _sessionPromptAvailable = false;

  StudyBuddyMessageView get currentView =>
      _temporaryView ?? _buildDefaultView(_snapshot);

  Future<void> initialize() => refreshQuotes();

  Future<void> refreshQuotes() async {
    final settings = await DailyQuoteService.load();
    _quotes = settings.allQuotes
        .map((quote) => quote.trim())
        .where((quote) => quote.isNotEmpty)
        .toList(growable: false);
    notifyListeners();
  }

  void updateSnapshot(
    StudyBuddyLiveSnapshot snapshot, {
    required bool screenActive,
  }) {
    final previous = _snapshot;
    _snapshot = snapshot;
    _screenActive = screenActive;

    if (!_seededFromSnapshot ||
        snapshot.sessionStudySeconds < previous.sessionStudySeconds ||
        snapshot.sessionBreakSeconds < previous.sessionBreakSeconds) {
      _lastHourlyBreakReminder = snapshot.sessionStudySeconds ~/ 3600;
      _lastQuoteMilestone = snapshot.combinedSessionSeconds ~/ 600;
      _sessionPromptAvailable = false;
      _seededFromSnapshot = true;
    }

    if (_temporaryView == null) {
      notifyListeners();
    }

    if (!_screenActive || !_seededFromSnapshot) return;

    _maybeShowHourlyBreakReminder(snapshot);
    _maybeShowQuote(snapshot);
  }

  void showSessionCompletionPrompt() {
    _sessionPromptAvailable = true;
    _showTemporary(
      const StudyBuddyMessageView(
        kind: StudyBuddyMessageKind.sessionCompletePrompt,
        title: 'Study Buddy is here 🌷',
        body:
            'That focus stretch is ready to be tucked away ✨ Hold to save it.',
        detail: 'Study Log and Task Template are waiting in your little popup.',
        highlighted: true,
      ),
      duration: const Duration(seconds: 5),
    );
  }

  void dismissSessionCompletionPrompt() {
    _sessionPromptAvailable = false;
    if (_temporaryView?.kind == StudyBuddyMessageKind.sessionCompletePrompt) {
      _temporaryTimer?.cancel();
      _temporaryView = null;
      notifyListeners();
    }
  }

  StudyBuddyDetailView buildDetailView() {
    final focusDuration = formatStudyBuddyDuration(
      _snapshot.sessionStudySeconds,
    );
    final breakDuration = formatStudyBuddyDuration(
      _snapshot.sessionBreakSeconds,
    );
    final focusSummary = 'You’ve studied for $focusDuration so far 🫧';
    final breakSummary =
        'You’ve floated through $breakDuration of break time so far.';
    return StudyBuddyDetailView(
      title: 'Hey, I’m Study Buddy 🫧',
      focusSummary: focusSummary,
      breakSummary: breakSummary,
      supportiveMessage: _detailSupportiveMessage(_snapshot),
      prompt: _sessionPromptAvailable
          ? 'That focus stretch is ready to be tucked away ✨ Want to save it?'
          : null,
      showLogActions: true,
    );
  }

  @override
  void dispose() {
    _temporaryTimer?.cancel();
    super.dispose();
  }

  void _maybeShowHourlyBreakReminder(StudyBuddyLiveSnapshot snapshot) {
    final milestone = snapshot.sessionStudySeconds ~/ 3600;
    if (milestone <= 0 || milestone <= _lastHourlyBreakReminder) return;
    _lastHourlyBreakReminder = milestone;
    final quoteMilestone = snapshot.combinedSessionSeconds ~/ 600;
    if (quoteMilestone > _lastQuoteMilestone) {
      _lastQuoteMilestone = quoteMilestone;
    }
    final focusDuration = formatStudyBuddyDuration(
      snapshot.sessionStudySeconds,
    );
    _showTemporary(
      StudyBuddyMessageView(
        kind: StudyBuddyMessageKind.hourlyBreakReminder,
        title: 'Hey, I’m Study Buddy 🫧',
        body:
            'You’ve studied for $focusDuration so far. Feeling like taking a little break? 🌷',
        detail:
            'A tiny pause can help your thoughts settle before the next stretch.',
        highlighted: true,
      ),
    );
  }

  void _maybeShowQuote(StudyBuddyLiveSnapshot snapshot) {
    if (!snapshot.running || _temporaryView != null) return;
    final milestone = snapshot.combinedSessionSeconds ~/ 600;
    if (milestone <= 0 || milestone <= _lastQuoteMilestone) return;
    _lastQuoteMilestone = milestone;
    final quote = _pickQuote(_quoteContextFor(snapshot), milestone);
    if (quote == null) return;
    _showTemporary(
      StudyBuddyMessageView(
        kind: StudyBuddyMessageKind.quote,
        title: 'A little quote bubble 💭',
        body: quote,
        detail: snapshot.mode == 'break'
            ? 'A soft reset while the timer breathes.'
            : 'A quiet little line to keep beside your focus bubble.',
        highlighted: true,
        quoteCredit: 'From your Quote Bubble',
      ),
    );
  }

  void _showTemporary(
    StudyBuddyMessageView view, {
    Duration duration = _temporaryMessageDuration,
  }) {
    _temporaryTimer?.cancel();
    _temporaryView = view;
    notifyListeners();
    _temporaryTimer = Timer(duration, () {
      _temporaryView = null;
      notifyListeners();
    });
  }

  StudyBuddyMessageView _buildDefaultView(StudyBuddyLiveSnapshot snapshot) {
    return StudyBuddyMessageView(
      kind: StudyBuddyMessageKind.defaultStatus,
      title: 'Hey, I’m Study Buddy 🫧',
      body:
          'You’ve focused for ${formatStudyBuddyDuration(snapshot.sessionStudySeconds)} so far 🫧',
    );
  }

  StudyBuddyQuoteContext _quoteContextFor(StudyBuddyLiveSnapshot snapshot) {
    if (!snapshot.running) return StudyBuddyQuoteContext.completion;
    if (snapshot.mode == 'break') return StudyBuddyQuoteContext.breakTime;
    if (snapshot.sessionStudySeconds >= const Duration(hours: 2).inSeconds) {
      return StudyBuddyQuoteContext.encouragement;
    }
    return StudyBuddyQuoteContext.focus;
  }

  String? _pickQuote(StudyBuddyQuoteContext context, int seed) {
    final pool = _quotes.where((quote) => quote.trim().isNotEmpty).toList();
    if (pool.isEmpty) return null;
    final offset = switch (context) {
      StudyBuddyQuoteContext.focus => 3,
      StudyBuddyQuoteContext.breakTime => 7,
      StudyBuddyQuoteContext.encouragement => 11,
      StudyBuddyQuoteContext.completion => 17,
    };
    return pool[(seed + offset).abs() % pool.length];
  }

  String _detailSupportiveMessage(StudyBuddyLiveSnapshot snapshot) {
    if (_sessionPromptAvailable) {
      return 'That focus stretch is ready to be tucked away, softly and proudly.';
    }
    if (snapshot.mode == 'break') {
      return _breakDetailMessages[snapshot.combinedSessionSeconds.abs() %
          _breakDetailMessages.length];
    }
    return _focusDetailMessages[snapshot.sessionStudySeconds.abs() %
        _focusDetailMessages.length];
  }
}

String formatStudyBuddyDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours <= 0) {
    final totalMinutes = duration.inMinutes;
    return '$totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
  }
  if (minutes == 0) {
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  return '$hours hour${hours == 1 ? '' : 's'} and $minutes minute${minutes == 1 ? '' : 's'}';
}

const List<String> _focusDetailMessages = <String>[
  'You’re floating well today 🫧',
  'Your brain’s been trying so gently today 💭',
  'There’s something lovely about how steadily you’re staying with this 🌷',
];

const List<String> _breakDetailMessages = <String>[
  'A little pause can help your thoughts settle 🌙',
  'Rest can still be part of the work, little by little 🫧',
  'You’re allowed to soften into this break for a moment 💭',
];
