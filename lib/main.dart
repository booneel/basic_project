import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🌟 dotenv 패키지 임포트 (pubspec.yaml에 추가 필요)
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'profile.dart';
import 'set_calendar.dart';
import 'wish.dart'; // GoalSettingScreen 임포트

// --- API 및 환경 설정 ---
class ApiConfig {
  // 🌟 API Key를 .env 파일에서 로드하도록 수정 (초기화 후 접근 가능)
  static String get GEMINI_API_BASE_URL {
    // .env 파일의 변수 이름을 GEMINI_API_KEY로 가정
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_FALLBACK_KEY';
    return 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$apiKey';
  }
}

// 🌟 환경 변수 로딩을 위해 기존 변수들을 제거하고 dotenv에서 직접 읽도록 수정

// 🌟 환경 변수 정의 (dotenv에서 로드할 키)
// dotenv가 로드된 후 이 변수들이 사용됩니다.
final String appId = dotenv.env['APP_ID'] ?? 'default-app-id';
final Map<String, dynamic> firebaseConfig = jsonDecode(
  dotenv.env['FIREBASE_CONFIG_JSON'] ?? '{}',
);
final String? initialAuthToken = dotenv.env['INITIAL_AUTH_TOKEN'];

// Firebase 인스턴스
late FirebaseApp _app;
late FirebaseAuth _auth;
late FirebaseFirestore _db;
String? _userId;

// ---------------- Firebase 유틸리티 함수 ------------------

Future<void> initializeFirebase() async {
  // 🌟 firebaseConfig는 이제 dotenv 로드 후 초기화됩니다.
  if (firebaseConfig.isEmpty) {
    print("Firebase configuration not found. Skipping initialization.");
    return;
  }

  try {
    _app = await Firebase.initializeApp(
      options: FirebaseOptions(
        // 🌟 환경 변수에서 읽은 값 사용
        apiKey: firebaseConfig['apiKey'] ?? '',
        appId: firebaseConfig['appId'] ?? '',
        messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
        projectId: firebaseConfig['projectId'] ?? '',
      ),
    );

    _auth = FirebaseAuth.instanceFor(app: _app);
    _db = FirebaseFirestore.instanceFor(app: _app);

    // 인증 처리
    if (initialAuthToken != null) {
      try {
        await _auth.signInWithCustomToken(initialAuthToken!);
      } catch (e) {
        print("Custom token sign-in failed: $e");
        await _auth.signInAnonymously();
      }
    } else {
      await _auth.signInAnonymously();
    }

    _userId = _auth.currentUser?.uid ?? 'anonymous_user';
    print("Firebase initialized. User ID: $_userId");
  } catch (e) {
    print("Firebase initialization failed: $e");
  }
}

FirebaseFirestore getDb() => _db;

String getUserId() => _userId ?? 'anonymous_user';

String getScheduleCollectionPath() {
  // 비공개 데이터 저장 경로: /artifacts/{appId}/users/{userId}/schedules
  return 'artifacts/$appId/users/${getUserId()}/schedules';
}
// -----------------------------------------------------------

// 1. 일정 데이터 모델 정의
class ScheduleItem {
  final String timeStart;
  final String timeEnd;
  final String title;
  final List<String>? subItems;
  bool isChecked;
  final bool showCheckbox;
  final bool isGoalSchedule; // LLM 생성 스케줄인지 표시

  ScheduleItem({
    required this.timeStart,
    required this.timeEnd,
    required this.title,
    this.subItems,
    this.isChecked = false,
    this.showCheckbox = true,
    this.isGoalSchedule = false,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      timeStart: json['timeStart'] as String,
      timeEnd: json['timeEnd'] as String,
      title: json['title'] as String,
      subItems: json['subItems'] != null
          ? List<String>.from(json['subItems'])
          : null,
      isGoalSchedule: json['isGoalSchedule'] ?? false,
      showCheckbox: json['showCheckbox'] ?? true,
    );
  }
}

// -----------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 🌟 .env 파일 로드 (flutter_dotenv 사용)
  // .env 파일이 프로젝트 루트에 있다고 가정
  await dotenv.load(fileName: ".env");

  // 한국 로케일 초기화
  await initializeDateFormatting('ko_KR', null);
  await initializeFirebase(); // Firebase 초기화
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: Colors.purple[300],
        splashFactory: NoSplash.splashFactory,
      ),
      home: const GoalSettingScreen(), // 시작 화면을 GoalSettingScreen으로 변경
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  final String? goalKeyword; // diet.dart에서 전달받은 목표 키워드

  // 키워드가 전달되면 LLM 스케줄 생성, 그렇지 않으면 기본 스케줄 표시
  const ScheduleScreen({super.key, this.goalKeyword});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const Color currentBgColor = Color(0xFF67B77A);
  static const Color pastBgColor = Color(0xFF616161);
  static const Color futureBgColor = Color(0xFFF7F7F7);

  late List<ScheduleItem> _scheduleList;
  Timer? _timer;
  int _selectedIndex = 1; // Home screen is active by default
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scheduleList = [];
    if (widget.goalKeyword != null) {
      _generateSchedule(widget.goalKeyword!);
    } else {
      _loadDefaultSchedule();
    }

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    // pushReplacement를 사용하여 깔끔하게 화면 전환
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CalendarScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  // 기본 스케줄 로드 (한국어)
  void _loadDefaultSchedule() {
    setState(() {
      _scheduleList = [
        ScheduleItem(timeStart: '09:00', timeEnd: '10:00', title: '기상 및 아침 루틴'),
        ScheduleItem(
          timeStart: '10:00',
          timeEnd: '12:00',
          title: '업무/학습 집중 시간',
        ),
        ScheduleItem(timeStart: '12:00', timeEnd: '13:00', title: '점심 식사'),
        ScheduleItem(timeStart: '13:00', timeEnd: '18:00', title: '핵심 업무 처리'),
        ScheduleItem(timeStart: '18:00', timeEnd: '19:00', title: '운동 시간'),
        ScheduleItem(timeStart: '19:00', timeEnd: '20:00', title: '저녁 식사 및 휴식'),
      ];
    });
  }

  // LLM을 호출하여 목표 기반 스케줄 생성
  Future<void> _generateSchedule(String goalKeyword) async {
    setState(() {
      _isLoading = true;
      _scheduleList = []; // 기존 스케줄 초기화
    });

    try {
      const systemPrompt =
          "당신은 일일 스케줄 생성 전문가입니다. 사용자의 목표 키워드를 바탕으로 구체적이고 실현 가능한 하루(09:00 ~ 21:00) 스케줄을 5~7개의 항목으로 구성하여 JSON 객체 배열로 반환하세요. 'isGoalSchedule' 필드는 true로 설정해야 합니다. 모든 스케줄 항목의 'title'과 'subItems'는 한국어로 작성되어야 합니다.";

      final userQuery = "다음 목표 키워드에 맞는 하루 스케줄을 생성해 주세요: '$goalKeyword'";

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

      // 🌟 수정된 ApiConfig.GEMINI_API_BASE_URL 속성을 사용하여 API Key를 포함
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
          final List<dynamic> scheduleData = jsonDecode(jsonText);
          setState(() {
            _scheduleList = scheduleData
                .map(
                  (item) => ScheduleItem.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          });
        } else {
          _showSnackBar('LLM 응답에서 유효한 스케줄 데이터를 찾을 수 없습니다.');
          _loadDefaultSchedule();
        }
      } else {
        _showSnackBar('스케줄 생성 실패: 상태 코드 ${response.statusCode}');
        _loadDefaultSchedule();
      }
    } catch (e) {
      _showSnackBar('스케줄 생성 중 오류가 발생했습니다: $e');
      _loadDefaultSchedule();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- 시간 계산 및 상태 함수 ---

  DateTime _parseTime(String time, DateTime now) {
    // 시간을 파싱하여 오늘 날짜와 결합된 DateTime 객체를 반환합니다.
    final parts = time.split(':');
    if (parts.length != 2) return now; // 파싱 실패 시 현재 시간 반환
    final hour = int.tryParse(parts[0]) ?? now.hour;
    final minute = int.tryParse(parts[1]) ?? now.minute;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool _isPastTime(String timeEnd, DateTime now) {
    if (timeEnd.isEmpty) return false;
    // 종료 시간이 오늘 날짜의 해당 시간보다 이전인지 확인
    return now.isAfter(_parseTime(timeEnd, now));
  }

  bool _isCurrentSchedule(String timeStart, String timeEnd, DateTime now) {
    final startTime = _parseTime(timeStart, now);
    // 종료 시간이 비어있으면 자정(23:59)으로 간주
    final endTime = _parseTime(timeEnd.isEmpty ? '23:59' : timeEnd, now);

    // 현재 시간이 시작 시간과 종료 시간 사이인지 확인
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // --- UI 빌드 함수 ---

  Widget _buildScheduleItem({required ScheduleItem item, required int index}) {
    final DateTime now = DateTime.now();
    // ScheduleItem에는 end, start 필드가 없으므로 timeEnd, timeStart 사용
    final bool isPast = _isPastTime(item.timeEnd, now);
    final bool isCurrent = _isCurrentSchedule(
      item.timeStart,
      item.timeEnd,
      now,
    );

    Color bgColor;
    Color textColor;

    if (isCurrent) {
      bgColor = currentBgColor;
      textColor = Colors.white;
    } else if (isPast) {
      bgColor = pastBgColor;
      textColor = Colors.white70;
    } else {
      bgColor = futureBgColor;
      textColor = Colors.black87;
    }

    final Color timeStartColor = isPast ? Colors.black38 : Colors.black;
    final Color timeEndColor = isPast ? Colors.black38 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeStart,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 2,
                    color: timeStartColor,
                  ),
                ),
                Text(
                  item.timeEnd,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1,
                    color: timeEndColor,
                    decoration: (isPast && item.isChecked)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withAlpha(38),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: bgColor == futureBgColor
                    ? Border.all(color: Colors.grey.shade200, width: 1)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // LLM 생성 스케줄일 경우 아이콘 추가
                        if (item.isGoalSchedule)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Icon(Icons.star, color: textColor, size: 18),
                          ),
                        Flexible(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                              decoration: (isPast && item.isChecked)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (item.showCheckbox)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: item.isChecked,
                              // 과거 시간일 경우 체크박스 비활성화 (null)
                              onChanged: isPast
                                  ? null
                                  : (bool? newValue) => setState(
                                      () => _scheduleList[index].isChecked =
                                          newValue!,
                                    ),
                              activeColor: isCurrent
                                  ? Colors.white
                                  : Colors.black,
                              checkColor: bgColor,
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.disabled))
                                    return Colors.transparent;
                                  if (states.contains(WidgetState.selected))
                                    return isCurrent
                                        ? Colors.white
                                        : Colors
                                              .black; // 현재 시간이면 흰색 체크, 아니면 검은색
                                  return Colors.white;
                                },
                              ),
                              side: BorderSide(
                                width: 1.5,
                                color: isPast
                                    ? Colors.transparent
                                    : (isCurrent
                                          ? Colors.white
                                          : Colors.black26),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.subItems != null && item.subItems!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: item.subItems!
                              .map(
                                (subItem) => Text(
                                  '• $subItem',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withAlpha(178),
                                    decoration: isPast && item.isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule', // 원본 유지
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home', // 원본 유지
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'profile', // 원본 유지
        ),
      ],
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      selectedItemColor: Colors.purple[300],
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      backgroundColor: Colors.white,
      elevation: 3,
      type: BottomNavigationBarType.fixed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String displayDay = DateFormat('d').format(now);
    final String displayMonthYear = DateFormat('M월 yyyy', 'ko_KR').format(now);
    final String displayWeekday = DateFormat('EEEE', 'ko_KR').format(now);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28.0, 45.0, 20.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDay,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(width: 30),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          displayWeekday,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                        Text(
                          displayMonthYear,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '오늘',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ), // 한국어
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 70,
                    child: Text(
                      '시간',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ), // 한국어
                  Expanded(
                    child: Text(
                      '할 일',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ), // 한국어
                  Icon(Icons.sort, color: Colors.grey[700]),
                ],
              ),
            ),
            const Divider(height: 25, thickness: 1, color: Colors.black12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 15),
                      Text("목표 기반 스케줄을 생성 중입니다..."),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: List.generate(_scheduleList.length, (index) {
                  return _buildScheduleItem(
                    item: _scheduleList[index],
                    index: index,
                  );
                }),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}
