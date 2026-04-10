const moodOptions = <String>[
  '😊 Happy',
  '🤩 Excited',
  '😎 Confident',
  '🧘 Calm',
  '😐 Neutral',
  '😔 Sad',
  '😤 Angry',
  '🤯 Stressed',
  '🤔 Anxious',
  '😴 Tired',
  '🤒 Sick',
];

const moodOptionsWithOther = <String>[...moodOptions, 'Other'];

enum MoodTone { positive, neutral, negative }

String canonicalMood(dynamic rawMood) {
  final input = (rawMood ?? '').toString().trim();
  if (input.isEmpty) return '';
  final normalized = input
      .replaceAll(RegExp(r'^[^\w]+'), '')
      .toLowerCase()
      .trim();
  for (final option in moodOptionsWithOther) {
    final key = option.replaceAll(RegExp(r'^[^\w]+'), '').toLowerCase().trim();
    if (normalized == key ||
        normalized.contains(key) ||
        key.contains(normalized)) {
      return option;
    }
  }
  return 'Other';
}

String displayMood(String moodOption) {
  if (moodOption.isEmpty) return 'Unknown';
  return moodOption.replaceAll(RegExp(r'^[^\w]+'), '').trim();
}

String moodEmoji(String moodOption) {
  final match = RegExp(r'^[^\w]+').firstMatch(moodOption);
  if (match == null) return '🙂';
  return moodOption.substring(0, match.end).trim();
}

MoodTone moodToneOf(String moodOption) {
  final key = displayMood(moodOption).toLowerCase();
  if (key.contains('happy') ||
      key.contains('excited') ||
      key.contains('confident') ||
      key.contains('calm')) {
    return MoodTone.positive;
  }
  if (key.contains('neutral') || key.contains('other')) {
    return MoodTone.neutral;
  }
  return MoodTone.negative;
}

bool isPositiveMood(String moodOption) =>
    moodToneOf(moodOption) == MoodTone.positive;

bool isNegativeMood(String moodOption) =>
    moodToneOf(moodOption) == MoodTone.negative;

bool isNeutralMood(String moodOption) =>
    moodToneOf(moodOption) == MoodTone.neutral;
