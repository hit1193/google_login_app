// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setState(() { _isLoadingProfile = true; });
    try {
      final userId = supabase.auth.currentUser!.id;
      // `users` 테이블에서 현재 사용자의 정보와 연결된 회사 정보 가져오기
      // 'name' 컬럼을 사용하고, 'companies(name)'으로 회사 이름을 조인합니다.
      final response = await supabase
          .from('users')
          .select('name, role, companies(name)')
          .eq('id', userId)
          .single()
          .execute();

      if (response.data != null) {
        setState(() {
          _userName = response.data['name'];
          _userRole = response.data['role'];
          _companyName = response.data['companies']['name'];
        });
      }
    } catch (e) {
      print('프로필 로드 오류: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 로드 오류: $e')),
        );
      }
    } finally {
      setState(() { _isLoadingProfile = false; });
    }
  }

  // 로그아웃
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      // main.dart의 onAuthStateChange 리스너가 로그인 화면으로 이동시켜줄 것입니다.
    } on AuthException catch (e) {
      if(mounted) {
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
