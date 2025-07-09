// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_login_app/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_login_app/screens/home_screen.dart'; // HomeScreen은 필요에 따라 생성

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 클라이언트 초기화
  await Supabase.initialize(
    url: 'https://vzwsjbdhbrpdyabflvxu.supabase.co', // ✨ 실제 Supabase 프로젝트 URL로 변경 ✨
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6d3NqYmRoYnJwZHlhYmZsdnh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwODIzODcsImV4cCI6MjA2NjY1ODM4N30.8BKpfvwFZRnwMg_HL4Gr4IIAS0E2HqDOqYQU2pYlJyM', // ✨ 실제 Supabase 프로젝트 Anon Key로 변경 ✨
    // authFlowType: AuthFlowType.pkce, // 웹 및 모바일 보안을 위한 PKCE 플로우 설정 (이전 오류 해결됨)
    debug: true, // 디버그 모드에서 Supabase 로그를 볼 수 있습니다.
  );

  runApp(const MyApp());
}

// Supabase 클라이언트 인스턴스 (다른 화면에서도 사용)
final supabase = Supabase.instance.client;

// ✨ 새로운 글로벌 네비게이터 키 추가 ✨
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Supabase 인증 상태 변경 리스너
    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session; // 현재 세션 정보
      final User? user = session?.user; // 현재 세션의 사용자 정보

      print('Supabase Auth Event: $event'); // ✨ 이벤트 로그 추가 ✨

      // navigatorKey.currentState가 유효한지 확인하고, 위젯이 마운트된 상태에서만 내비게이션 시도
      // 이 로직은 `WidgetsBinding.instance.addPostFrameCallback` 내부로 이동해야 더 안전합니다.

      if (event == AuthChangeEvent.signedIn) {
        print('User signed in: ${user?.id}'); // ✨ 로그인 사용자 ID 로그 추가 ✨
        await _createOrUpdateUserProfileForOAuth(user);
        print('Profile creation/update for OAuth user completed.'); // ✨ 프로필 처리 완료 로그 ✨

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentState?.mounted == true) { // navigatorState가 마운트되었는지 확인
            print('Navigating to HomeScreen using navigatorKey...');
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            print('Navigation to HomeScreen initiated via navigatorKey.');
          } else {
            print('NavigatorState is not mounted or null, cannot navigate to HomeScreen.');
          }
        });
      } else if (event == AuthChangeEvent.signedOut) {
        print('User signed out.'); // ✨ 로그아웃 로그 추가 ✨
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentState?.mounted == true) { // navigatorState가 마운트되었는지 확인
            print('Navigating to LoginScreen...'); // ✨ 내비게이션 시작 로그 ✨
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
            print('Navigation to LoginScreen initiated.'); // ✨ 내비게이션 실행 로그 ✨
          } else {
            print('NavigatorState is not mounted or null, cannot navigate to LoginScreen.');
          }
        });
      }
      // AuthChangeEvent.initialSession은 이제 직접 처리하지 않습니다.
      else if (event == AuthChangeEvent.userUpdated) {
        print('User updated: ${user?.id}');
      } else if (event == AuthChangeEvent.passwordRecovery) {
        print('Password recovery initiated for user: ${user?.id}');
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        print('Token refreshed for user: ${user?.id}');
      } else {
        print('Unhandled Auth Event: $event');
      }
    });
  }

  // `users` (프로필) 테이블에 사용자 정보 생성/업데이트 함수 (주로 OAuth 사용자용)
  Future<void> _createOrUpdateUserProfileForOAuth(User? user) async {
    if (user == null) {
      print('User is null in _createOrUpdateUserProfileForOAuth.');
      return;
    }

    try {
      print('Checking if user profile exists for ${user.id}...'); // ✨ 프로필 존재 여부 확인 로그 ✨
      // 1. `users` 테이블에 해당 user.id가 이미 존재하는지 확인
      // .select()는 이제 직접 List<Map<String, dynamic>>를 반환합니다.
      final List<Map<String, dynamic>> response = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .limit(1); // .execute() 대신 .select() 직접 사용

      // 만약 데이터가 존재하면(이미 프로필이 있다면) 추가 생성하지 않고 완료
      // response는 이제 PostgrestResponse 객체가 아닌 List<Map<String, dynamic>> 입니다.
      if (response.isNotEmpty) { // response.data 대신 response를 직접 사용
        print('사용자 프로필이 이미 존재합니다: ${user.id}. 스킵합니다.'); // ✨ 스킵 로그 ✨
        return;
      }

      // 2. 새로운 프로필이라면 `users` 테이블에 정보 삽입
      print('Creating new user profile for ${user.id}...'); // ✨ 새 프로필 생성 로그 ✨
      await supabase.from('users').insert({
        'id': user.id,
        // ✨ 중요: 아래 'YOUR_DEFAULT_COMPANY_UUID'를 실제 유효한 회사 UUID로 변경해야 합니다. ✨
        // 이 UUID는 Supabase의 `companies` 테이블에 미리 생성되어 있어야 합니다.
        'company_id': 'YOUR_DEFAULT_COMPANY_UUID', // 예: 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
        'name': user.email?.split('@')[0] ?? '새 사용자', // 이메일 앞부분을 기본 이름으로
        'role': 'employee', // 기본 역할 (예: 'employee', 'admin' 등)
        'is_company_admin': false, // 테이블 스키마에 따라 포함
        'email': user.email, // email 컬럼이 users 테이블에 존재한다는 전제 하에 포함
        'avatar_url': user.userMetadata?['avatar_url'], // Google 프로필 사진 URL (있다면)
      });
      print('새로운 사용자 프로필이 성공적으로 생성되었습니다 (OAuth): ${user.id}.'); // ✨ 성공 로그 ✨
    } catch (e) {
      print('프로필 생성/업데이트 중 오류 발생 (OAuth): $e'); // ✨ 오류 로그 ✨
      // 여기서 UI에 오류 메시지를 표시할 필요는 없습니다. (백그라운드 작업)
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Supabase 로그인 데모',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.black,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black, // 로그인 버튼 색상에 맞춤
            foregroundColor: Colors.black, // 텍스트/아이콘 색상
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // 앱 시작 시 로그인 상태에 따라 초기 화면 결정
      home: supabase.auth.currentUser == null
          ? LoginScreen() // 로그인되지 않았으면 로그인 화면
          : const HomeScreen(), // 로그인되어 있으면 홈 화면
    );
  }
}