import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // <-- 삭제됨
import 'signup.dart';
import 'wish.dart';

// 앱의 시작점 (엔트리 포인트)
void main() async {
  // Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  // wish.dart에 있던 한국 로케일 초기화 코드를 여기로 이동
  await initializeDateFormatting('ko_KR', null);

  runApp(const MyApp());
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
        fontFamily: 'Pretendard', // TODO: 폰트 파일 추가 시 주석 해제

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

      // 첫 화면으로 'LoginPage'를 지정
      home: const LoginPage(),

      // 페이지 이동 경로 설정
      routes: {
        '/signup': (context) => const SignUpPage(),
        '/goal': (context) => const GoalSettingScreen(), // wish.dart의 화면
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
  bool _isPasswordVisible = false;
  // bool _isGoogleLoading = false; // <-- 삭제됨

  // Future<void> _handleGoogleSignIn() async { ... } // <-- 구글 로그인 함수 전체 삭제됨

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
              Text(
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
              _buildTextField(label: '이메일 또는 전화번호', hint: 'test@gmail.com'),
              const SizedBox(height: 16),
              _buildTextField(
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
                onPressed: () {
                  // TODO: 일반 로그인 ID/PW 검증 로직
                  Navigator.pushReplacementNamed(context, '/goal');
                },
                child: Text('로그인'),
              ),

              // const SizedBox(height: 24), <-- "Or" 구분선과 함께 삭제됨
              // Row( ... "Or" 구분선 ... ),  <-- 삭제됨
              // const SizedBox(height: 24), <-- 구글 로그인 버튼과 함께 삭제됨
              // OutlinedButton.icon( ... ), <-- 구글 로그인 버튼 삭제됨

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

