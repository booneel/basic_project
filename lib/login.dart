import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'main.dart'; // initializeFirebase, ScheduleScreen 임포트
import 'signup.dart';
import 'wish.dart'; // GoalSettingScreen 임포트
import 'set_calendar.dart'; // CalendarScreen 임포트
import 'profile.dart'; // ProfileScreen 임포트

// 앱의 시작점 (엔트리 포인트)
void main() async {
  // Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    await initializeDateFormatting('ko_KR', null);
    await initializeFirebase();
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              '앱 초기화 실패: $e\n.env 파일과 Firebase 설정을 확인하세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

// 앱의 최상위 위젯 (테마, 홈 화면 설정)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '갓생 플래너',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Pretendard',

        // 공통 버튼 테마
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // 공통 텍스트 필드 테마
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2.0),
          ),
        ),
      ),

      // ⚠️ [수정] Firebase 인증 상태에 따른 초기 화면 결정
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null && !snapshot.data!.isAnonymous) {
            // 로그인된 사용자가 있을 경우 GoalSettingScreen으로 이동
            return const GoalSettingScreen(); // ⚠️ GoalSettingScreen (wish.dart)으로 바로 이동
          }
          return const LoginPage();
        },
      ),

      // 페이지 이동 경로 설정 (전체 앱 라우팅 통합)
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/goal': (context) => const GoalSettingScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// 로그인 페이지 UI
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(); // ⚠️ [추가]
  final _passwordController = TextEditingController(); // ⚠️ [추가]
  bool _isPasswordVisible = false;
  bool _isLoading = false; // ⚠️ [추가]

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ⚠️ [수정] 로그인 로직 (성공 시 /goal로 이동)
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackbar('이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 로그인 성공 시 StreamBuilder가 감지하여 자동으로 GoalSettingScreen으로 이동

    } on FirebaseAuthException catch (e) {
      String errorMessage = _getAuthErrorMessage(e.code);
      _showErrorSnackbar(errorMessage);
    } catch (e) {
      _showErrorSnackbar('로그인 중 알 수 없는 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'user-disabled':
        return '사용자 계정이 비활성화되었습니다.';
      default:
        return '로그인에 실패했습니다. (오류 코드: $errorCode)';
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✨ 1. 로고 수정됨 (Image.asset 사용)
              CircleAvatar(
                radius: 50, // 크기 지정
                backgroundColor: Colors.transparent, // 이미지 배경이 투명할 경우 대비
                child: ClipOval(
                  child: Image.asset(
                    'asset/img/Mark.png', // <-- 사용자님이 요청한 경로
                    height: 100, // CircleAvatar radius * 2
                    width: 100,  // CircleAvatar radius * 2
                    fit: BoxFit.cover, // 원에 꽉 차게
                    errorBuilder: (context, error, stackTrace) {
                      // 이미지를 못 찾을 경우 임시 아이콘
                      return CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.calendar_month_rounded, size: 50, color: Colors.blue[600]),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 타이틀
              const Text(
                '로그인',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '갓생이 되는 지름길로 들어오세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // 폼 필드
              _buildTextField(
                  controller: _emailController, // ⚠️ [수정] 컨트롤러 연결
                  label: '이메일 또는 전화번호',
                  hint: 'test@gmail.com'
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController, // ⚠️ [수정] 컨트롤러 연결
                label: '비밀번호',
                hint: '********',
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onVisibilityToggle: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 아이디/비밀번호 찾기
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () { /* TODO: 아이디 찾기 */ },
                    child: Text('아이디 찾기', style: TextStyle(color: Colors.grey[700])),
                  ),
                  TextButton(
                    onPressed: () { /* TODO: 비밀번호 찾기 */ },
                    child: Text('비밀번호 찾기', style: TextStyle(color: Colors.grey[700])),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 일반 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _login, // ⚠️ [수정] 로그인 로직 연결
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
                    : const Text('로그인'),
              ),

              const SizedBox(height: 32), // 로그인 버튼과 회원가입 링크 사이의 간격

              // 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 없으신가요?', style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: Text('회원가입', style: TextStyle(color: Colors.blue[600])),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 필드를 만드는 공통 헬퍼 위젯
  Widget _buildTextField({
    TextEditingController? controller, // ⚠️ [추가] 컨트롤러 인자
    required String label,
    required String hint,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller, // ⚠️ [수정] 컨트롤러 연결
          obscureText: isPassword && !isPasswordVisible,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onVisibilityToggle,
            )
                : null,
          ),
        ),
      ],
    );
  }
}