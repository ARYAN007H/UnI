/// Supabase project configuration.
/// Replace these with your own Supabase project URL and anon key.
class SupabaseConfig {
  static const String url = 'https://YOUR_PROJECT.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY';

  /// Default channels seeded for every new couple
  static const List<Map<String, String>> defaultChannels = [
    {'name': 'general', 'icon': '💬', 'description': 'Talk about anything'},
    {'name': 'photos', 'icon': '📸', 'description': 'Share your moments'},
    {'name': 'plans', 'icon': '📅', 'description': 'Plan your dates & trips'},
    {'name': 'random', 'icon': '✨', 'description': 'Random thoughts & ideas'},
  ];
}
