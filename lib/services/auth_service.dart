import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';

/// Handles authentication and couple pairing.
class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Profile? _profile;
  Profile? get profile => _profile;

  Couple? _couple;
  Couple? get couple => _couple;

  Profile? _partnerProfile;
  Profile? get partnerProfile => _partnerProfile;

  bool _loading = true;
  bool get loading => _loading;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    // Listen for auth changes
    _client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        await loadUserData();
      } else {
        _profile = null;
        _couple = null;
        _partnerProfile = null;
        _loading = false;
        notifyListeners();
      }
    });

    // Check existing session
    if (currentUser != null) {
      await loadUserData();
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  /// Load user profile, couple, and partner data.
  Future<void> loadUserData() async {
    try {
      _loading = true;
      notifyListeners();

      final userId = currentUser!.id;

      // Load profile
      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null) {
        _profile = Profile.fromJson(profileData);
      }

      // Load couple
      final coupleData = await _client
          .from('couples')
          .select()
          .or('user_1.eq.$userId,user_2.eq.$userId')
          .maybeSingle();

      if (coupleData != null) {
        _couple = Couple.fromJson(coupleData);

        // Load partner profile
        final partnerId = _couple!.partnerId(userId);
        final partnerData = await _client
            .from('profiles')
            .select()
            .eq('id', partnerId)
            .maybeSingle();

        if (partnerData != null) {
          _partnerProfile = Profile.fromJson(partnerData);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sign up with email & password.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Create profile
      await _client.from('profiles').insert({
        'id': response.user!.id,
        'username': username.toLowerCase().trim(),
        'display_name': displayName.trim(),
      });

      await loadUserData();
    }
  }

  /// Sign in with email & password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await loadUserData();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _client.auth.signOut();
    _profile = null;
    _couple = null;
    _partnerProfile = null;
    notifyListeners();
  }

  /// Generate a random 6-character invite code for couple pairing.
  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a couple entry with an invite code (creator flow).
  Future<String> createCouple() async {
    final code = generateInviteCode();
    final userId = currentUser!.id;

    await _client.from('couples').insert({
      'user_1': userId,
      'invite_code': code,
    });

    return code;
  }

  /// Join an existing couple with an invite code (partner flow).
  Future<bool> joinCouple(String code) async {
    final userId = currentUser!.id;

    // Find the couple with this invite code
    final coupleData = await _client
        .from('couples')
        .select()
        .eq('invite_code', code.toUpperCase().trim())
        .isFilter('user_2', null)
        .maybeSingle();

    if (coupleData == null) return false;

    // Update couple with partner
    await _client.from('couples').update({
      'user_2': userId,
      'invite_code': null, // Burn the code
    }).eq('id', coupleData['id']);

    // Seed default channels for this couple
    await _seedDefaultChannels(coupleData['id'] as String);

    await loadUserData();
    return true;
  }

  /// Seed the default channels for a newly formed couple.
  Future<void> _seedDefaultChannels(String coupleId) async {
    final channels = SupabaseConfig.defaultChannels.asMap().entries.map((e) => {
          'couple_id': coupleId,
          'name': e.value['name'],
          'icon': e.value['icon'],
          'description': e.value['description'],
          'position': e.key,
          'is_default': e.key == 0,
        }).toList();

    await _client.from('channels').insert(channels);
  }
}
