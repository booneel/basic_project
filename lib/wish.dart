import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'diet.dart'; // AnalysisScreen 임포트
import 'main.dart'; // ApiConfig, initializeFirebase 임포트

/// LLM에서 추출한 목표 키워드 데이터를 담는 클래스
class GoalKeyword {
  final String goal;
  final String keyword;

  GoalKeyword({required this.goal, required this.keyword});

  factory GoalKeyword.fromJson(Map<String, dynamic> json) {
    return GoalKeyword(
      goal: json['goal'] as String,
      keyword: json['keyword'] as String,
    );
  }

  @override
  String toString() {
    return '$goal: $keyword';
  }
}

// -----------------------------------------------------------
// main.dart에서 실행되므로 main 함수는 제거하고 GoalSettingScreen만 남김

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeGoal() async {
    final goalText = _controller.text.trim();
    if (goalText.isEmpty) {
      _showAlertDialog('알림', '목표를 입력해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const systemPrompt =
          "당신은 사용자의 목표를 분석하여 핵심 키워드 목록을 생성하는 전문가입니다. 사용자가 입력한 목표를 바탕으로 3~5개의 가장 중요한 핵심 키워드를 추출하여 JSON 객체 배열로 반환하세요. 각 키워드는 해당 목표의 구체적인 실행 요소가 되어야 합니다.";

      final userQuery = "다음 목표를 분석하고 핵심 키워드를 추출해 주세요: '$goalText'";

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': userQuery},
            ],
          },
        ],
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'goal': {'type': 'STRING', 'description': '사용자의 원 목표 (축약된 형태)'},
                'keyword': {'type': 'STRING', 'description': '구체적인 핵심 실행 키워드'},
              },
              'required': ['goal', 'keyword'],
            },
          },
        },
      };

      // API Key는 Canvas 환경에서 자동으로 채워지므로, 베이스 URL만 사용
      final response = await http.post(
        Uri.parse(ApiConfig.GEMINI_API_BASE_URL),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        final jsonText =
        result['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (jsonText != null) {
          final List<dynamic> keywordData = jsonDecode(jsonText);
          final List<GoalKeyword> keywords = keywordData
              .map((item) => GoalKeyword.fromJson(item as Map<String, dynamic>))
              .toList();

          if (keywords.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalysisScreen(keywords: keywords),
              ),
            );
          } else {
            _showAlertDialog('분석 실패', 'LLM이 유효한 키워드를 추출하지 못했습니다.');
          }
        } else {
          _showAlertDialog('응답 오류', 'LLM 응답에서 유효한 JSON을 찾을 수 없습니다.');
        }
      } else {
        _showAlertDialog('API 오류', '키워드 분석에 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      _showAlertDialog('오류 발생', '데이터 처리 중 문제가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 75),
                        // Image.asset 대신 Icon 사용
                        Icon(
                          Icons.insights,
                          size: 150,
                          color: Colors.purple[300],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          '당신의 목표를\n설정해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 55),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black),
                          ),
                          child: TextField(
                            controller: _controller,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            decoration: const InputDecoration.collapsed(
                              hintText: '살을 빼고 싶고,\n요리사가 되고싶어',
                              hintStyle: TextStyle(
                                fontSize: 24,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _analyzeGoal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.black),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black,
                            ),
                          )
                              : const Text(
                            '다음 (목표 분석)',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isLoading ? 'AI가 목표를 분석 중입니다...' : '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}