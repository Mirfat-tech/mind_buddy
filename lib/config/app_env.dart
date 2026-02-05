import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
}
