import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';

/// Supabase project configuration.
/// Loaded from .env file.
class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get publishableKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Default channels seeded for every new couple
  static const List<Map<String, String>> defaultChannels = [
    {'name': 'general', 'icon': '💬', 'description': 'Your cozy corner together'},
    {'name': 'photos', 'icon': '📸', 'description': 'Share your moments'},
    {'name': 'plans', 'icon': '📅', 'description': 'Plan your dates & adventures'},
    {'name': 'random', 'icon': '✨', 'description': 'Fun, games & random thoughts'},
  ];

  /// Curated conversation prompts for the #random channel
  static const List<ConversationPrompt> conversationPrompts = [
    // Deep & Meaningful
    ConversationPrompt(text: 'What\'s one thing about me that surprised you when we first met?', category: 'Deep', emoji: '💭'),
    ConversationPrompt(text: 'What\'s a dream you haven\'t told me about yet?', category: 'Deep', emoji: '🌙'),
    ConversationPrompt(text: 'What moment in our relationship made you the happiest?', category: 'Deep', emoji: '✨'),
    ConversationPrompt(text: 'If you could relive one day with me, which would it be?', category: 'Deep', emoji: '🔄'),
    ConversationPrompt(text: 'What\'s something small I do that makes your whole day better?', category: 'Deep', emoji: '🌸'),
    ConversationPrompt(text: 'What\'s a fear you\'ve overcome since we\'ve been together?', category: 'Deep', emoji: '🦋'),
    ConversationPrompt(text: 'What song reminds you most of us?', category: 'Deep', emoji: '🎵'),
    ConversationPrompt(text: 'What do you think is our greatest strength as a couple?', category: 'Deep', emoji: '💪'),

    // Fun & Playful
    ConversationPrompt(text: 'If we could teleport anywhere right now, where would you take me?', category: 'Fun', emoji: '🌍'),
    ConversationPrompt(text: 'What\'s your favorite inside joke of ours?', category: 'Fun', emoji: '😂'),
    ConversationPrompt(text: 'If we were in a movie, what genre would our story be?', category: 'Fun', emoji: '🎬'),
    ConversationPrompt(text: 'What superpower would you want me to have?', category: 'Fun', emoji: '⚡'),
    ConversationPrompt(text: 'If we had a couple theme song, what would it be?', category: 'Fun', emoji: '🎶'),
    ConversationPrompt(text: 'What fictional couple are we most like?', category: 'Fun', emoji: '📺'),
    ConversationPrompt(text: 'If we opened a restaurant together, what would we serve?', category: 'Fun', emoji: '🍳'),
    ConversationPrompt(text: 'What emoji best describes our relationship?', category: 'Fun', emoji: '🤔'),
    ConversationPrompt(text: 'If we won the lottery tomorrow, what\'s the first thing we\'d do?', category: 'Fun', emoji: '💰'),
    ConversationPrompt(text: 'What would our couple band name be?', category: 'Fun', emoji: '🎸'),

    // Would You Rather
    ConversationPrompt(text: 'Would you rather have breakfast in bed or a surprise dinner out?', category: 'Would You Rather', emoji: '🤷'),
    ConversationPrompt(text: 'Would you rather go on a road trip or fly to a beach resort?', category: 'Would You Rather', emoji: '🚗'),
    ConversationPrompt(text: 'Would you rather cook together or order our favorite takeout?', category: 'Would You Rather', emoji: '🍕'),
    ConversationPrompt(text: 'Would you rather watch the sunrise together or the sunset?', category: 'Would You Rather', emoji: '🌅'),
    ConversationPrompt(text: 'Would you rather have a movie night or a game night?', category: 'Would You Rather', emoji: '🎮'),
    ConversationPrompt(text: 'Would you rather live in a cabin in the mountains or a beach house?', category: 'Would You Rather', emoji: '🏔️'),

    // Future Together
    ConversationPrompt(text: 'Where do you see us in 5 years?', category: 'Future', emoji: '🔮'),
    ConversationPrompt(text: 'What\'s one adventure you want us to go on together?', category: 'Future', emoji: '🗺️'),
    ConversationPrompt(text: 'What tradition should we start together?', category: 'Future', emoji: '🎄'),
    ConversationPrompt(text: 'If we could learn something new together, what would it be?', category: 'Future', emoji: '📚'),
    ConversationPrompt(text: 'What does your ideal weekend with me look like?', category: 'Future', emoji: '☀️'),
    ConversationPrompt(text: 'What country do you most want to explore together?', category: 'Future', emoji: '✈️'),

    // Appreciation
    ConversationPrompt(text: 'What\'s something I did recently that made you smile?', category: 'Appreciation', emoji: '😊'),
    ConversationPrompt(text: 'What\'s your favorite physical feature of mine?', category: 'Appreciation', emoji: '💕'),
    ConversationPrompt(text: 'What quality of mine are you most grateful for?', category: 'Appreciation', emoji: '🙏'),
    ConversationPrompt(text: 'What\'s the best gift I\'ve ever given you?', category: 'Appreciation', emoji: '🎁'),
    ConversationPrompt(text: 'When did you first realize you were falling for me?', category: 'Appreciation', emoji: '❤️'),
    ConversationPrompt(text: 'What\'s one way I make you feel safe and loved?', category: 'Appreciation', emoji: '🤗'),

    // Silly
    ConversationPrompt(text: 'What animal do you think I\'d be and why?', category: 'Silly', emoji: '🐾'),
    ConversationPrompt(text: 'If I was a flavor of ice cream, what would I be?', category: 'Silly', emoji: '🍦'),
    ConversationPrompt(text: 'What\'s the most embarrassing thing you\'ve done to impress me?', category: 'Silly', emoji: '🙈'),
    ConversationPrompt(text: 'If our love story was a meme, which meme would it be?', category: 'Silly', emoji: '😜'),
    ConversationPrompt(text: 'Rate my texting game from 1-10, be honest!', category: 'Silly', emoji: '📱'),
  ];

  /// Date night activity options for the spinner in #random
  static const List<String> dateNightOptions = [
    '🍿 Movie Night',
    '🍳 Cook Together',
    '🚶 Sunset Walk',
    '🎮 Game Night',
    '📖 Read Together',
    '🎨 Art Night',
    '🧩 Puzzle Time',
    '🎵 Music & Dance',
    '🧘 Yoga Together',
    '📸 Photo Walk',
    '🍰 Bake Something',
    '⭐ Stargazing',
  ];
}
