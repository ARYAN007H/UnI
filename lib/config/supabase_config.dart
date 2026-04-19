import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase project configuration.
/// Loaded from .env file.
class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Default channels seeded for every new couple
  static const List<Map<String, String>> defaultChannels = [
    {'name': 'general', 'icon': '💬', 'description': 'Talk about anything'},
    {'name': 'photos', 'icon': '📸', 'description': 'Share your moments'},
    {'name': 'plans', 'icon': '📅', 'description': 'Plan your dates & trips'},
    {'name': 'random', 'icon': '✨', 'description': 'Random thoughts & ideas'},
  ];
}
