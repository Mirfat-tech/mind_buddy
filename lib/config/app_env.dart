import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get openAiApiKey {
    try {
      return dotenv.env['OPENAI_API_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }
}
