import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/router.dart';

void main() {
  group('localFirstBuiltInTemplateForKey', () {
    test('returns built-in template for mood without remote lookup', () {
      final template = localFirstBuiltInTemplateForKey('mood');

      expect(template, isNotNull);
      expect(template!.id, 'builtin:mood');
      expect(template.templateKey, 'mood');
    });

    test(
      'returns built-in template for bills and books without remote lookup',
      () {
        final bills = localFirstBuiltInTemplateForKey('bills');
        final books = localFirstBuiltInTemplateForKey('books');

        expect(bills, isNotNull);
        expect(bills!.id, 'builtin:bills');
        expect(bills.templateKey, 'bills');

        expect(books, isNotNull);
        expect(books!.id, 'builtin:books');
        expect(books.templateKey, 'books');
      },
    );

    test('returns built-in template for cycle without remote lookup', () {
      final cycle = localFirstBuiltInTemplateForKey('cycle');

      expect(cycle, isNotNull);
      expect(cycle!.id, 'builtin:cycle');
      expect(cycle.templateKey, 'cycle');
    });

    test('returns built-in template for expenses without remote lookup', () {
      final expenses = localFirstBuiltInTemplateForKey('expenses');

      expect(expenses, isNotNull);
      expect(expenses!.id, 'builtin:expenses');
      expect(expenses.templateKey, 'expenses');
    });

    test('returns built-in template for fast without remote lookup', () {
      final fast = localFirstBuiltInTemplateForKey('fast');

      expect(fast, isNotNull);
      expect(fast!.id, 'builtin:fast');
      expect(fast.templateKey, 'fast');
    });

    test('returns built-in template for income without remote lookup', () {
      final income = localFirstBuiltInTemplateForKey('income');

      expect(income, isNotNull);
      expect(income!.id, 'builtin:income');
      expect(income.templateKey, 'income');
    });

    test('returns built-in template for meditation without remote lookup', () {
      final meditation = localFirstBuiltInTemplateForKey('meditation');

      expect(meditation, isNotNull);
      expect(meditation!.id, 'builtin:meditation');
      expect(meditation.templateKey, 'meditation');
    });

    test('returns built-in template for movies without remote lookup', () {
      final movies = localFirstBuiltInTemplateForKey('movies');

      expect(movies, isNotNull);
      expect(movies!.id, 'builtin:movies');
      expect(movies.templateKey, 'movies');
    });

    test('returns built-in template for places without remote lookup', () {
      final places = localFirstBuiltInTemplateForKey('places');

      expect(places, isNotNull);
      expect(places!.id, 'builtin:places');
      expect(places.templateKey, 'places');
    });

    test('returns built-in template for restaurants without remote lookup', () {
      final restaurants = localFirstBuiltInTemplateForKey('restaurants');

      expect(restaurants, isNotNull);
      expect(restaurants!.id, 'builtin:restaurants');
      expect(restaurants.templateKey, 'restaurants');
    });

    test('returns built-in template for skin care without remote lookup', () {
      final skinCare = localFirstBuiltInTemplateForKey('skin_care');

      expect(skinCare, isNotNull);
      expect(skinCare!.id, 'builtin:skin_care');
      expect(skinCare.templateKey, 'skin_care');
    });

    test('returns built-in template for social without remote lookup', () {
      final social = localFirstBuiltInTemplateForKey('social');

      expect(social, isNotNull);
      expect(social!.id, 'builtin:social');
      expect(social.templateKey, 'social');
    });

    test('returns built-in template for study without remote lookup', () {
      final study = localFirstBuiltInTemplateForKey('study');

      expect(study, isNotNull);
      expect(study!.id, 'builtin:study');
      expect(study.templateKey, 'study');
    });

    test('returns built-in template for tasks without remote lookup', () {
      final tasks = localFirstBuiltInTemplateForKey('tasks');

      expect(tasks, isNotNull);
      expect(tasks!.id, 'builtin:tasks');
      expect(tasks.templateKey, 'tasks');
    });

    test('returns built-in template for tv logs without remote lookup', () {
      final tvLogs = localFirstBuiltInTemplateForKey('tv_log');

      expect(tvLogs, isNotNull);
      expect(tvLogs!.id, 'builtin:tv_log');
      expect(tvLogs.templateKey, 'tv_log');
    });

    test('returns built-in template for wishlist without remote lookup', () {
      final wishlist = localFirstBuiltInTemplateForKey('wishlist');

      expect(wishlist, isNotNull);
      expect(wishlist!.id, 'builtin:wishlist');
      expect(wishlist.templateKey, 'wishlist');
    });

    test('returns built-in template for workout without remote lookup', () {
      final workout = localFirstBuiltInTemplateForKey('workout');

      expect(workout, isNotNull);
      expect(workout!.id, 'builtin:workout');
      expect(workout.templateKey, 'workout');
    });

    test('returns null for non-local-first templates', () {
      final template = localFirstBuiltInTemplateForKey('goals');

      expect(template, isNull);
    });
  });
}
