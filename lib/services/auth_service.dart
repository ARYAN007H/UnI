import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';

/// Handles authentication and couple pairing.
class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Deep-link pairing (agent3 request) ─────────────────────

  /// Extract an invite code from a pairing deep link.
  ///
  /// Accepted forms (case-insensitive host/path handling):
  ///  - custom scheme:  uandi://pair?code=ABC123
  ///  - web link:       https://uandi.app/pair?code=ABC123  (or any host)
  ///  - path code:      https://uandi.app/pair/ABC123
  ///
  /// Returns null when the URI is not a pairing link or has no code.
  static String? extractPairCode(Uri uri) {
    final isPairLink = uri.scheme == 'uandi' ||
        (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first.toLowerCase() == 'pair');
    if (!isPairLink) return null;

    final queryCode = uri.queryParameters['code'] ??
        uri.queryParameters['invite_code'];
    if (queryCode != null && queryCode.trim().isNotEmpty) {
      return queryCode.trim().toUpperCase();
    }

    // /pair/<code> form — 'pair' itself is not the code
    for (final segment in uri.pathSegments) {
      if (segment.toLowerCase() == 'pair') continue;
      if (segment.trim().isNotEmpty) return segment.trim().toUpperCase();
    }
    return null;
  }


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

  /// Whether the user just signed up (used to show verification prompt).
  bool _justSignedUp = false;
  bool get justSignedUp => _justSignedUp;
  void clearJustSignedUp() {
    _justSignedUp = false;
    notifyListeners();
  }

  // ── Email verification helpers ──────────────────────────────

  /// Whether the user's email is verified.
  bool get isEmailVerified => _profile?.emailVerified ?? false;

  /// Whether the 24-hour grace period has expired without verification.
  bool get isGracePeriodExpired => _profile?.isGracePeriodExpired ?? false;

  /// Remaining time in the grace period.
  Duration get gracePeriodRemaining =>
      _profile?.gracePeriodRemaining ?? Duration.zero;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    // Listen for auth changes
    _client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        // If we were awaiting verification via magic link, mark as verified
        if (data.event == AuthChangeEvent.signedIn &&
            _profile != null &&
            !_profile!.emailVerified) {
          await _markEmailVerified();
        }
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
      } else {
        // Safety net: auto-create profile if auth user exists but profile row is missing.
        // This can happen if the signup profile insert failed (RLS, network, etc).
        final email = currentUser!.email ?? '';
        final fallbackName = email.split('@').first;
        try {
          await _client.from('profiles').insert({
            'id': userId,
            'username': fallbackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''),
            'display_name': fallbackName,
            'email_verified': false,
          });
          // Re-fetch the newly created profile
          final newProfile = await _client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (newProfile != null) {
            _profile = Profile.fromJson(newProfile);
          }
        } catch (e) {
          debugPrint('Error auto-creating profile: $e');
        }
      }

      // Load couple — use list query to handle potential duplicate rows
      final coupleList = await _client
          .from('couples')
          .select()
          .or('user_1.eq.$userId,user_2.eq.$userId')
          .order('paired_at', ascending: false);

      // Only consider fully paired couples (user_2 is not null)
      // Unpaired ones (waiting for partner) should keep _couple as null
      // so main.dart correctly shows the PairScreen.
      Map<String, dynamic>? coupleData;
      if (coupleList.isNotEmpty) {
        try {
          coupleData = coupleList.firstWhere(
            (c) => c['user_2'] != null,
          );
        } catch (_) {
          // No fully paired couple found — stay on PairScreen
          coupleData = null;
        }
      }

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
      } else {
        _couple = null;
        _partnerProfile = null;
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sign up with email & password.
  /// With "Confirm email" disabled in Supabase, user gets a session immediately.
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
      // Create profile with email_verified = false
      // Use upsert to handle cases where the profile row may already exist
      try {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'username': username.toLowerCase().trim(),
          'display_name': displayName.trim(),
          'email_verified': false,
        });
      } catch (e) {
        // If profile creation fails, loadUserData's safety net will retry
        debugPrint('Profile creation during signup failed (will retry): $e');
      }

      _justSignedUp = true;
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
    _justSignedUp = false;
    notifyListeners();
  }

  // ── Email verification ─────────────────────────────────────

  /// Send a magic link to the user's email for verification.
  /// When the user clicks it, the auth state change listener
  /// will detect the sign-in event and mark them as verified.
  Future<void> sendVerificationEmail() async {
    final email = currentUser?.email;
    if (email == null) return;

    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  /// Mark the current user's email as verified in the profiles table.
  Future<void> _markEmailVerified() async {
    if (currentUser == null) return;

    try {
      await _client.from('profiles').update({
        'email_verified': true,
        'email_verified_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', currentUser!.id);

      // Reload to get updated profile
      await loadUserData();
    } catch (e) {
      debugPrint('Error marking email as verified: $e');
    }
  }

  /// Manually mark email as verified (e.g. after magic link callback).
  Future<void> markEmailVerified() async {
    await _markEmailVerified();
  }

  // ── Couple pairing ────────────────────────────────────────

  /// Generate a random 6-character invite code for couple pairing.
  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a couple entry with an invite code (creator flow).
  Future<String> createCouple() async {
    final userId = currentUser!.id;

    // Check if user already has unpaired couples (handle duplicates from previous attempts)
    final existingList = await _client
        .from('couples')
        .select()
        .eq('user_1', userId)
        .isFilter('user_2', null)
        .order('paired_at', ascending: false);

    if (existingList.isNotEmpty) {
      // If any existing row has an active invite code, reuse it
      for (final row in existingList) {
        if (row['invite_code'] != null) {
          return row['invite_code'] as String;
        }
      }

      // All existing rows have null/burned invite codes — update the first one with a new code
      final code = generateInviteCode();
      final staleId = existingList.first['id'];
      await _client.from('couples').update({
        'invite_code': code,
      }).eq('id', staleId);
      return code;
    }

    // No existing unpaired couple — create a new one
    final code = generateInviteCode();

    await _client.from('couples').insert({
      'user_1': userId,
      'invite_code': code,
    });

    return code;
  }

  /// Join an existing couple with an invite code (partner flow).
  Future<bool> joinCouple(String code) async {
    final userId = currentUser!.id;
    final normalizedCode = code.toUpperCase().trim();

    debugPrint('[joinCouple] Attempting to join with code: $normalizedCode');

    try {
      // Find the couple with this invite code
      final coupleData = await _client
          .from('couples')
          .select()
          .eq('invite_code', normalizedCode)
          .isFilter('user_2', null)
          .maybeSingle();

      debugPrint('[joinCouple] Query result: $coupleData');

      if (coupleData == null) {
        debugPrint('[joinCouple] No matching couple found for code: $normalizedCode');
        return false;
      }

      // Don't let user pair with themselves
      if (coupleData['user_1'] == userId) {
        debugPrint('[joinCouple] User tried to join their own couple');
        return false;
      }

      // Update couple with partner
      await _client.from('couples').update({
        'user_2': userId,
        'invite_code': null, // Burn the code
      }).eq('id', coupleData['id']);

      // Seed default channels for this couple
      await _seedDefaultChannels(coupleData['id'] as String);

      await loadUserData();
      return true;
    } catch (e) {
      debugPrint('[joinCouple] Error: $e');
      rethrow;
    }
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

  /// Toggle Vanilla Mode (Stealth Mode) for the couple.
  Future<void> toggleVanillaMode(bool isVanilla) async {
    if (_couple == null) return;
    
    try {
      await _client.from('couples').update({
        'is_vanilla_mode': isVanilla,
      }).eq('id', _couple!.id);
      
      // Update local state optimistic
      _couple = _couple!.copyWith(isVanillaMode: isVanilla);
      notifyListeners();
      
      // Reload fully to ensure sync
      await loadUserData();
    } catch (e) {
      debugPrint('Error toggling vanilla mode: $e');
    }
  }

  /// Update the global theme color for the couple
  Future<void> updateThemeColor(String hex) async {
    if (_couple == null) return;
    
    try {
      await _client.from('couples').update({
        'theme_color_hex': hex,
      }).eq('id', _couple!.id);
      
      // Update local state optimistic
      _couple = _couple!.copyWith(themeColorHex: hex);
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error updating theme color: $e');
    }
  }

  /// Update display name for the current user's profile
  Future<void> updateDisplayName(String newName) async {
    if (currentUser == null || _profile == null) return;

    try {
      await _client.from('profiles').update({
        'display_name': newName,
      }).eq('id', currentUser!.id);

      _profile = _profile!.copyWith(displayName: newName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating display name: $e');
      rethrow;
    }
  }
}
