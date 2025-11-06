import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _isGoogleLoading = false; // 구글 로그인 로딩 상태 변수

  // 웹(Web) 전용 ID 선언부를 주석 처리 (모바일에서는 필요 없음)
  // final String _webClientId = "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com";

  // 구글 로그인 처리 함수
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true; // 로딩 시작
    });

    // ✨ 모바일(iOS/Android)에서는 괄호를 비워두어야 합니다.
    final GoogleSignIn googleSignIn = GoogleSignIn();

    try {
      // 구글 로그인 시도
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('구글 로그인이 취소되었습니다.')),
          );
        }
        return;
      }

      // (선택 사항) Firebase Auth와 연동 시
      // final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      // ... (Firebase 인증 로직) ...


      // 로그인 성공! 'goal' (GoalSettingScreen) 페이지로 이동
      if (mounted) {
        // pushReplacementNamed: 뒤로가기 버튼으로 로그인 화면에 못 오게 함
        Navigator.pushReplacementNamed(context, '/goal');
      }

    } catch (error) {
      // 오류 발생 시
      debugPrint('구글 로그인 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인에 실패했습니다: $error')),
        );
      }
    } finally {
      // 성공하든 실패하든 로딩 종료
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
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
              // 로고
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                // TODO: 'assets/logo.png'와 같은 로고 이미지로 변경
                child: Icon(Icons.calendar_month_rounded,
                    size: 50, color: Colors.blue[600]),
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
              const SizedBox(height: 24),

              // "Or" 구분선
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Or', style: TextStyle(color: Colors.grey[600])),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 24),

              // Google 로그인 버튼
              OutlinedButton.icon(
                // 로딩 중이 아닐 때만 버튼 활성화
                onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                icon: _isGoogleLoading
                    ? Container( // 로딩 중이면 스피너 표시
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: Colors.grey[600],
                  ),
                )
                    : Image.asset( // TODO: 'assets/google_logo.png' 추가 및 등록
                  'assets/google_logo.png', // <-- 실제 구글 로고 이미지 경로
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    // 임시 아이콘 (로고 없을 시)
                    return Icon(Icons.g_mobiledata_rounded, color: Colors.blue);
                  },
                ),
                label: Text(
                  _isGoogleLoading ? '로그인 중...' : 'Google 계정으로 로그인',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[100], // 로딩 중 배경색
                ),
              ),
              const SizedBox(height: 32),

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

