class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.morningMessages,
    required this.eveningMessages,
  });

  final String id;
  final String title;
  final String description;
  final String subtitle;
  final List<String> morningMessages;
  final List<String> eveningMessages;
}

const List<NotificationCategory> notificationCategories = [
  NotificationCategory(
    id: 'journal',
    title: 'Journal',
    description: 'A place to put today into words',
    subtitle: 'Journal',
    morningMessages: [
      'Want a place to put today into words, messy is welcome.',
      'You do not have to write much. Even one line counts.',
      'If your thoughts feel crowded, journaling can hold them for a moment.',
    ],
    eveningMessages: [
      'Before today fades, want to leave yourself a note?',
      'What would you like to remember about today, or let go of?',
    ],
  ),
  NotificationCategory(
    id: 'journal_memory',
    title: 'Memories',
    description: 'Save a moment with photos or video',
    subtitle: 'Memories',
    morningMessages: [
      'Something just happened. Want to save it for future-you?',
      'This might be worth remembering, even if it is small.',
    ],
    eveningMessages: [
      'A photo does not have to be pretty to be meaningful.',
      'Memories do not have to be happy to matter.',
      'If today had one image, what would it be?',
      'Want to leave a visual bookmark for this moment?',
    ],
  ),
  NotificationCategory(
    id: 'vent',
    title: 'Vent',
    description: 'A private place to unload',
    subtitle: 'Vent bubble',
    morningMessages: [
      'You do not have to make sense here. Just let it out.',
      'This is a space with no reactions, no fixing, no judgment.',
    ],
    eveningMessages: [
      'If you need to unload without explaining yourself, I am here.',
      'Say the thing you would not say out loud.',
      'Big feelings are allowed here. You are not too much.',
    ],
  ),
  NotificationCategory(
    id: 'brainfog',
    title: 'Brainfog',
    description: 'A gentle brain dump',
    subtitle: 'Brainfog bubble',
    morningMessages: [
      'If your thoughts feel tangled, we can sort them gently.',
      'You do not have to hold everything in your head.',
      'This is just a brain dump. No organizing required.',
    ],
    eveningMessages: [
      'Put it here so your mind can rest for a minute.',
      'Feeling scattered? Let us empty the mental tabs.',
    ],
  ),
  NotificationCategory(
    id: 'insights',
    title: 'Insights',
    description: 'Notice a pattern without judging it',
    subtitle: 'Insights',
    morningMessages: [
      'Want to notice a pattern without judging it?',
      'Sometimes insight is just noticing, not fixing.',
      'There is no right or wrong insight. Only awareness.',
    ],
    eveningMessages: [
      'Understanding yourself can be slow and kind.',
      'You have been showing up lately. Want to see what that reveals?',
    ],
  ),
  NotificationCategory(
    id: 'soft_combo',
    title: 'Mind Buddy',
    description: 'A gentle nudge, if you want it',
    subtitle: 'Mind Buddy',
    morningMessages: [
      'You do not have to carry today alone.',
      'A few minutes of honesty can change how the day settles.',
      'If something has been looping in your mind, there is a place for it.',
      'You can use this space quietly, no effort required.',
    ],
    eveningMessages: [
      'You do not have to carry today alone.',
      'A few minutes of honesty can change how the day settles.',
      'If something has been looping in your mind, there is a place for it.',
      'You can use this space quietly, no effort required.',
    ],
  ),
  NotificationCategory(
    id: 'mood',
    title: 'Mood',
    description: 'Log how you feel today',
    subtitle: 'Mood',
    morningMessages: [
      'How are you arriving today, even if it is messy?',
    ],
    eveningMessages: [
      'Want to check in with how today actually felt?',
    ],
  ),
  NotificationCategory(
    id: 'sleep',
    title: 'Sleep',
    description: 'Check in with your sleep',
    subtitle: 'Sleep',
    morningMessages: [
      'Did you feel rested, or just awake?',
    ],
    eveningMessages: [
      'Your body might be ready to slow down. No pressure.',
    ],
  ),
  NotificationCategory(
    id: 'water',
    title: 'Water',
    description: 'Log your water',
    subtitle: 'Water',
    morningMessages: [
      'Tiny reminder to sip, not chug.',
    ],
    eveningMessages: [
      'If you have not had water yet, this is your soft nudge.',
    ],
  ),
  NotificationCategory(
    id: 'meditation',
    title: 'Meditation',
    description: 'Open a quiet moment',
    subtitle: 'Meditation',
    morningMessages: [
      'One quiet minute counts too.',
    ],
    eveningMessages: [
      'You do not have to clear your mind, just sit with it.',
    ],
  ),
  NotificationCategory(
    id: 'goals',
    title: 'Goals',
    description: 'Choose one gentle priority',
    subtitle: 'Goals',
    morningMessages: [
      'One small thing that matters today is enough.',
    ],
    eveningMessages: [
      'Want to choose one gentle priority?',
    ],
  ),
  NotificationCategory(
    id: 'tasks',
    title: 'Tasks',
    description: 'Log tasks',
    subtitle: 'Tasks',
    morningMessages: [
      'What is the kindest thing to cross off today?',
    ],
    eveningMessages: [
      'If you stop now, that is still okay.',
    ],
  ),
  NotificationCategory(
    id: 'study',
    title: 'Study',
    description: 'Open your study space',
    subtitle: 'Study',
    morningMessages: [
      'Ten focused minutes is still progress.',
    ],
    eveningMessages: [
      'Only if it feels right, want to open your study space?',
    ],
  ),
  NotificationCategory(
    id: 'workout',
    title: 'Workout',
    description: 'Log movement',
    subtitle: 'Workout',
    morningMessages: [
      'Movement can be soft today.',
    ],
    eveningMessages: [
      'Stretching counts. Rest counts too.',
    ],
  ),
  NotificationCategory(
    id: 'fast',
    title: 'Fast',
    description: 'Check in with food and fasting',
    subtitle: 'Fast',
    morningMessages: [
      'Check in with your body. What does it need right now?',
    ],
    eveningMessages: [
      'No pressure, just a gentle check in.',
    ],
  ),
  NotificationCategory(
    id: 'skin_care',
    title: 'Skin Care',
    description: 'A small moment of care',
    subtitle: 'Skin care',
    morningMessages: [
      'A small moment of care, just for you.',
    ],
    eveningMessages: [
      'If it helps, your skin care space is here.',
    ],
  ),
  NotificationCategory(
    id: 'expenses',
    title: 'Expenses',
    description: 'Log expenses',
    subtitle: 'Expenses',
    morningMessages: [
      'Want a quick glance at today’s numbers?',
    ],
    eveningMessages: [
      'Information only, no judgment here.',
    ],
  ),
  NotificationCategory(
    id: 'income',
    title: 'Income',
    description: 'Log income',
    subtitle: 'Income',
    morningMessages: [
      'Want a quick glance at today’s numbers?',
    ],
    eveningMessages: [
      'Information only, no judgment here.',
    ],
  ),
  NotificationCategory(
    id: 'bills',
    title: 'Bills',
    description: 'Log bills',
    subtitle: 'Bills',
    morningMessages: [
      'Want to check in on bills, just for clarity?',
    ],
    eveningMessages: [
      'Information only, no judgment here.',
    ],
  ),
  NotificationCategory(
    id: 'social',
    title: 'Social',
    description: 'Log social moments',
    subtitle: 'Social',
    morningMessages: [
      'Who felt safe to talk to lately?',
    ],
    eveningMessages: [
      'Even thinking about connection counts.',
    ],
  ),
  NotificationCategory(
    id: 'places',
    title: 'Places',
    description: 'Log places',
    subtitle: 'Places',
    morningMessages: [
      'Want to log something that brought you a little joy?',
    ],
    eveningMessages: [
      'Want to log something that brought you a little joy?',
    ],
  ),
  NotificationCategory(
    id: 'restaurants',
    title: 'Restaurants',
    description: 'Log a restaurant',
    subtitle: 'Restaurants',
    morningMessages: [
      'Want to log something that brought you a little joy?',
    ],
    eveningMessages: [
      'Want to log something that brought you a little joy?',
    ],
  ),
  NotificationCategory(
    id: 'movies',
    title: 'Movie Log',
    description: 'Log a movie',
    subtitle: 'Movies',
    morningMessages: [
      'Want to log something that brought you a little joy?',
    ],
    eveningMessages: [
      'Want to log something that brought you a little joy?',
    ],
  ),
  NotificationCategory(
    id: 'tv',
    title: 'TV Log',
    description: 'Log a TV show',
    subtitle: 'TV log',
    morningMessages: [
      'Want to log something that brought you a little joy?',
    ],
    eveningMessages: [
      'Want to log something that brought you a little joy?',
    ],
  ),
  NotificationCategory(
    id: 'books',
    title: 'Books',
    description: 'Log a book',
    subtitle: 'Books',
    morningMessages: [
      'Want to log something that brought you a little joy?',
    ],
    eveningMessages: [
      'Want to log something that brought you a little joy?',
    ],
  ),
  NotificationCategory(
    id: 'wishlist',
    title: 'Wishlist',
    description: 'Add something you want',
    subtitle: 'Wishlist',
    morningMessages: [
      'It is okay to want things.',
    ],
    eveningMessages: [
      'It is okay to want things.',
    ],
  ),
];

Map<String, bool> defaultNotificationCategoryState() {
  return {
    for (final category in notificationCategories) category.id: true,
  };
}
