// app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MindBuddyApp extends StatelessWidget {
  const MindBuddyApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Mind Buddy',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent, // 👈 important
        colorSchemeSeed: const Color.fromARGB(255, 223, 77, 242),
        brightness: Brightness.light,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent, // 👈 important
        colorSchemeSeed: const Color.fromARGB(255, 223, 77, 242),
        brightness: Brightness.dark,
      ),

      routerConfig: router,
    );
  }
}
