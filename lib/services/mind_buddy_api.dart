import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MindBuddyEnhancedApi {
  final String apiKey;

  MindBuddyEnhancedApi({required this.apiKey});

  // ============================================
  // AVAILABLE FUNCTIONS FOR OPENAI
  // ============================================

  List<Map<String, dynamic>> get availableFunctions => [
    // REMINDERS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_reminder',
        'description': 'Add a reminder to the calendar',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Reminder title'},
            'date': {
              'type': 'string',
              'description': 'Date in YYYY-MM-DD format',
            },
            'time': {
              'type': 'string',
              'description': 'Time in HH:MM format (24-hour), optional',
            },
            'notes': {
              'type': 'string',
              'description': 'Additional notes, optional',
            },
          },
          'required': ['title', 'date'],
        },
      },
    },

    // REMINDERS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_reminder',
        'description': 'Update reminder date or time',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Reminder title'},
            'new_date': {
              'type': 'string',
              'description': 'New date YYYY-MM-DD',
            },
            'new_time': {'type': 'string', 'description': 'New time HH:MM'},
          },
          'required': ['title'],
        },
      },
    },

    // REMINDERS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_reminder',
        'description': 'Delete a reminder',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Reminder title'},
          },
          'required': ['title'],
        },
      },
    },

    // MOODS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_mood',
        'description': 'Log user\'s mood',
        'parameters': {
          'type': 'object',
          'properties': {
            'mood': {
              'type': 'string',
              'enum': [
                'happy',
                'sad',
                'anxious',
                'calm',
                'energetic',
                'tired',
                'angry',
                'content',
                'stressed',
                'excited',
                'other',
              ],
              'description': 'User\'s mood',
            },
            'intensity': {'type': 'number', 'description': 'Intensity 1-10'},
            'notes': {'type': 'string', 'description': 'Notes'},
            'date': {
              'type': 'string',
              'description': 'Date YYYY-MM-DD (defaults to today)',
            },
          },
          'required': ['mood'],
        },
      },
    },

    // MOODS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_mood_log',
        'description': 'Update mood log',
        'parameters': {
          'type': 'object',
          'properties': {
            'mood': {'type': 'string', 'description': 'New mood'},
            'intensity': {
              'type': 'number',
              'description': 'New intensity 1-10',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['mood'],
        },
      },
    },

    // MOODS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_mood_log',
        'description': 'Delete mood log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': [],
        },
      },
    },

    // HABITS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_habit',
        'description': 'Log habit completion',
        'parameters': {
          'type': 'object',
          'properties': {
            'habit_name': {'type': 'string', 'description': 'Habit name'},
            'completed': {
              'type': 'boolean',
              'description': 'Whether completed',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['habit_name', 'completed'],
        },
      },
    },

    // HABITS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_habit_log',
        'description': 'Update habit status',
        'parameters': {
          'type': 'object',
          'properties': {
            'habit_name': {'type': 'string', 'description': 'Habit name'},
            'completed': {'type': 'boolean', 'description': 'New status'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['habit_name', 'completed'],
        },
      },
    },

    // HABITS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_habit_log',
        'description': 'Delete habit log',
        'parameters': {
          'type': 'object',
          'properties': {
            'habit_name': {'type': 'string', 'description': 'Habit name'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['habit_name'],
        },
      },
    },

    // WATER - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_water',
        'description': 'Log water intake',
        'parameters': {
          'type': 'object',
          'properties': {
            'amount_ml': {'type': 'number', 'description': 'Amount in ml'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['amount_ml'],
        },
      },
    },

    // WATER - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_water_log',
        'description': 'Update water intake amount',
        'parameters': {
          'type': 'object',
          'properties': {
            'amount_ml': {'type': 'number', 'description': 'New amount in ml'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['amount_ml'],
        },
      },
    },

    // WATER - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_water_log',
        'description': 'Delete water log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': [],
        },
      },
    },

    // BILLS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_bill',
        'description': 'Add a bill',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Bill name'},
            'amount': {'type': 'number', 'description': 'Amount'},
            'due_date': {
              'type': 'string',
              'description': 'Due date YYYY-MM-DD',
            },
            'paid': {
              'type': 'boolean',
              'description': 'Already paid? (default false)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['name', 'amount', 'due_date'],
        },
      },
    },

    // BILLS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_bill',
        'description': 'Update bill status or amount',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Bill name'},
            'paid': {'type': 'boolean', 'description': 'New paid status'},
            'amount': {'type': 'number', 'description': 'New amount'},
            'due_date': {'type': 'string', 'description': 'Bill due date'},
          },
          'required': ['name', 'due_date'],
        },
      },
    },

    // BILLS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_bill',
        'description': 'Delete a bill',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Bill name'},
            'due_date': {'type': 'string', 'description': 'Due date'},
          },
          'required': ['name', 'due_date'],
        },
      },
    },

    // BOOKS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_book',
        'description': 'Log a book',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Book title'},
            'author': {'type': 'string', 'description': 'Author'},
            'rating': {
              'type': 'number',
              'description': 'Rating 1-5',
              'minimum': 1,
              'maximum': 5,
            },
            'status': {
              'type': 'string',
              'enum': ['reading', 'completed', 'want_to_read'],
              'description': 'Status',
            },
            'date': {'type': 'string', 'description': 'Date YYYY-MM-DD'},
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['title'],
        },
      },
    },

    // BOOKS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_book_log',
        'description': 'Update book rating or status',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Book title'},
            'rating': {'type': 'number', 'description': 'New rating 1-5'},
            'status': {'type': 'string', 'description': 'New status'},
          },
          'required': ['title'],
        },
      },
    },

    // BOOKS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_book_log',
        'description': 'Delete book log',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Book title'},
          },
          'required': ['title'],
        },
      },
    },

    // CYCLE - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_cycle',
        'description': 'Log menstrual cycle info',
        'parameters': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['period_start', 'period_end', 'ovulation', 'symptoms'],
              'description': 'Type',
            },
            'date': {'type': 'string', 'description': 'Date YYYY-MM-DD'},
            'symptoms': {'type': 'string', 'description': 'Symptoms'},
            'flow': {
              'type': 'string',
              'enum': ['light', 'medium', 'heavy'],
              'description': 'Flow level',
            },
          },
          'required': ['type', 'date'],
        },
      },
    },

    // CYCLE - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_cycle_log',
        'description': 'Update cycle flow or symptoms',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
            'flow': {
              'type': 'string',
              'enum': ['light', 'medium', 'heavy'],
              'description': 'New flow',
            },
            'symptoms': {'type': 'string', 'description': 'New symptoms'},
          },
          'required': ['date'],
        },
      },
    },

    // CYCLE - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_cycle_log',
        'description': 'Delete cycle log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },

    // EXPENSES - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_expense',
        'description': 'Add an expense',
        'parameters': {
          'type': 'object',
          'properties': {
            'description': {
              'type': 'string',
              'description': 'What was purchased',
            },
            'amount': {'type': 'number', 'description': 'Amount spent'},
            'category': {
              'type': 'string',
              'enum': [
                'food',
                'transport',
                'entertainment',
                'health',
                'shopping',
                'bills',
                'other',
              ],
              'description': 'Category',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
          },
          'required': ['description', 'amount'],
        },
      },
    },

    // EXPENSES - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_expense',
        'description': 'Update expense amount or category',
        'parameters': {
          'type': 'object',
          'properties': {
            'description': {
              'type': 'string',
              'description': 'Expense description',
            },
            'amount': {'type': 'number', 'description': 'New amount'},
            'category': {'type': 'string', 'description': 'New category'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['description', 'date'],
        },
      },
    },

    // EXPENSES - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_expense',
        'description': 'Delete expense',
        'parameters': {
          'type': 'object',
          'properties': {
            'description': {
              'type': 'string',
              'description': 'Expense description',
            },
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['description', 'date'],
        },
      },
    },

    // INCOME - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_income',
        'description': 'Add income',
        'parameters': {
          'type': 'object',
          'properties': {
            'source': {'type': 'string', 'description': 'Income source'},
            'amount': {'type': 'number', 'description': 'Amount'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['source', 'amount'],
        },
      },
    },

    // INCOME - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_income',
        'description': 'Update income amount',
        'parameters': {
          'type': 'object',
          'properties': {
            'source': {'type': 'string', 'description': 'Income source'},
            'amount': {'type': 'number', 'description': 'New amount'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['source', 'amount', 'date'],
        },
      },
    },

    // INCOME - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_income',
        'description': 'Delete income entry',
        'parameters': {
          'type': 'object',
          'properties': {
            'source': {'type': 'string', 'description': 'Income source'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['source', 'date'],
        },
      },
    },

    // FASTING - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_fast',
        'description': 'Log fasting period',
        'parameters': {
          'type': 'object',
          'properties': {
            'start_time': {
              'type': 'string',
              'description': 'Start time ISO 8601',
            },
            'end_time': {'type': 'string', 'description': 'End time ISO 8601'},
            'type': {
              'type': 'string',
              'enum': ['intermittent', 'water', 'dry', 'other'],
              'description': 'Type',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['start_time', 'end_time'],
        },
      },
    },

    // FASTING - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_fast_log',
        'description': 'Update fasting duration or feeling',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
            'duration_hours': {'type': 'number', 'description': 'New duration'},
            'feeling': {'type': 'string', 'description': 'How they feel'},
          },
          'required': ['date'],
        },
      },
    },

    // FASTING - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_fast_log',
        'description': 'Delete fasting log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },

    // SLEEP - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_sleep',
        'description': 'Log sleep',
        'parameters': {
          'type': 'object',
          'properties': {
            'bedtime': {'type': 'string', 'description': 'Bedtime ISO 8601'},
            'wake_time': {
              'type': 'string',
              'description': 'Wake time ISO 8601',
            },
            'quality': {
              'type': 'string',
              'enum': ['poor', 'fair', 'good', 'excellent'],
              'description': 'Quality',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['bedtime', 'wake_time'],
        },
      },
    },

    // SLEEP - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_sleep_log',
        'description': 'Update sleep quality',
        'parameters': {
          'type': 'object',
          'properties': {
            'quality': {'type': 'string', 'description': 'New quality'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['quality', 'date'],
        },
      },
    },

    // SLEEP - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_sleep_log',
        'description': 'Delete sleep log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },

    // TASKS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_task',
        'description': 'Add a task',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Task title'},
            'due_date': {
              'type': 'string',
              'description': 'Due date YYYY-MM-DD',
            },
            'priority': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
              'description': 'Priority',
            },
            'completed': {'type': 'boolean', 'description': 'Completed?'},
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['title'],
        },
      },
    },

    // TASKS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_task',
        'description': 'Update task status or priority',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Task title'},
            'completed': {'type': 'boolean', 'description': 'New status'},
            'priority': {'type': 'string', 'description': 'New priority'},
          },
          'required': ['title'],
        },
      },
    },

    // TASKS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_task',
        'description': 'Delete a task',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Task title'},
          },
          'required': ['title'],
        },
      },
    },

    // WISHLIST - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_wishlist_item',
        'description': 'Add item to wishlist',
        'parameters': {
          'type': 'object',
          'properties': {
            'item': {'type': 'string', 'description': 'Item name'},
            'price': {'type': 'number', 'description': 'Price'},
            'priority': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
              'description': 'Priority',
            },
            'link': {'type': 'string', 'description': 'URL'},
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['item'],
        },
      },
    },

    // WISHLIST - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_wishlist_item',
        'description': 'Update wishlist item',
        'parameters': {
          'type': 'object',
          'properties': {
            'item': {'type': 'string', 'description': 'Item name'},
            'price': {'type': 'number', 'description': 'New price'},
            'priority': {'type': 'string', 'description': 'New priority'},
          },
          'required': ['item'],
        },
      },
    },

    // WISHLIST - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_wishlist_item',
        'description': 'Delete wishlist item',
        'parameters': {
          'type': 'object',
          'properties': {
            'item': {'type': 'string', 'description': 'Item name'},
          },
          'required': ['item'],
        },
      },
    },

    // MOVIES - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_movie',
        'description': 'Log a movie watched',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Movie title'},
            'rating': {
              'type': 'number',
              'description': 'Rating 1-5',
              'minimum': 1,
              'maximum': 5,
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'review': {'type': 'string', 'description': 'Review'},
            'genre': {'type': 'string', 'description': 'Genre'},
          },
          'required': ['title'],
        },
      },
    },

    // MOVIES - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_movie_log',
        'description': 'Update movie rating or review',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Movie title'},
            'rating': {'type': 'number', 'description': 'New rating 1-5'},
            'review': {'type': 'string', 'description': 'New review'},
          },
          'required': ['title'],
        },
      },
    },

    // MOVIES - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_movie_log',
        'description': 'Delete movie log',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Movie title'},
          },
          'required': ['title'],
        },
      },
    },

    // TV SHOWS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_tv_show',
        'description': 'Log TV show watched',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Show title'},
            'season': {'type': 'number', 'description': 'Season number'},
            'episode': {'type': 'number', 'description': 'Episode number'},
            'rating': {'type': 'number', 'description': 'Rating 1-5'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'review': {'type': 'string', 'description': 'Review'},
          },
          'required': ['title'],
        },
      },
    },

    // TV SHOWS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_tv_log',
        'description': 'Update TV show rating',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Show title'},
            'rating': {'type': 'number', 'description': 'New rating 1-5'},
          },
          'required': ['title'],
        },
      },
    },

    // TV SHOWS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_tv_log',
        'description': 'Delete TV show log',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Show title'},
          },
          'required': ['title'],
        },
      },
    },

    // PLACES - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_place',
        'description': 'Log place visited',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Place name'},
            'location': {'type': 'string', 'description': 'Location'},
            'rating': {'type': 'number', 'description': 'Rating 1-5'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
            'category': {
              'type': 'string',
              'enum': ['cafe', 'park', 'museum', 'landmark', 'nature', 'other'],
              'description': 'Category',
            },
          },
          'required': ['name'],
        },
      },
    },

    // PLACES - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_place_log',
        'description': 'Update place rating or notes',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Place name'},
            'rating': {'type': 'number', 'description': 'New rating 1-5'},
            'notes': {'type': 'string', 'description': 'New notes'},
          },
          'required': ['name'],
        },
      },
    },

    // PLACES - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_place_log',
        'description': 'Delete place log',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Place name'},
          },
          'required': ['name'],
        },
      },
    },

    // RESTAURANTS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_restaurant',
        'description': 'Log restaurant visited',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Restaurant name'},
            'location': {'type': 'string', 'description': 'Location'},
            'cuisine': {'type': 'string', 'description': 'Cuisine type'},
            'rating': {'type': 'number', 'description': 'Rating 1-5'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'dish': {'type': 'string', 'description': 'Dish ordered'},
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['name'],
        },
      },
    },

    // RESTAURANTS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_restaurant_log',
        'description': 'Update restaurant rating or notes',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Restaurant name'},
            'rating': {'type': 'number', 'description': 'New rating 1-5'},
            'notes': {'type': 'string', 'description': 'New notes'},
          },
          'required': ['name'],
        },
      },
    },

    // RESTAURANTS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_restaurant_log',
        'description': 'Delete restaurant log',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Restaurant name'},
          },
          'required': ['name'],
        },
      },
    },

    // MEDITATION - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_meditation',
        'description': 'Log meditation session',
        'parameters': {
          'type': 'object',
          'properties': {
            'duration_minutes': {
              'type': 'number',
              'description': 'Duration in minutes',
            },
            'technique': {'type': 'string', 'description': 'Technique used'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['duration_minutes'],
        },
      },
    },

    // MEDITATION - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_meditation_log',
        'description': 'Update meditation duration',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
            'duration_minutes': {
              'type': 'number',
              'description': 'New duration',
            },
          },
          'required': ['date', 'duration_minutes'],
        },
      },
    },

    // MEDITATION - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_meditation_log',
        'description': 'Delete meditation log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },

    // GOALS - ADD
    {
      'type': 'function',
      'function': {
        'name': 'add_goal',
        'description': 'Add a goal',
        'parameters': {
          'type': 'object',
          'properties': {
            'goal_title': {'type': 'string', 'description': 'Goal title'},
            'category': {'type': 'string', 'description': 'Category'},
            'target_date': {
              'type': 'string',
              'description': 'Target date YYYY-MM-DD',
            },
            'is_completed': {'type': 'boolean', 'description': 'Completed?'},
            'priority': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
              'description': 'Priority',
            },
          },
          'required': ['goal_title'],
        },
      },
    },

    // GOALS - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_goal',
        'description': 'Update goal status',
        'parameters': {
          'type': 'object',
          'properties': {
            'goal_title': {'type': 'string', 'description': 'Goal title'},
            'is_completed': {'type': 'boolean', 'description': 'Completed?'},
          },
          'required': ['goal_title'],
        },
      },
    },

    // GOALS - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_goal',
        'description': 'Delete a goal',
        'parameters': {
          'type': 'object',
          'properties': {
            'goal_title': {'type': 'string', 'description': 'Goal title'},
          },
          'required': ['goal_title'],
        },
      },
    },

    // WORKOUT - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_workout',
        'description': 'Log workout session',
        'parameters': {
          'type': 'object',
          'properties': {
            'exercise': {'type': 'string', 'description': 'Exercise name'},
            'sets': {'type': 'number', 'description': 'Number of sets'},
            'reps': {'type': 'number', 'description': 'Reps per set'},
            'weight_kg': {'type': 'number', 'description': 'Weight in kg'},
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['exercise'],
        },
      },
    },

    // WORKOUT - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_workout_log',
        'description': 'Update workout sets, reps, or weight',
        'parameters': {
          'type': 'object',
          'properties': {
            'exercise': {'type': 'string', 'description': 'Exercise name'},
            'date': {'type': 'string', 'description': 'Date'},
            'sets': {'type': 'number', 'description': 'New sets'},
            'reps': {'type': 'number', 'description': 'New reps'},
            'weight_kg': {'type': 'number', 'description': 'New weight'},
          },
          'required': ['exercise', 'date'],
        },
      },
    },

    // WORKOUT - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_workout_log',
        'description': 'Delete workout log',
        'parameters': {
          'type': 'object',
          'properties': {
            'exercise': {'type': 'string', 'description': 'Exercise name'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['exercise', 'date'],
        },
      },
    },

    // SKIN CARE - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_skin_care',
        'description': 'Log skin care routine',
        'parameters': {
          'type': 'object',
          'properties': {
            'routine_type': {
              'type': 'string',
              'description': 'Morning/Evening routine',
            },
            'products': {'type': 'string', 'description': 'Products used'},
            'skin_condition': {
              'type': 'string',
              'description': 'Skin condition',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['routine_type'],
        },
      },
    },

    // SKIN CARE - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_skin_care_log',
        'description': 'Update skin care routine or condition',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
            'skin_condition': {
              'type': 'string',
              'description': 'New condition',
            },
            'products': {'type': 'string', 'description': 'New products'},
          },
          'required': ['date'],
        },
      },
    },

    // SKIN CARE - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_skin_care_log',
        'description': 'Delete skin care log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },

    // STUDY - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_study',
        'description': 'Log study session',
        'parameters': {
          'type': 'object',
          'properties': {
            'subject': {'type': 'string', 'description': 'Subject studied'},
            'duration_hours': {
              'type': 'number',
              'description': 'Duration in hours',
            },
            'focus_rating': {
              'type': 'number',
              'description': 'Focus rating 1-10',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['subject', 'duration_hours'],
        },
      },
    },

    // STUDY - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_study_log',
        'description': 'Update study duration or focus rating',
        'parameters': {
          'type': 'object',
          'properties': {
            'subject': {'type': 'string', 'description': 'Subject'},
            'date': {'type': 'string', 'description': 'Date'},
            'duration_hours': {'type': 'number', 'description': 'New duration'},
            'focus_rating': {
              'type': 'number',
              'description': 'New focus rating 1-10',
            },
          },
          'required': ['subject', 'date'],
        },
      },
    },

    // STUDY - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_study_log',
        'description': 'Delete study log',
        'parameters': {
          'type': 'object',
          'properties': {
            'subject': {'type': 'string', 'description': 'Subject'},
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['subject', 'date'],
        },
      },
    },

    // SOCIAL - ADD
    {
      'type': 'function',
      'function': {
        'name': 'log_social',
        'description': 'Log social activity',
        'parameters': {
          'type': 'object',
          'properties': {
            'person_event': {
              'type': 'string',
              'description': 'Person met or event attended',
            },
            'activity_type': {'type': 'string', 'description': 'Activity type'},
            'social_energy': {
              'type': 'number',
              'description': 'Energy level 1-10',
            },
            'date': {
              'type': 'string',
              'description': 'Date (defaults to today)',
            },
            'notes': {'type': 'string', 'description': 'Notes'},
          },
          'required': ['person_event'],
        },
      },
    },

    // SOCIAL - UPDATE
    {
      'type': 'function',
      'function': {
        'name': 'update_social_log',
        'description': 'Update social energy or activity type',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
            'social_energy': {
              'type': 'number',
              'description': 'New energy level 1-10',
            },
            'activity_type': {
              'type': 'string',
              'description': 'New activity type',
            },
          },
          'required': ['date'],
        },
      },
    },

    // SOCIAL - DELETE
    {
      'type': 'function',
      'function': {
        'name': 'delete_social_log',
        'description': 'Delete social log',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Date'},
          },
          'required': ['date'],
        },
      },
    },
  ];

  // ============================================
  // SEND MESSAGE WITH FUNCTION CALLING
  // ============================================

  Future<String> sendMessage(
    String message,
    List<Map<String, dynamic>> conversationHistory,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo-preview',
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a helpful wellbeing assistant for Mind Buddy app. 

TODAY'S DATE: ${DateTime.now().toIso8601String().split('T')[0]} (January 30, 2026)
CURRENT YEAR: 2026

CRITICAL DATE HANDLING RULES:
- When user says "today", use: ${DateTime.now().toIso8601String().split('T')[0]}
- When user says "yesterday", use: ${DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0]}
- When user mentions a month/day without a year (e.g., "December 10th"), ALWAYS assume it's in the current year (2026) or the most recent occurrence
- NEVER use dates from 2023 or other past years unless explicitly stated
- Always use YYYY-MM-DD format for dates
- Default to today's date if no date is mentioned

MOOD MATCHING:
- Match user's mood description to closest enum value
- Examples: "over the moon" → "happy", "feeling down" → "sad", "worried" → "anxious"
- If unsure, use "other"

CONFIRMATION BEFORE LOGGING:
- When interpreting unclear, ambiguous, or informal user input, FIRST confirm your understanding before calling any functions
- Ask: "Just to confirm, you want me to log [activity] with [details] for [date]? Should I go ahead?"
- Examples that need confirmation:
  * Typos: "i also meditaded for 10 mins" → Confirm: "meditation for 10 minutes"
  * Informal: "did 30 min cardio" → Confirm: "cardio workout for 30 minutes"
  * Ambiguous dates: "2 days ago" → Confirm: "January 28th, 2026"
  * Missing details: "read 48 Laws of power up until page 31" → Confirm book title, author if known, and ask if they want to track page number in notes
- Only call functions AFTER user confirms with "yes", "correct", "yep", "yeah", etc.
- If user says "no" or corrects you, adjust and ask for confirmation again
- For very clear requests (like "log 500ml water"), you can proceed without confirmation

When users mention logging, updating, or deleting activities (movies, habits, moods, water, etc.), use the appropriate function.
Be conversational and encouraging. Confirm what you've logged/updated/deleted.''',
            },
            ...conversationHistory,
            {'role': 'user', 'content': message},
          ],
          'tools': availableFunctions,
          'tool_choice': 'auto',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI API error: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final choice = data['choices'][0];

      // Check if AI wants to call functions
      if (choice['message']['tool_calls'] != null) {
        return await _handleFunctionCalls(
          choice['message']['tool_calls'],
          conversationHistory,
          choice['message'],
        );
      }

      // Regular text response
      return choice['message']['content'] ?? 'No response';
    } catch (e) {
      return 'Sorry, I encountered an error: $e';
    }
  }

  // ============================================
  // HANDLE FUNCTION CALLS
  // ============================================

  Future<String> _handleFunctionCalls(
    List<dynamic> toolCalls,
    List<Map<String, dynamic>> conversationHistory,
    Map<String, dynamic> assistantMessage,
  ) async {
    final functionResults = <Map<String, dynamic>>[];

    // Execute all function calls
    for (final toolCall in toolCalls) {
      final functionName = toolCall['function']['name'];
      final arguments = jsonDecode(toolCall['function']['arguments']);

      final result = await _executeFunction(functionName, arguments);

      functionResults.add({
        'tool_call_id': toolCall['id'],
        'role': 'tool',
        'name': functionName,
        'content': jsonEncode(result),
      });
    }

    // Send results back to OpenAI for final response
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4-turbo-preview',
        'messages': [
          ...conversationHistory,
          assistantMessage,
          ...functionResults,
        ],
      }),
    );

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? 'Done!';
  }

  // ============================================
  // EXECUTE FUNCTIONS
  // ============================================

  Future<Map<String, dynamic>> _executeFunction(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    // Helper to get today's date in YYYY-MM-DD
    String getDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) {
        return DateTime.now().toIso8601String().split('T')[0];
      }
      return dateStr;
    }

    try {
      switch (functionName) {
        // REMINDERS - ADD
        case 'add_reminder':
          final datetime = args['time'] != null
              ? '${args['date']}T${args['time']}:00'
              : '${args['date']}T09:00:00';

          await supabase.from('calendar_events').insert({
            'user_id': user.id,
            'type': 'reminder',
            'title': args['title'],
            'datetime': datetime,
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Reminder set'};

        // REMINDERS - UPDATE
        case 'update_reminder':
          final updateReminderData = <String, dynamic>{};
          if (args['new_date'] != null || args['new_time'] != null) {
            final newDate = args['new_date'] ?? getDate(null);
            final newTime = args['new_time'] ?? '09:00';
            updateReminderData['datetime'] = '${newDate}T$newTime:00';
          }

          await supabase
              .from('calendar_events')
              .update(updateReminderData)
              .eq('user_id', user.id)
              .eq('title', args['title'])
              .eq('type', 'reminder');
          return {'success': true, 'message': 'Reminder updated'};

        // REMINDERS - DELETE
        case 'delete_reminder':
          await supabase
              .from('calendar_events')
              .delete()
              .eq('user_id', user.id)
              .eq('title', args['title'])
              .eq('type', 'reminder');
          return {'success': true, 'message': 'Reminder deleted'};

        // MOODS - ADD
        case 'log_mood':
          await supabase.from('mood_logs').insert({
            'user_id': user.id,
            'feeling': args['mood'],
            'intensity': args['intensity'] ?? 5,
            'notes': args['notes'],
            'day': getDate(args['date']),
          });
          return {'success': true, 'message': 'Mood logged'};

        // MOODS - UPDATE
        case 'update_mood_log':
          await supabase
              .from('mood_logs')
              .update({
                'feeling': args['mood'],
                'intensity': args['intensity'] ?? 5,
              })
              .eq('user_id', user.id)
              .eq('day', getDate(args['date']));
          return {'success': true, 'message': 'Mood updated'};

        // MOODS - DELETE
        case 'delete_mood_log':
          await supabase
              .from('mood_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', getDate(args['date']));
          return {'success': true, 'message': 'Mood deleted'};

        // HABITS - ADD
        case 'log_habit':
          await supabase.from('habit_logs').insert({
            'user_id': user.id,
            'habit_name': args['habit_name'],
            'is_completed': args['completed'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Habit logged'};

        // HABITS - UPDATE
        case 'update_habit_log':
          await supabase
              .from('habit_logs')
              .update({'is_completed': args['completed']})
              .eq('user_id', user.id)
              .eq('habit_name', args['habit_name'])
              .eq('day', getDate(args['date']));
          return {'success': true, 'message': 'Habit updated'};

        // HABITS - DELETE
        case 'delete_habit_log':
          await supabase
              .from('habit_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('habit_name', args['habit_name'])
              .eq('day', getDate(args['date']));
          return {'success': true, 'message': 'Habit deleted'};

        // WATER - ADD
        case 'log_water':
          await supabase.from('water_logs').insert({
            'user_id': user.id,
            'amount': args['amount_ml'],
            'unit': 'ml',
            'day': getDate(args['date']),
            'goal_reached': false,
          });
          return {'success': true, 'message': '${args['amount_ml']}ml logged'};

        // WATER - UPDATE
        case 'update_water_log':
          await supabase
              .from('water_logs')
              .update({'amount': args['amount_ml'], 'unit': 'ml'})
              .eq('user_id', user.id)
              .eq('day', getDate(args['date']));
          return {
            'success': true,
            'message': 'Water updated to ${args['amount_ml']}ml',
          };

        // WATER - DELETE
        case 'delete_water_log':
          await supabase
              .from('water_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', getDate(args['date']));
          return {'success': true, 'message': 'Water log deleted'};

        // BILLS - ADD
        case 'add_bill':
          await supabase.from('bill_logs').insert({
            'user_id': user.id,
            'name': args['name'],
            'amount': args['amount'],
            'day': args['due_date'],
            'is_paid': args['paid'] ?? false,
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Bill added'};

        // BILLS - UPDATE
        case 'update_bill':
          final updateData = <String, dynamic>{};
          if (args['paid'] != null) updateData['is_paid'] = args['paid'];
          if (args['amount'] != null) updateData['amount'] = args['amount'];

          await supabase
              .from('bill_logs')
              .update(updateData)
              .eq('user_id', user.id)
              .eq('name', args['name'])
              .eq('day', args['due_date']);
          return {'success': true, 'message': 'Bill updated'};

        // BILLS - DELETE
        case 'delete_bill':
          await supabase
              .from('bill_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('name', args['name'])
              .eq('day', args['due_date']);
          return {'success': true, 'message': 'Bill deleted'};

        // BOOKS - ADD
        case 'log_book':
          await supabase.from('book_logs').insert({
            'user_id': user.id,
            'book_title': args['title'],
            'author': args['author'],
            'rating': args['rating'],
            'status': args['status'] ?? 'reading',
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Book logged'};

        // BOOKS - UPDATE
        case 'update_book_log':
          final bookUpdate = <String, dynamic>{};
          if (args['rating'] != null) bookUpdate['rating'] = args['rating'];
          if (args['status'] != null) bookUpdate['status'] = args['status'];

          await supabase
              .from('book_logs')
              .update(bookUpdate)
              .eq('user_id', user.id)
              .eq('book_title', args['title']);
          return {'success': true, 'message': 'Book updated'};

        // BOOKS - DELETE
        case 'delete_book_log':
          await supabase
              .from('book_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('book_title', args['title']);
          return {'success': true, 'message': 'Book deleted'};

        // CYCLE - ADD
        case 'log_cycle':
          await supabase.from('menstrual_logs').insert({
            'user_id': user.id,
            'day': args['date'],
            'flow': args['flow'],
            'symptoms': args['symptoms'],
          });
          return {'success': true, 'message': 'Cycle logged'};

        // CYCLE - UPDATE
        case 'update_cycle_log':
          final cycleUpdate = <String, dynamic>{};
          if (args['flow'] != null) cycleUpdate['flow'] = args['flow'];
          if (args['symptoms'] != null)
            cycleUpdate['symptoms'] = args['symptoms'];

          await supabase
              .from('menstrual_logs')
              .update(cycleUpdate)
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Cycle log updated'};

        // CYCLE - DELETE
        case 'delete_cycle_log':
          await supabase
              .from('menstrual_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Cycle log deleted'};

        // EXPENSES - ADD
        case 'add_expense':
          await supabase.from('expense_logs').insert({
            'user_id': user.id,
            'category': args['category'] ?? 'other',
            'cost': args['amount'],
            'day': getDate(args['date']),
            'notes': args['description'],
          });
          return {'success': true, 'message': 'Expense added'};

        // EXPENSES - UPDATE
        case 'update_expense':
          final expenseUpdate = <String, dynamic>{};
          if (args['amount'] != null) expenseUpdate['cost'] = args['amount'];
          if (args['category'] != null)
            expenseUpdate['category'] = args['category'];

          await supabase
              .from('expense_logs')
              .update(expenseUpdate)
              .eq('user_id', user.id)
              .eq('notes', args['description'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Expense updated'};

        // EXPENSES - DELETE
        case 'delete_expense':
          await supabase
              .from('expense_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('notes', args['description'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Expense deleted'};

        // INCOME - ADD
        case 'add_income':
          await supabase.from('income_logs').insert({
            'user_id': user.id,
            'source': args['source'],
            'amount': args['amount'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Income added'};

        // INCOME - UPDATE
        case 'update_income':
          await supabase
              .from('income_logs')
              .update({'amount': args['amount']})
              .eq('user_id', user.id)
              .eq('source', args['source'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Income updated'};

        // INCOME - DELETE
        case 'delete_income':
          await supabase
              .from('income_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('source', args['source'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Income deleted'};

        // FASTING - ADD
        case 'log_fast':
          await supabase.from('fast_logs').insert({
            'user_id': user.id,
            'day': getDate(null),
            'duration_hours': args['duration_hours'] ?? 16,
            'feeling': args['feeling'],
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Fast logged'};

        // FASTING - UPDATE
        case 'update_fast_log':
          final fastUpdate = <String, dynamic>{};
          if (args['duration_hours'] != null)
            fastUpdate['duration_hours'] = args['duration_hours'];
          if (args['feeling'] != null) fastUpdate['feeling'] = args['feeling'];

          await supabase
              .from('fast_logs')
              .update(fastUpdate)
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Fast log updated'};

        // FASTING - DELETE
        case 'delete_fast_log':
          await supabase
              .from('fast_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Fast log deleted'};

        // SLEEP - ADD
        case 'log_sleep':
          await supabase.from('sleep_logs').insert({
            'user_id': user.id,
            'day': getDate(null),
            'hours_slept': args['hours_slept'] ?? 8,
            'quality': args['quality'],
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Sleep logged'};

        // SLEEP - UPDATE
        case 'update_sleep_log':
          await supabase
              .from('sleep_logs')
              .update({'quality': args['quality']})
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Sleep updated'};

        // SLEEP - DELETE
        case 'delete_sleep_log':
          await supabase
              .from('sleep_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Sleep deleted'};

        // TASKS - ADD
        case 'add_task':
          await supabase.from('task_logs').insert({
            'user_id': user.id,
            'task_name': args['title'],
            'priority': args['priority'] ?? 'medium',
            'is_done': args['completed'] ?? false,
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Task added'};

        // TASKS - UPDATE
        case 'update_task':
          final taskUpdate = <String, dynamic>{};
          if (args['completed'] != null)
            taskUpdate['is_done'] = args['completed'];
          if (args['priority'] != null)
            taskUpdate['priority'] = args['priority'];

          await supabase
              .from('task_logs')
              .update(taskUpdate)
              .eq('user_id', user.id)
              .eq('task_name', args['title']);
          return {'success': true, 'message': 'Task updated'};

        // TASKS - DELETE
        case 'delete_task':
          await supabase
              .from('task_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('task_name', args['title']);
          return {'success': true, 'message': 'Task deleted'};

        // WISHLIST - ADD
        case 'add_wishlist_item':
          await supabase.from('wishlist').insert({
            'user_id': user.id,
            'item_name': args['item'],
            'price': args['price'],
            'priority': args['priority'] ?? 'medium',
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Added to wishlist'};

        // WISHLIST - UPDATE
        case 'update_wishlist_item':
          final wishlistUpdate = <String, dynamic>{};
          if (args['price'] != null) wishlistUpdate['price'] = args['price'];
          if (args['priority'] != null)
            wishlistUpdate['priority'] = args['priority'];

          await supabase
              .from('wishlist')
              .update(wishlistUpdate)
              .eq('user_id', user.id)
              .eq('item_name', args['item']);
          return {'success': true, 'message': 'Wishlist updated'};

        // WISHLIST - DELETE
        case 'delete_wishlist_item':
          await supabase
              .from('wishlist')
              .delete()
              .eq('user_id', user.id)
              .eq('item_name', args['item']);
          return {'success': true, 'message': 'Removed from wishlist'};

        // MOVIES - ADD
        case 'log_movie':
          await supabase.from('movie_logs').insert({
            'user_id': user.id,
            'movie_title': args['title'],
            'rating': args['rating'],
            'day': getDate(args['date']),
            'notes': args['review'],
            'genre': args['genre'],
          });
          return {'success': true, 'message': 'Movie logged'};

        // MOVIES - UPDATE
        case 'update_movie_log':
          final movieUpdate = <String, dynamic>{};
          if (args['rating'] != null) movieUpdate['rating'] = args['rating'];
          if (args['review'] != null) movieUpdate['notes'] = args['review'];

          await supabase
              .from('movie_logs')
              .update(movieUpdate)
              .eq('user_id', user.id)
              .eq('movie_title', args['title']);
          return {'success': true, 'message': 'Movie updated'};

        // MOVIES - DELETE
        case 'delete_movie_log':
          await supabase
              .from('movie_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('movie_title', args['title']);
          return {'success': true, 'message': 'Movie deleted'};

        // TV SHOWS - ADD
        case 'log_tv_show':
          await supabase.from('tv_logs').insert({
            'user_id': user.id,
            'title': args['title'],
            'rating': args['rating'],
            'day': getDate(args['date']),
            'thoughts': args['review'],
          });
          return {'success': true, 'message': 'TV show logged'};

        // TV SHOWS - UPDATE
        case 'update_tv_log':
          await supabase
              .from('tv_logs')
              .update({'rating': args['rating']})
              .eq('user_id', user.id)
              .eq('title', args['title']);
          return {'success': true, 'message': 'TV show updated'};

        // TV SHOWS - DELETE
        case 'delete_tv_log':
          await supabase
              .from('tv_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('title', args['title']);
          return {'success': true, 'message': 'TV show deleted'};

        // PLACES - ADD
        case 'log_place':
          await supabase.from('place_logs').insert({
            'user_id': user.id,
            'place_name': args['name'],
            'location': args['location'],
            'rating': args['rating'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Place logged'};

        // PLACES - UPDATE
        case 'update_place_log':
          final placeUpdate = <String, dynamic>{};
          if (args['rating'] != null) placeUpdate['rating'] = args['rating'];
          if (args['notes'] != null) placeUpdate['notes'] = args['notes'];

          await supabase
              .from('place_logs')
              .update(placeUpdate)
              .eq('user_id', user.id)
              .eq('place_name', args['name']);
          return {'success': true, 'message': 'Place updated'};

        // PLACES - DELETE
        case 'delete_place_log':
          await supabase
              .from('place_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('place_name', args['name']);
          return {'success': true, 'message': 'Place deleted'};

        // RESTAURANTS - ADD
        case 'log_restaurant':
          await supabase.from('restaurant_logs').insert({
            'user_id': user.id,
            'restaurant_name': args['name'],
            'location': args['location'],
            'cuisine_type': args['cuisine'],
            'rating': args['rating'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Restaurant logged'};

        // RESTAURANTS - UPDATE
        case 'update_restaurant_log':
          final restaurantUpdate = <String, dynamic>{};
          if (args['rating'] != null)
            restaurantUpdate['rating'] = args['rating'];
          if (args['notes'] != null) restaurantUpdate['notes'] = args['notes'];

          await supabase
              .from('restaurant_logs')
              .update(restaurantUpdate)
              .eq('user_id', user.id)
              .eq('restaurant_name', args['name']);
          return {'success': true, 'message': 'Restaurant updated'};

        // RESTAURANTS - DELETE
        case 'delete_restaurant_log':
          await supabase
              .from('restaurant_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('restaurant_name', args['name']);
          return {'success': true, 'message': 'Restaurant deleted'};

        // MEDITATION - ADD
        case 'log_meditation':
          await supabase.from('meditation_logs').insert({
            'user_id': user.id,
            'duration_minutes': args['duration_minutes'],
            'technique': args['technique'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Meditation logged'};

        // MEDITATION - UPDATE
        case 'update_meditation_log':
          await supabase
              .from('meditation_logs')
              .update({'duration_minutes': args['duration_minutes']})
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Meditation updated'};

        // MEDITATION - DELETE
        case 'delete_meditation_log':
          await supabase
              .from('meditation_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Meditation deleted'};

        // GOALS - ADD
        case 'add_goal':
          await supabase.from('goal_logs').insert({
            'user_id': user.id,
            'goal_title': args['goal_title'],
            'category': args['category'],
            'target_date': args['target_date'],
            'is_completed': args['is_completed'] ?? false,
            'priority': args['priority'] ?? 'medium',
          });
          return {'success': true, 'message': 'Goal added'};

        // GOALS - UPDATE
        case 'update_goal':
          await supabase
              .from('goal_logs')
              .update({'is_completed': args['is_completed']})
              .eq('user_id', user.id)
              .eq('goal_title', args['goal_title']);
          return {'success': true, 'message': 'Goal updated'};

        // GOALS - DELETE
        case 'delete_goal':
          await supabase
              .from('goal_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('goal_title', args['goal_title']);
          return {'success': true, 'message': 'Goal deleted'};

        // WORKOUT - ADD
        case 'log_workout':
          await supabase.from('workout_logs').insert({
            'user_id': user.id,
            'exercise': args['exercise'],
            'sets': args['sets'],
            'reps': args['reps'],
            'weight_kg': args['weight_kg'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Workout logged'};

        // WORKOUT - UPDATE
        case 'update_workout_log':
          final workoutUpdate = <String, dynamic>{};
          if (args['sets'] != null) workoutUpdate['sets'] = args['sets'];
          if (args['reps'] != null) workoutUpdate['reps'] = args['reps'];
          if (args['weight_kg'] != null)
            workoutUpdate['weight_kg'] = args['weight_kg'];

          await supabase
              .from('workout_logs')
              .update(workoutUpdate)
              .eq('user_id', user.id)
              .eq('exercise', args['exercise'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Workout updated'};

        // WORKOUT - DELETE
        case 'delete_workout_log':
          await supabase
              .from('workout_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('exercise', args['exercise'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Workout deleted'};

        // SKIN CARE - ADD
        case 'log_skin_care':
          await supabase.from('skin_care_logs').insert({
            'user_id': user.id,
            'routine_type': args['routine_type'],
            'products': args['products'],
            'skin_condition': args['skin_condition'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Skin care logged'};

        // SKIN CARE - UPDATE
        case 'update_skin_care_log':
          final skinCareUpdate = <String, dynamic>{};
          if (args['skin_condition'] != null)
            skinCareUpdate['skin_condition'] = args['skin_condition'];
          if (args['products'] != null)
            skinCareUpdate['products'] = args['products'];

          await supabase
              .from('skin_care_logs')
              .update(skinCareUpdate)
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Skin care updated'};

        // SKIN CARE - DELETE
        case 'delete_skin_care_log':
          await supabase
              .from('skin_care_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Skin care deleted'};

        // STUDY - ADD
        case 'log_study':
          await supabase.from('study_logs').insert({
            'user_id': user.id,
            'subject': args['subject'],
            'duration_hours': args['duration_hours'],
            'focus_rating': args['focus_rating'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Study session logged'};

        // STUDY - UPDATE
        case 'update_study_log':
          final studyUpdate = <String, dynamic>{};
          if (args['duration_hours'] != null)
            studyUpdate['duration_hours'] = args['duration_hours'];
          if (args['focus_rating'] != null)
            studyUpdate['focus_rating'] = args['focus_rating'];

          await supabase
              .from('study_logs')
              .update(studyUpdate)
              .eq('user_id', user.id)
              .eq('subject', args['subject'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Study log updated'};

        // STUDY - DELETE
        case 'delete_study_log':
          await supabase
              .from('study_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('subject', args['subject'])
              .eq('day', args['date']);
          return {'success': true, 'message': 'Study log deleted'};

        // SOCIAL - ADD
        case 'log_social':
          await supabase.from('social_logs').insert({
            'user_id': user.id,
            'person_event': args['person_event'],
            'activity_type': args['activity_type'],
            'social_energy': args['social_energy'],
            'day': getDate(args['date']),
            'notes': args['notes'],
          });
          return {'success': true, 'message': 'Social activity logged'};

        // SOCIAL - UPDATE
        case 'update_social_log':
          final socialUpdate = <String, dynamic>{};
          if (args['social_energy'] != null)
            socialUpdate['social_energy'] = args['social_energy'];
          if (args['activity_type'] != null)
            socialUpdate['activity_type'] = args['activity_type'];

          await supabase
              .from('social_logs')
              .update(socialUpdate)
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Social log updated'};

        // SOCIAL - DELETE
        case 'delete_social_log':
          await supabase
              .from('social_logs')
              .delete()
              .eq('user_id', user.id)
              .eq('day', args['date']);
          return {'success': true, 'message': 'Social log deleted'};

        default:
          return {'success': false, 'error': 'Unknown function'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // HOBONICHI REPO METHODS (for compatibility)
  // ============================================

  Stream<List<Map<String, dynamic>>> streamMessages({required int chatId}) {
    return Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> listMessages({required int chatId}) async {
    final rows = await Supabase.instance.client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addMessage({
    required int chatId,
    required String userId,
    required String role,
    required String content,
  }) async {
    await Supabase.instance.client.from('chat_messages').insert({
      'chat_id': chatId,
      'user_id': userId,
      'role': role,
      'text': content,
    });
  }

  Future<void> ensureDayExists({
    required String dayId,
    required String userId,
  }) async {
    final existing = await Supabase.instance.client
        .from('days')
        .select('id')
        .eq('id', dayId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await Supabase.instance.client.from('days').insert({
        'id': dayId,
        'user_id': userId,
      });
    }
  }

  Future<List<Map<String, dynamic>>> listPages({
    required String dayId,
    required String userId,
  }) async {
    final rows = await Supabase.instance.client
        .from('pages')
        .select('*')
        .eq('day_id', dayId)
        .eq('user_id', userId)
        .order('sort_order', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addPage({
    required String dayId,
    required String userId,
    required int sortOrder,
    required String title,
  }) async {
    final inserted = await Supabase.instance.client
        .from('pages')
        .insert({
          'day_id': dayId,
          'user_id': userId,
          'title': title,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted as Map);
  }

  Future<Map<String, dynamic>> getOrCreateFirstPage({
    required String dayId,
    required String userId,
  }) async {
    final pages = await listPages(dayId: dayId, userId: userId);

    if (pages.isNotEmpty) {
      return pages.first;
    }

    final inserted = await Supabase.instance.client
        .from('pages')
        .insert({
          'day_id': dayId,
          'user_id': userId,
          'title': 'Page 1',
          'sort_order': 0,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted as Map);
  }

  Future<void> setCoverForDay({
    required String dayId,
    required String userId,
    required String coverId,
  }) async {
    await Supabase.instance.client
        .from('days')
        .update({'cover_id': coverId})
        .eq('id', dayId)
        .eq('user_id', userId);
  }

  Future<String?> getCoverForDay({
    required String dayId,
    required String userId,
  }) async {
    final row = await Supabase.instance.client
        .from('days')
        .select('cover_id')
        .eq('id', dayId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return (row['cover_id'] as String?);
  }

  Future<void> addPomodoroBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await Supabase.instance.client.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'pomodoro',
      'sort_order': sortOrder,
      'content': {
        'mode': 'focus',
        'focusMinutes': 25,
        'shortBreakMinutes': 5,
        'longBreakMinutes': 15,
        'secondsLeft': 25 * 60,
        'running': false,
        'cyclesDone': 0,
      },
    });
  }

  Future<Set<String>> daysWithBoxesInRange({
    required String userId,
    required String startDayId,
    required String endDayId,
  }) async {
    final pagesRows = await Supabase.instance.client
        .from('pages')
        .select('id, day_id')
        .eq('user_id', userId)
        .gte('day_id', startDayId)
        .lte('day_id', endDayId);

    final pages = (pagesRows as List).cast<Map<String, dynamic>>();
    if (pages.isEmpty) return {};

    final pageIds = pages.map((p) => p['id'] as String).toList();
    final pageIdToDay = {
      for (final p in pages) (p['id'] as String): (p['day_id'] as String),
    };

    final boxRows = await Supabase.instance.client
        .from('boxes')
        .select('page_id')
        .inFilter('page_id', pageIds);

    final boxes = (boxRows as List).cast<Map<String, dynamic>>();
    final dayIds = <String>{};

    for (final b in boxes) {
      final pid = b['page_id'] as String;
      final dayId = pageIdToDay[pid];
      if (dayId != null) dayIds.add(dayId);
    }

    return dayIds;
  }

  Future<int> createChat({required String userId}) async {
    final inserted = await Supabase.instance.client
        .from('chats')
        .insert({
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return (inserted['id'] as num).toInt();
  }

  Future<void> updateBoxContent({
    required String boxId,
    required Map<String, dynamic> content,
  }) async {
    await Supabase.instance.client
        .from('boxes')
        .update({'content': content})
        .eq('id', boxId);
  }
}
