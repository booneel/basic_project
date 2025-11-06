import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async'; // Timer 및 TimeoutException 사용
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🌟 dotenv 패키지 임포트 (pubspec.yaml에 추가 필요)
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'profile.dart';
import 'set_calendar.dart';
import 'wish.dart'; // GoalSettingScreen 임포트

// --- Firebase 인스턴스 ---
late FirebaseApp _app;
late FirebaseAuth _auth;
FirebaseFirestore? _db; // 👈 [핵심 수정] Nullable로 변경하여 LateInitializationError 방지
String? _userId;

// --- API 및 환경 설정 ---
class ApiConfig {
  static String get GEMINI_API_BASE_URL {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_FALLBACK_KEY';
    return 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$apiKey';
  }
}

// 🌟 환경 변수 정의
final String appId = dotenv.env['APP_ID'] ?? 'default-app-id';
final Map<String, dynamic> firebaseConfig = jsonDecode(
  dotenv.env['FIREBASE_CONFIG_JSON'] ?? '{}',
);
final String? initialAuthToken = dotenv.env['INITIAL_AUTH_TOKEN'];

// ---------------- Firebase 유틸리티 함수 ------------------

Future<void> initializeFirebase() async {
  if (firebaseConfig.isEmpty || firebaseConfig['projectId'] == null) {
    print(
      "🚨 Firebase configuration not found or invalid. Skipping initialization.",
    );
    return;
  }

  try {
    // 🌟 Duplicate App 오류 방지 로직
    try {
      if (Firebase.apps.isEmpty || Firebase.app().name != '[DEFAULT]') {
        _app = await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseConfig['apiKey'] as String? ?? '',
            appId: firebaseConfig['appId'] as String? ?? '',
            messagingSenderId:
                firebaseConfig['messagingSenderId'] as String? ?? '',
            projectId: firebaseConfig['projectId'] as String? ?? '',
          ),
        );
      } else {
        _app = Firebase.app();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app' || Firebase.apps.isNotEmpty) {
        _app = Firebase.app();
        print(
          "✅ Duplicate app initialization handled. Reusing existing Firebase app.",
        );
      } else {
        rethrow;
      }
    }

    _auth = FirebaseAuth.instanceFor(app: _app);
    _db = FirebaseFirestore.instanceFor(app: _app); // 👈 Nullable 필드에 할당

    // 인증 처리
    if (initialAuthToken != null && initialAuthToken!.isNotEmpty) {
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
    print("✅ Firebase initialized. User ID: $_userId");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
    // 🌟 구성 오류 시 StateError를 던져 앱 재시작 유도
    throw StateError(
      "Critical Firebase initialization failed. Please check your .env configuration JSON carefully.",
    );
  }
}

// 🌟 [핵심 수정] _db가 Nullable이 되었으므로, 초기화 검사를 포함한 getDb()
FirebaseFirestore getDb() {
  if (_db == null) {
    // 초기화가 안된 상태에서 getDb() 호출 시 명시적인 오류 발생
    throw StateError(
      "FirebaseFirestore instance is not initialized. Check initializeFirebase() in main.",
    );
  }
  return _db!; // non-null assertion
}

String getUserId() => _userId ?? 'anonymous_user';

String getScheduleCollectionPath() {
  return 'artifacts/$appId/users/${getUserId()}/schedules';
}

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
      subItems: json['subItems'] is List
          ? List<String>.from(json['subItems'])
          : null,
      isGoalSchedule: json['isGoalSchedule'] ?? false,
      showCheckbox: json['showCheckbox'] ?? true,
    );
  }
}

// ---------------- main 함수 (초기화 로직) ----------------
void main() async {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goal Planner App',
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: Colors.purple[300],
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GoalSettingScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// ---------------- ScheduleScreen 위젯 (메인 스케줄 보기 및 저장) ----------------

class ScheduleScreen extends StatefulWidget {
  final String? goalKeyword; // 이제 이 값은 무시됩니다.

  const ScheduleScreen({super.key, this.goalKeyword});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const Color currentBgColor = Color(0xFF67B77A);
  static const Color pastBgColor = Color(0xFF616161);
  static const Color futureBgColor = Color(0xFFF7F7F7);

  List<ScheduleItem> _scheduleList = [];
  Timer? _timer;
  int _selectedIndex = 1;
  bool _isLoading = false;

  String _getTodayDateKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  void _loadDefaultSchedule() {
    if (!mounted) return;
    setState(() {
      _scheduleList = [
        ScheduleItem(
          timeStart: '09:00',
          timeEnd: '10:00',
          title: '기상 및 아침 루틴',
          isGoalSchedule: false,
        ),
        ScheduleItem(
          timeStart: '10:00',
          timeEnd: '12:00',
          title: '업무/학습 집중 시간',
          isGoalSchedule: false,
        ),
        ScheduleItem(
          timeStart: '12:00',
          timeEnd: '13:00',
          title: '점심 식사',
          isGoalSchedule: false,
        ),
        ScheduleItem(
          timeStart: '13:00',
          timeEnd: '18:00',
          title: '핵심 업무 처리',
          isGoalSchedule: false,
        ),
        ScheduleItem(
          timeStart: '18:00',
          timeEnd: '19:00',
          title: '운동 시간',
          isGoalSchedule: false,
        ),
        ScheduleItem(
          timeStart: '19:00',
          timeEnd: '20:00',
          title: '저녁 식사 및 휴식',
          isGoalSchedule: false,
        ),
      ];
    });
  }

  Future<void> _saveScheduleToFirestore(List<ScheduleItem> scheduleList) async {
    if (scheduleList.isEmpty) return;

    try {
      final todayKey = _getTodayDateKey();
      final collectionPath = getScheduleCollectionPath();

      final List<Map<String, dynamic>> scheduleJsonList = scheduleList.map((
        item,
      ) {
        return {
          'timeStart': item.timeStart,
          'timeEnd': item.timeEnd,
          'title': item.title,
          'subItems': item.subItems,
          'isChecked': item.isChecked,
          'showCheckbox': item.showCheckbox,
          'isGoalSchedule': item.isGoalSchedule,
        };
      }).toList();

      await getDb().collection(collectionPath).doc(todayKey).set({
        'items': scheduleJsonList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ DB 저장 실패: $e");
      // DB 저장 실패 시에는 스케줄이 메모리에 있으므로 심각한 오류가 아니면 무시할 수 있습니다.
    }
  }

  Future<void> _saveCurrentScheduleToFirestore() async {
    await _saveScheduleToFirestore(_scheduleList);
  }

  // 🌟 [핵심] LLM 생성 로직을 제거하고 순수하게 DB 로드만 수행
  Future<void> _loadSchedulesFromFirestore() async {
    if (!_isLoading)
      setState(() {
        _isLoading = true;
      });

    try {
      final todayKey = _getTodayDateKey();
      final docSnapshot = await getDb()
          .collection(getScheduleCollectionPath())
          .doc(todayKey)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final List<dynamic>? scheduleData = data['items'] as List<dynamic>?;

        if (scheduleData != null) {
          if (!mounted) return;
          setState(() {
            _scheduleList = scheduleData
                .map(
                  (item) => ScheduleItem.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          });
          print("✅ Firestore에서 오늘의 일정 ${_scheduleList.length}개를 로드했습니다.");
        } else {
          _loadDefaultSchedule();
        }
      } else {
        _loadDefaultSchedule();
      }
    } catch (e) {
      // DB 연결 오류 (StateError 포함) 시 사용자에게 메시지 표시
      _showSnackBar('일정 로드 중 오류가 발생했습니다: $e', isError: true);
      _loadDefaultSchedule();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🌟 [제거] _generateSchedule 함수는 diet.dart로 이동했으므로, main.dart에서는 삭제합니다.

  @override
  void initState() {
    super.initState();
    _scheduleList = [];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🌟 [핵심 수정] 키워드 인자 무시, 무조건 DB 로드 시도
      await _loadSchedulesFromFirestore();
    });

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

    String routeName = '/';

    switch (index) {
      case 0:
        routeName = '/calendar';
        break;
      case 1:
        routeName = '/';
        break;
      case 2:
        routeName = '/profile';
        break;
    }

    if (_selectedIndex != index) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  DateTime _parseTime(String time, DateTime now) {
    final parts = time.split(':');
    if (parts.length != 2) return now;
    final hour = int.tryParse(parts[0]) ?? now.hour;
    final minute = int.tryParse(parts[1]) ?? now.minute;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool _isPastTime(String timeEnd, DateTime now) {
    if (timeEnd.isEmpty) return false;
    return now.isAfter(_parseTime(timeEnd, now));
  }

  bool _isCurrentSchedule(String timeStart, String timeEnd, DateTime now) {
    final startTime = _parseTime(timeStart, now);
    final endTime = _parseTime(timeEnd.isEmpty ? '23:59' : timeEnd, now);
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  Widget _buildScheduleItem({required ScheduleItem item, required int index}) {
    final DateTime now = DateTime.now();
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
                              onChanged: isPast
                                  ? null
                                  : (bool? newValue) {
                                      setState(
                                        () => _scheduleList[index].isChecked =
                                            newValue!,
                                      );
                                      _saveCurrentScheduleToFirestore();
                                    },
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
                                        : Colors.black;
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
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '캘린더'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
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
                  ),
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
                  ),
                  const Expanded(
                    child: Text(
                      '할 일',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
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
                      Text("일정을 불러오는 중입니다..."),
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
