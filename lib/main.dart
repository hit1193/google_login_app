// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_login_app/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_login_app/screens/auth_screen.dart';
import 'package:google_login_app/screens/home_screen.dart'; // HomeScreen은 필요에 따라 생성

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 클라이언트 초기화
  await Supabase.initialize(
    url:
        'https://vzwsjbdhbrpdyabflvxu.supabase.co', // ✨ 실제 Supabase 프로젝트 URL로 변경 ✨
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6d3NqYmRoYnJwZHlhYmZsdnh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwODIzODcsImV4cCI6MjA2NjY1ODM4N30.8BKpfvwFZRnwMg_HL4Gr4IIAS0E2HqDOqYQU2pYlJyM', // ✨ 실제 Supabase 프로젝트 Anon Key로 변경 ✨
    authFlowType: AuthFlowType.pkce, // 웹 및 모바일 보안을 위한 PKCE 플로우 설정
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
    // 로그인/로그아웃 시 화면을 자동으로 전환하고, 프로필을 처리합니다.
    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final User? user = data.session?.user; // 현재 세션의 사용자 정보

      print('Supabase Auth Event: $event'); // ✨ 이벤트 로그 추가 ✨

      if (event == AuthChangeEvent.signedIn) {
        print('User signed in: ${user?.id}'); // ✨ 로그인 사용자 ID 로그 추가 ✨
        // 로그인 성공 시 프로필 처리 후 홈 화면으로 이동
        // 이 함수는 주로 Google/OAuth 로그인 시 새로운 사용자 프로필을 생성하는 데 사용됩니다.
        // 이메일/비밀번호 가입 시에는 LoginScreen에서 프로필이 직접 생성됩니다.
        await _createOrUpdateUserProfileForOAuth(user);
        print('Profile creation/update for OAuth user completed.'); // ✨ 프로필 처리 완료 로그 ✨

        // ✨ 이 부분을 다시 확인하세요! ✨
        // navigatorKey.currentState가 null이 아닐 때만 실행
        if (mounted) { //(navigatorKey.currentState != null) {
          print('Navigating to HomeScreen using navigatorKey...');
          // ✨ 이 콜백 안에 내비게이션 코드가 있는지 확인 ✨
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            print('Navigation to HomeScreen initiated via navigatorKey.');
          });
        } else {
          print('NavigatorState is null, cannot navigate to HomeScreen.'); // 이 로그가 찍혔습니다.
        }
      } else if (event == AuthChangeEvent.signedOut) {
        print('User signed out.'); // ✨ 로그아웃 로그 추가 ✨
        // 로그아웃 시 로그인 화면으로 이동
        if (mounted) {
          print('Navigating to LoginScreen...'); // ✨ 내비게이션 시작 로그 ✨
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Navigator.of(context, rootNavigator: true)를 사용하여 최상위 Navigator를 명시적으로 사용
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
            print('Navigation to LoginScreen initiated.'); // ✨ 내비게이션 실행 로그 ✨
          });
        } else {
          print('Widget is not mounted, cannot navigate to LoginScreen.'); // ✨ 위젯 마운트 상태 로그 ✨
        }
      }
      // ✨ AuthChangeEvent.initialSession 제거 - 이 멤버는 더 이상 사용되지 않거나 직접 비교되지 않습니다. ✨
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
  // 이 함수는 Google/OAuth 로그인 시 새로운 사용자 프로필을 생성하거나,
  // 이미 존재하는 프로필이라면 아무것도 하지 않습니다.
  Future<void> _createOrUpdateUserProfileForOAuth(User? user) async {
    if (user == null) {
      print('User is null in _createOrUpdateUserProfileForOAuth.');
      return;
    }

    try {
      print('Checking if user profile exists for ${user.id}...'); // ✨ 프로필 존재 여부 확인 로그 ✨
      // 1. `users` 테이블에 해당 user.id가 이미 존재하는지 확인
      final response = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .limit(1)
          .execute();

      // 만약 데이터가 존재하면(이미 프로필이 있다면) 추가 생성하지 않고 완료
      if (response.data != null && (response.data as List).isNotEmpty) {
        print('사용자 프로필이 이미 존재합니다: ${user.id}. 스킵합니다.'); // ✨ 스킵 로그 ✨
        return;
      }

      // 2. 새로운 프로필이라면 `users` 테이블에 정보 삽입
      // Google/OAuth 로그인 시에는 회사 이름을 입력받지 않으므로, 기본 회사 UUID를 사용합니다.
      // ✨ 아래 'YOUR_DEFAULT_COMPANY_UUID'를 실제 유효한 회사 UUID로 변경해야 합니다. ✨
      // 이 UUID는 Supabase의 `companies` 테이블에 미리 생성되어 있어야 합니다.
      print('Creating new user profile for ${user.id}...'); // ✨ 새 프로필 생성 로그 ✨
      await supabase.from('users').insert({
        'id': user.id,
        'company_id': 'YOUR_DEFAULT_COMPANY_UUID', // ✨ 중요: 실제 회사 UUID로 대체 (Google 로그인 시) ✨
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
            foregroundColor: Colors.black,
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
