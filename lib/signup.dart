import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final TextEditingController _birthDateController = TextEditingController();

  // 날짜 선택기 (DatePicker)를 띄우는 함수
  Future<void> _selectDate() async {
    //
    // showDatePicker는 context를 필요로 하므로,
    // 이 위젯은 반드시 MaterialApp 하위에서 호출되어야 합니다.
    //
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        // 날짜 형식을 'YYYY/MM/DD'로 변경
        _birthDateController.text =
        "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            /* TODO: 나중에 뒤로가기 구현 */
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 타이틀
              Text(
                '회원 가입',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                '갓생 플래너에 주인공이 되어보세요!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // 2. 폼 필드
              _buildTextField(label: '이름', hint: '이백수'),
              const SizedBox(height: 16),
              _buildTextField(label: '이메일', hint: 'test@gmail.com'),
              const SizedBox(height: 16),
              _buildTextField(
                label: '생일',
                hint: '18/03/2024',
                controller: _birthDateController, // 컨트롤러 연결
                suffixIcon: Icons.calendar_today,
                onSuffixIconTap: _selectDate, // 탭할 때 날짜 선택기 호출
              ),
              const SizedBox(height: 16),
              _buildTextField(label: '전화번호', hint: '010-1111-1111'),
              const SizedBox(height: 16),
              _buildTextField(
                label: '패스워드',
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
              _buildTextField(
                label: '패스워드 확인',
                hint: '********',
                isPassword: true,
                isPasswordVisible: _isConfirmPasswordVisible,
                onVisibilityToggle: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              const SizedBox(height: 32),

              // 3. 회원가입 버튼
              ElevatedButton(
                onPressed: () {
                  // 현재 페이지(SignUpPage)를 닫고
                  // 이전 페이지(LoginPage)로 돌아갑니다.
                  Navigator.pop(context);
                },
                child: Text('회원 가입'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 4. 로그인 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 있으신가요?', style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('로그인', style: TextStyle(color: Colors.blue[600])),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 필드를 만드는 공통 헬퍼 위젯 (컨트롤러 파라미터 추가)
  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
  }) {
    //
    // 공통 InputDecoration 테마가 없으므로
    // 여기서 직접 스타일을 적용하거나,
    // 사용하는 앱의 MaterialApp 테마를 따르게 됩니다.
    //
    final inputDecorationTheme = InputDecorationTheme(
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
    );

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
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          readOnly: onSuffixIconTap != null,
          onTap: onSuffixIconTap,
          decoration: InputDecoration(
            hintText: hint,
            // 테마에서 스타일을 가져와 적용
            hintStyle: inputDecorationTheme.hintStyle,
            border: inputDecorationTheme.border,
            enabledBorder: inputDecorationTheme.enabledBorder,
            focusedBorder: inputDecorationTheme.focusedBorder,
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onVisibilityToggle,
            )
                : (suffixIcon != null
                ? IconButton(
              icon: Icon(suffixIcon, color: Colors.grey),
              onPressed: onSuffixIconTap,
            )
                : null),
          ),
        ),
      ],
    );
  }
}