// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In 패키지 임포트

// Supabase 클라이언트 인스턴스 (main.dart에서 초기화됨)
final supabase = Supabase.instance.client;

// AppUser 모델 (사용자 정보 저장용)
class AppUser {
  final String id;
  final String email;
  final String? companyId;
  final String? companyName;

  AppUser({
    required this.id,
    required this.email,
    this.companyId,
    this.companyName,
  });
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController(); // ✨ 회사명 입력 컨트롤러 추가 ✨
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose(); // ✨ 컨트롤러 dispose ✨
    super.dispose();
  }

  // 이메일/비밀번호 로그인 함수
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = res.user;

      if (user != null) {
        // 사용자 프로필 정보 가져오기 (users 테이블과 companies 테이블 조인)
        // 'users' 테이블에 'email' 컬럼이 있다는 전제 하에 사용
        final userProfileResponse = await supabase
            .from('users')
            .select('*, companies(name)') // users 테이블의 모든 컬럼과 companies 테이블의 name 컬럼 조인
            .eq('id', user.id)
            .single()
            .execute(); // .execute()를 사용하여 PostgrestResponse 반환

        String? companyName;
        String? companyId = userProfileResponse.data?['company_id']?.toString(); // UUID는 문자열로 처리

        if (userProfileResponse.data?['companies'] != null) {
          companyName = userProfileResponse.data?['companies']['name'];
        }

        final appUser = AppUser(
          id: user.id,
          email: user.email ?? '',
          companyId: companyId,
          companyName: companyName,
        );

        _showSnackBar('로그인 성공! 회사: ${appUser.companyName ?? '정보 없음'}');
        // main.dart의 onAuthStateChange 리스너가 홈 화면으로 이동시켜 줄 것입니다.
      } else {
        _showSnackBar('로그인 실패: 이메일 또는 비밀번호를 확인하세요.', isError: true);
      }
    } on AuthException catch (e) {
      _showSnackBar('로그인 오류: ${e.message}', isError: true);
    } catch (e) {
      print('오류 상세: $e');
      _showSnackBar('알 수 없는 오류 발생: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 이메일/비밀번호 회원가입 함수 (회사명 입력 포함)
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    final String companyName = _companyNameController.text.trim();
    if (companyName.isEmpty) {
      _showSnackBar('회사명을 입력해주세요.', isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // 1. 회사명으로 company_id 가져오기
      final companyResponse = await supabase
          .from('companies')
          .select('id')
          .eq('name', companyName)
          .single()
          .execute();

      if (companyResponse.data == null) {
        _showSnackBar('존재하지 않는 회사명입니다. 정확한 회사명을 입력하거나 관리자에게 문의하세요.', isError: true);
        setState(() { _isLoading = false; });
        return;
      }
      final String companyId = companyResponse.data!['id'];

      // 2. Supabase Auth에 회원가입
      final AuthResponse authRes = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authRes.user != null) {
        // 3. 회원가입 성공 후 users 테이블에 프로필 정보 삽입
        // (main.dart의 onAuthStateChange 리스너는 OAuth용으로 분리되었으므로, 여기서 직접 처리)
        final User user = authRes.user!;
        await supabase.from('users').insert({
          'id': user.id,
          'company_id': companyId, // 조회한 company_id 사용
          'name': user.email?.split('@')[0] ?? '새 사용자',
          'role': 'employee',
          'is_company_admin': false,
          'email': user.email,
          'avatar_url': user.userMetadata?['avatar_url'],
        });

        _showSnackBar('회원가입 성공! 이메일 확인이 필요할 수 있습니다.');
        // 자동 로그인될 경우 main.dart의 리스너가 홈 화면으로 이동시킬 것입니다.
      } else {
        _showSnackBar('회원가입 실패: 사용자 정보를 확인하세요.', isError: true);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      print('오류 상세: $e');
      _showSnackBar('알 수 없는 오류 발생: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Google 소셜 로그인 함수
  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; });
    try {
      print('구글 로그인 성공!');
      await supabase.auth.signInWithOAuth(
        Provider.google,
        redirectTo: "io.supabase.flutterquickstart://login-callback", // ✨ 실제 Redirect URL로 변경 ✨
      );
      _showSnackBar('Google 로그인 요청 완료. 브라우저/팝업을 확인하세요.');
      // Google 로그인 성공 후, main.dart의 onAuthStateChange 리스너가 처리합니다.
    } on AuthException catch (e) {
      _showSnackBar('Google 로그인 오류: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('예상치 못한 오류 발생: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
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
    const double formWidth = 400.0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: formWidth,
            child: Card(
              color: Colors.white,
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset(
                        'assets/plug4asset.png',
                        height: 300,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return '유효한 이메일을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField( // ✨ 회사명 입력 필드 추가 ✨
                        controller: _companyNameController,
                        decoration: const InputDecoration(
                          labelText: '회사명',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '회사명을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          _signUp(); // 회원가입 버튼 클릭 시 _signUp 함수 호출
                        },
                        child: const Text(
                          '계정이 없으신가요? 회원가입',
                          style: TextStyle(fontSize: 15, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(thickness: 1, color: Colors.grey),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                        ),
                        label: const Text('Google로 로그인'),
                        onPressed: _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
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
            ),
          ),
        ),
      ),
    );
  }
}
