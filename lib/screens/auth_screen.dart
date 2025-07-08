// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In 패키지 임포트

// 전역 Supabase 클라이언트 인스턴스 (main.dart에서 초기화됨)
final supabase = Supabase.instance.client;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // 로딩 상태 관리

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 이메일/비밀번호 회원가입 함수
  Future<void> _signUp() async {
    setState(() { _isLoading = true; });
    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      debugPrint("email:${_emailController.text}, password:${_passwordController.text}");

      if (res.user != null) {
        _showSnackBar('회원가입 성공! 이메일 확인이 필요할 수 있습니다.');
        // 새롭게 가입한 사용자의 프로필 추가 (company_id 등)
        await _createProfile(res.user!.id, res.user!.email);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // 이메일/비밀번호 로그인 함수
  Future<void> _signIn() async {
    setState(() { _isLoading = true; });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _showSnackBar('로그인 성공!');
      // AuthStateChange 리스너가 홈 화면으로 이동시켜 줄 것입니다.
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Google 소셜 로그인 함수
  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; });
    try {
      await supabase.auth.signInWithOAuth(
        Provider.google, // Supabase가 제공하는 Google OAuth Provider
        // 중요: 여기에 Google Cloud Console 및 플러터 설정에 맞춘 Redirect URL을 입력해야 합니다.
        // 일반적으로 iOS는 'io.supabase.flutterquickstart://login-callback/'
        // Android는 'https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback' 또는 커스텀 스키마
        // Supabase 프로젝트 설정 -> Authentication -> Providers -> Google 에서 "Redirect URIs"를 확인하세요.
        redirectTo: 'https://vzwsjbdhbrpdyabflvxu.supabase.co/auth/vo/callback', // ✨ 실제 Redirect URL로 변경 ✨
      );
      _showSnackBar('Google 로그인 요청 완료. 브라우저/팝업을 확인하세요.');
      // Google 로그인 성공 후, Supabase Auth 상태 변경 리스너가 처리합니다.
      // (main.dart에 있는 onAuthStateChange.listen)
      // 이 리스너 내부에서 `_createProfile`을 호출하여 프로필을 생성합니다.
    } on AuthException catch (e) {
      _showSnackBar('Google 로그인 오류: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('예상치 못한 오류 발생: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // profiles 테이블에 사용자 정보 생성/업데이트 함수
  // 로그인된 사용자의 ID를 기반으로 프로필을 생성하거나, 이미 있다면 넘깁니다.
  Future<void> _createProfile(String userId, String? email) async {
    try {
      // 1. profiles 테이블에 해당 user.id가 이미 존재하는지 확인
      // .limit(1)은 쿼리 결과를 1개로 제한하며, .execute()는 Raw Response를 반환합니다.
      final response = await supabase
          .from('users')
          .select('id') // ID만 선택하여 존재 여부 확인
          .eq('id', userId)
          .limit(1)
          .execute();

      // 만약 데이터가 존재하면(이미 프로필이 있다면) 추가 생성하지 않고 종료
      if (response.data != null && (response.data as List).isNotEmpty) {
        print('User profile already exists for $userId.');
        return;
      }

      // 2. 새로운 프로필이라면 `profiles` 테이블에 정보 삽입
      // ✨ 아래 'YOUR_DEFAULT_COMPANY_UUID'를 실제 유효한 회사 UUID로 변경해야 합니다. ✨
      // 이 UUID는 Supabase의 `companies` 테이블에 미리 생성되어 있어야 합니다.
      await supabase.from('users').insert({
        'id': userId,
        'company_id': '2127321d-1a15-401d-89db-5b1bc73a2268', // ✨ 중요: 실제 회사 UUID로 대체 ✨
        'full_name': email?.split('@')[0] ?? '새 사용자', // 이메일 앞부분을 기본 이름으로
        'role': 'employee', // 기본 역할 (예: 'employee', 'admin' 등)
        // 'avatar_url': user.userMetadata?['avatar_url'] // Google 프로필 사진 URL을 가져오려면 userMetadata 접근 필요 (현재는 사용 안 함)
      });
      print('New user profile created for $userId.');
      _showSnackBar('프로필 정보가 저장되었습니다.');
    } catch (e) {
      print('프로필 생성/업데이트 중 오류 발생: $e');
      _showSnackBar('프로필 정보 처리 중 오류 발생: $e', isError: true);
    }
  }

  // SnackBar를 통해 사용자에게 메시지 표시
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회사 자산 관리 로그인')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // 너비 가득 채우기
            children: [
              const Text(
                '환영합니다!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent),
              ),
              const SizedBox(height: 40),

              // --- 이메일/비밀번호 입력 필드 ---
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // --- 로그인 / 회원가입 버튼 ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  ElevatedButton(
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('로그인', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton( // 회원가입은 좀 더 보조적인 느낌
                    onPressed: _signUp,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                    ),
                    child: const Text('회원가입', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              const Divider(thickness: 1, color: Colors.grey),
              const SizedBox(height: 20),

              // --- Google 로그인 버튼 ---
              const Text(
                '또는 소셜 계정으로 로그인',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Image.asset(
                  'assets/google_logo.png', // Google 로고 이미지 (아래 assets 설명 참고)
                  height: 24,
                ),
                label: const Text('Google로 로그인'),
                onPressed: _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // 배경 흰색
                  foregroundColor: Colors.black87, // 글자 검정색
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
