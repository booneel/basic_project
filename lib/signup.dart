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

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // 'MyApp'의 라우트 스택에서 현재 페이지를 닫고 이전(로그인) 페이지로
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 타이틀
              Text(
                '회원 가입',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '갓생 플래너에 주인공이 되어보세요!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // 폼 필드
              _buildTextField(label: '이름', hint: '이백수'),
              const SizedBox(height: 16),
              _buildTextField(label: '이메일', hint: 'test@gmail.com'),
              const SizedBox(height: 16),
              _buildTextField(
                label: '생일',
                hint: '18/03/2024',
                controller: _birthDateController,
                suffixIcon: Icons.calendar_today,
                onSuffixIconTap: _selectDate,
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

              // 회원가입 버튼
              ElevatedButton(
                onPressed: () {
                  // 현재 페이지(SignUpPage)를 닫고
                  // 이전 페이지(LoginPage)로 돌아갑니다.
                  Navigator.pop(context);
                },
                child: Text('회원 가입'),
              ),
              const SizedBox(height: 32),

              // 로그인 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 있으신가요?', style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // 로그인 페이지로 돌아가기
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

  // 텍스트 필드 헬퍼 위젯
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