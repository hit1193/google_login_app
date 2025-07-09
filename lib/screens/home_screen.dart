// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase 클라이언트 인스턴스 (main.dart에서 정의된 전역 인스턴스를 사용)
final supabase = Supabase.instance.client;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  String? _companyName;
  String? _userRole;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // `users` 테이블에서 사용자 정보 가져오기
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      // `users` 테이블에서 현재 사용자의 정보와 연결된 회사 정보 가져오기
      // 'name' 컬럼을 사용하고, 'companies(name)'으로 회사 이름을 조인합니다.
      // .single() 메서드는 Map<String, dynamic>을 직접 반환합니다.
      final Map<String, dynamic> response = await supabase
          .from('users')
          .select('name, role, companies(name)')
          .eq('id', userId)
          .single(); // .execute() 대신 .single() 직접 사용

      // response는 이제 Map<String, dynamic> 타입이므로, .data 속성에 접근할 필요가 없습니다.
      // .single()은 결과가 없으면 예외를 던지므로, response가 null이 될 일은 없습니다.
      // 따라서 if (response != null) 검사는 필요 없지만, 데이터가 올바른지 확인하는 로직은 유효합니다.
      setState(() {
        _userName = response['name'] as String?; // 직접 'name' 키에 접근
        _userRole = response['role'] as String?; // 직접 'role' 키에 접근
        // 'companies'는 중첩된 맵이므로, 먼저 'companies' 키에 접근 후 'name' 키에 접근
        _companyName = (response['companies'] as Map<String, dynamic>?)?['name'] as String?;
      });
    } catch (e) {
      print('프로필 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 로드 오류: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  // 로그아웃
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      // main.dart의 onAuthStateChange 리스너가 로그인 화면으로 이동시켜줄 것입니다.
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 오류: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자산 관리 홈')),
      body: Center(
        child: _isLoadingProfile
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '환영합니다, ${_userName ?? '사용자'}님!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '소속 회사: ${_companyName ?? '정보 없음'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '역할: ${_userRole ?? '정보 없음'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _signOut,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('로그아웃', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
