// lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService with ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  AuthService() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 현재 세션 확인
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = _supabase.auth.currentUser;
        await _fetchUserProfile();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 구글 로그인 실행
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was canceled');
      }

      // 구글 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Supabase에 구글 인증 정보로 로그인
      final AuthResponse res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      _user = res.user;

      // 사용자 프로필 확인 또는 생성
      await _fetchUserProfile();

    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_user == null) return;

    try {
      // 프로필 정보 가져오기
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();

      _profile = response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // 프로필이 없는 경우 null로 설정
      _profile = null;
    }
  }

  Future<void> createOrUpdateProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Edge Function 호출하여 프로필 생성/업데이트
      final response = await _supabase.functions.invoke(
        'auth-helper',
        body: {
          'action': 'create_profile',
          'profileData': profileData,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create profile: ${response.data}');
      }

      // 프로필 정보 업데이트
      await _fetchUserProfile();

    } catch (e) {
      debugPrint('Error creating/updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _googleSignIn.signOut();
      await _supabase.auth.signOut();

      _user = null;
      _profile = null;

    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
