const Set<String> localFirstTemplateKeys = <String>{
  'bills',
  'books',
  'cycle',
  'expenses',
  'fast',
  'income',
  'meditation',
  'movies',
  'places',
  'restaurants',
  'skin_care',
  'social',
  'tv_log',
  'wishlist',
  'workout',
  'mood',
  'sleep',
  'water',
  'study',
  'tasks',
  'meals',
  'medication',
};

bool isLocalFirstTemplateKey(String templateKey) {
  return localFirstTemplateKeys.contains(templateKey.trim().toLowerCase());
}

String localFirstLogTableName(String templateKey) {
  switch (templateKey.trim().toLowerCase()) {
    case 'goals':
      return 'goal_logs';
    case 'water':
      return 'water_logs';
    case 'sleep':
      return 'sleep_logs';
    case 'medication':
      return 'medication_logs';
    case 'meals':
      return 'meals_logs';
    case 'cycle':
      return 'menstrual_logs';
    case 'books':
      return 'book_logs';
    case 'income':
      return 'income_logs';
    case 'wishlist':
      return 'wishlist';
    case 'restaurants':
      return 'restaurant_logs';
    case 'movies':
      return 'movie_logs';
    case 'bills':
      return 'bill_logs';
    case 'expenses':
      return 'expense_logs';
    case 'places':
      return 'place_logs';
    case 'tasks':
      return 'task_logs';
    case 'fast':
      return 'fast_logs';
    case 'meditation':
      return 'meditation_logs';
    case 'skin_care':
      return 'skin_care_logs';
    case 'social':
      return 'social_logs';
    case 'study':
      return 'study_logs';
    case 'workout':
      return 'workout_logs';
    case 'tv_log':
      return 'tv_logs';
    case 'mood':
      return 'mood_logs';
    case 'symptoms':
      return 'symptom_logs';
    default:
      return '${templateKey.trim().toLowerCase()}_logs';
  }
}
