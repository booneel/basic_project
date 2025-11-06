import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // TimeoutException 사용
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart'; // ScheduleScreen, ApiConfig, getDb, getScheduleCollectionPath, ScheduleItem 임포트
import 'wish.dart'; // GoalKeyword 임포트

// ---------------- 1. 목표 분석 결과 화면 (AnalysisScreen) ----------------

/// 목표 분석 결과를 표시하고, 사용자가 핵심 키워드를 선택하는 화면
class AnalysisScreen extends StatelessWidget {
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
        // 🌟 [핵심 수정] LLM 생성 및 저장을 담당할 Generator Screen으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ScheduleGeneratorScreen(goalKeyword: keyword.keyword),
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
              '스케줄 생성 및 저장 →',
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

// ---------------- 2. 스케줄 생성, 저장, 이동 화면 (ScheduleGeneratorScreen) ----------------

class ScheduleGeneratorScreen extends StatefulWidget {
  final String goalKeyword;

  const ScheduleGeneratorScreen({super.key, required this.goalKeyword});

  @override
  State<ScheduleGeneratorScreen> createState() =>
      _ScheduleGeneratorScreenState();
}

class _ScheduleGeneratorScreenState extends State<ScheduleGeneratorScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _generatedScheduleData = []; // ScheduleItem 대신 JSON 데이터 사용

  // Note: main.dart의 ScheduleItem 클래스가 필요합니다.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScheduleProcess(widget.goalKeyword);
    });
  }

  // 전체 생성 및 저장 프로세스 관리
  Future<void> _initScheduleProcess(String goalKeyword) async {
    await _generateSchedule(goalKeyword); // 1. LLM 스케줄 생성

    if (_generatedScheduleData.isNotEmpty && _error == null) {
      await _saveScheduleAndNavigate(); // 2. DB 저장 및 이동
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTodayDateKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // 🌟 LLM을 호출하여 목표 기반 스케줄 생성 (30초 타임아웃 적용)
  Future<void> _generateSchedule(String goalKeyword) async {
    try {
      const systemPrompt =
          "당신은 일일 스케줄 생성 전문가입니다. 사용자의 목표 키워드를 바탕으로 구체적이고 실현 가능한 하루(09:00 ~ 21:00) 스케줄을 5~7개의 항목으로 구성하여 JSON 객체 배열로 반환하세요. 'isGoalSchedule' 필드는 true로 설정해야 합니다. 모든 스케줄 항목의 'title'과 'subItems'는 한국어로 작성되어야 합니다.";

      final userQuery = "다음 목표 키워드에 맞는 하루 스케줄을 생성해 주세요: '$goalKeyword'";

      // Note: main.dart의 ApiConfig.GEMINI_API_BASE_URL을 사용합니다.
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
                'timeStart': {
                  'type': 'STRING',
                  'description': '시작 시간 (예: HH:MM)',
                },
                'timeEnd': {
                  'type': 'STRING',
                  'description': '종료 시간 (예: HH:MM)',
                },
                'title': {'type': 'STRING', 'description': '스케줄 제목 (한국어)'},
                'subItems': {
                  'type': 'ARRAY',
                  'items': {'type': 'STRING'},
                  'description': '구체적인 할 일 목록 (한국어, 선택 사항)',
                },
                'isGoalSchedule': {
                  'type': 'BOOLEAN',
                  'description': '이 스케줄이 목표 생성 스케줄임을 표시',
                },
              },
              'required': ['timeStart', 'timeEnd', 'title'],
            },
          },
        },
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.GEMINI_API_BASE_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30)); // 🌟 30초 타임아웃 적용

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        final jsonText =
            result['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (jsonText != null) {
          _generatedScheduleData = jsonDecode(jsonText); // JSON 데이터 저장
        } else {
          _error = 'LLM 응답에서 유효한 스케줄 데이터를 찾을 수 없습니다.';
        }
      } else {
        print(
          "LLM API Failed. Status: ${response.statusCode}, Body: ${response.body}",
        );
        _error = '스케줄 생성 실패: 상태 코드 ${response.statusCode}';
      }
    } on TimeoutException {
      _error = '스케줄 생성 실패: 응답 시간 초과 (30초)';
    } catch (e) {
      _error = '스케줄 생성 중 오류가 발생했습니다: $e';
    }
  }

  // 🌟 생성된 스케줄을 Firestore에 저장하고 ScheduleScreen으로 이동
  Future<void> _saveScheduleAndNavigate() async {
    if (_generatedScheduleData.isEmpty || !mounted) return;

    // 저장 중 로딩 표시
    setState(() => _isLoading = true);

    try {
      final todayKey = _getTodayDateKey();
      final collectionPath = getScheduleCollectionPath();

      // ScheduleItem 객체 대신 바로 JSON 데이터 리스트를 저장
      final List<Map<String, dynamic>> scheduleJsonList = _generatedScheduleData
          .map((item) {
            // LLM에서 받은 데이터에 isChecked, showCheckbox 기본값 추가
            final map = item as Map<String, dynamic>;
            map['isChecked'] = false;
            map['showCheckbox'] = true;
            return map;
          })
          .toList();

      await getDb() // main.dart의 getDb() 사용
          .collection(collectionPath)
          .doc(todayKey)
          .set({
            'items': scheduleJsonList,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        // 저장 후 ScheduleScreen으로 이동 (키워드 없이 이동)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '일정 저장 실패: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 로딩 중이면 스플래시 화면 유지
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 15),
              Text(
                _error == null ? "AI가 목표 기반 일정을 생성하고 저장합니다..." : "일정 저장 중...",
              ),
            ],
          ),
        ),
      );
    }

    // 🌟 오류 발생 시 오류 메시지 표시
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('오류 발생')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 20),
                Text(
                  '❌ 오류 발생: $_error\n\n홈 화면으로 돌아가 다시 시도해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScheduleScreen(),
                      ),
                    );
                  },
                  child: const Text('메인 화면으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 이 화면은 생성 후 바로 이동하므로, 정상적인 상태에서는 보이지 않아야 합니다.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
