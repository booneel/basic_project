import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnalysisScreen(),
    );
  }
}
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '어느 부분에\n집중하고 싶으신가요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 39,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 58),
              _buildOptionButton(context, '다이어트'),
              const SizedBox(height: 25),
              _buildOptionButton(context, '요리공부'),
              const SizedBox(height: 25),
              _buildOptionButton(context, '조리공부'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(BuildContext context, String text) {
    return ElevatedButton(
      onPressed: () {
        // TODO: Handle option selection
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black,
        elevation: 6,
        minimumSize: const Size(double.infinity, 100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
      ),
    );
  }
}