import 'package:flutter/material.dart';
import 'main.dart'; // ScheduleScreen 임포트
import 'wish.dart'; // GoalKeyword 임포트

// main.dart에서 실행되므로 main 함수는 제거하고 AnalysisScreen만 남김

/// 목표 분석 결과를 표시하고, 사용자가 핵심 키워드를 선택하는 화면
class AnalysisScreen extends StatelessWidget {
  // 이전 화면에서 전달받은 분석된 키워드 리스트
  final List<GoalKeyword> keywords;

  const AnalysisScreen({super.key, required this.keywords});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('목표 분석 및 선택'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '어느 부분에 집중하고 싶으신가요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 키워드 중, 오늘 스케줄에 반영하고 싶은 핵심 목표를 하나 선택하세요.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            if (keywords.isEmpty)
              const Center(
                child: Text(
                  '분석된 키워드가 없습니다. 다시 시도해 주세요.',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: keywords.length,
                  itemBuilder: (context, index) {
                    final keyword = keywords[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildOptionButton(context, keyword),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(BuildContext context, GoalKeyword keyword) {
    return ElevatedButton(
      onPressed: () {
        // 선택된 키워드를 ScheduleScreen으로 전달하여 LLM 스케줄 생성을 요청
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScheduleScreen(goalKeyword: keyword.keyword),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        minimumSize: const Size(double.infinity, 100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.purple.shade200, width: 2),
        ),
        padding: const EdgeInsets.all(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.purple[400]),
              const SizedBox(width: 8),
              Text(
                keyword.keyword,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '주요 목표: ${keyword.goal}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '스케줄 생성 →',
              style: TextStyle(
                fontSize: 14,
                color: Colors.purple[300],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
