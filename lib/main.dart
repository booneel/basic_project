import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async'; // 🚨 Timer를 사용하기 위해 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 한국 로케일 초기화
  await initializeDateFormatting('ko_KR', null);
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
      home: const ScheduleScreen(),
    );
  }
}

// 1. 일정 데이터 모델 정의
class ScheduleItem {
  final String timeStart;
  final String timeEnd;
  final String title;
  final List<String>? subItems;
  bool isChecked;
  final bool showCheckbox;

  // 'end' 시간은 로직에 필수적이므로, '22:00 ~' 같은 경우를 위해 'end' 파라미터를 추가
  final String start;
  final String end;

  ScheduleItem({
    required this.timeStart,
    required this.timeEnd,
    required this.title,
    required this.start,
    required this.end,
    this.subItems,
    this.isChecked = false,
    this.showCheckbox = true,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const Color currentBgColor = Color(0xFF67B77A); // 현재 스케줄: 옅은 초록색
  static const Color pastBgColor = Color(0xFF616161);    // 지난 스케줄: 짙은 회색
  static const Color futureBgColor = Color(0xFFF7F7F7);  // 이후 스케줄: 옅은 회색

  // 2. 초기 일정 데이터 리스트 (상태로 관리)
  late List<ScheduleItem> _scheduleList;

  // 🚨 1. Timer 변수 선언
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 🚨 스케줄 리스트 (최신 버전)
    _scheduleList = [
      ScheduleItem(
        timeStart: '9:00',
        timeEnd: '11:00',
        start: '09:00', // 로직용 시작 시간
        end: '11:00',   // 로직용 종료 시간
        title: '스트레칭 및 아침 조깅',
        isChecked: false,
        subItems: const ['youtube.com/1234', 'youtube.com/34596'],
      ),
      ScheduleItem(
        timeStart: '12:00',
        timeEnd: '13:00',
        start: '12:00',
        end: '13:00',
        title: '점심식사 (추천메뉴)',
        isChecked: false,
        subItems: const ['샐러드', '피자', '햄버거'],
      ),
      ScheduleItem(
        timeStart: '14:00',
        timeEnd: '17:00',
        start: '14:00',
        end: '17:00',
        title: '아르바이트',
        isChecked: false,
        subItems: null,
      ),
      ScheduleItem(
        timeStart: '18:00',
        timeEnd: '19:00',
        start: '18:00',
        end: '19:00',
        title: '저녁식사 (추천메뉴)',
        isChecked: false,
        subItems: const ['현미밥 + 닭가슴살', '족발', '보쌈'],
      ),
      ScheduleItem(
        timeStart: '20:00',
        timeEnd: '21:00',
        start: '20:00',
        end: '21:00',
        title: '근력 운동',
        isChecked: false,
        subItems: const ['youtube.com/23985', 'youtube.com/21241'],
      ),
      ScheduleItem(
        timeStart: '22:00',
        timeEnd: '', // '22:00 ~' 표기를 위해 끝 시간 비움
        start: '22:00',
        end: '23:59', // 로직은 하루 끝(23:59)까지로 계산
        title: '취침',
        isChecked: false,
        subItems: null,
      ),
    ];

    // 🚨 2. 타이머 시작: 10초마다 setState()를 호출하여 화면을 새로고침
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) { // 위젯이 아직 화면에 있는지 확인
        setState(() {
          // 이 빈 setState가 build 메서드를 다시 실행시켜
          // DateTime.now()를 새로 가져오게 만듭니다.
        });
      }
    });
  }

  // 🚨 3. dispose 메서드 추가 (메모리 누수 방지)
  @override
  void dispose() {
    _timer?.cancel(); // 화면이 종료되면 타이머도 취소
    super.dispose();
  }


  // 3. 시간 문자열을 오늘 날짜의 DateTime 객체로 변환 (수정됨)
  // 🚨 'now'를 인자로 받아서 계산
  DateTime _parseTime(String time, DateTime now) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    // 'now'를 기준으로 날짜를 생성
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // 4. 일정이 현재 시간을 기준으로 종료되었는지 확인 (수정됨)
  // 🚨 'now'를 인자로 받아서 계산
  bool _isPastTime(String timeEnd, DateTime now) {
    if (timeEnd.isEmpty) return false; // '취침' 스케줄 처리
    final endTime = _parseTime(timeEnd, now);
    return now.isAfter(endTime);
  }

  // 5. 일정이 현재 시간에 진행 중인지 확인 (수정됨)
  // 🚨 'now'를 인자로 받아서 계산
  bool _isCurrentSchedule(String timeStart, String timeEnd, DateTime now) {
    final startTime = _parseTime(timeStart, now);
    final endTime = _parseTime(timeEnd.isEmpty ? '23:59' : timeEnd, now);
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // 6. 일정 항목 빌드 위젯 (시간대별 색상/체크박스 로직 적용)
  Widget _buildScheduleItem({
    required ScheduleItem item,
    required int index,
  }) {
    // 🚨 _buildScheduleItem이 호출될 때마다 '현재 시간'을 새로 가져옴
    final DateTime now = DateTime.now();

    // 🚨 'now'를 기준으로 isPast와 isCurrent를 계산
    final bool isPast = _isPastTime(item.end, now);
    final bool isCurrent = _isCurrentSchedule(item.start, item.end, now);

    Color bgColor;
    Color textColor;

    if (isCurrent) {
      bgColor = currentBgColor;  // 현재 스케줄: 초록색
      textColor = Colors.white;
    } else if (isPast) {
      bgColor = pastBgColor;     // 지난 스케줄: 짙은 회색
      textColor = Colors.white70;
    } else {
      bgColor = futureBgColor;   // 이후 스케줄: 옅은 회색
      textColor = Colors.black87;
    }

    // print('스케줄: ${item.title} / 현재: $isCurrent / 과거: $isPast / bgColor: $bgColor');

    // 시간 섹션 색상
    final Color timeStartColor = isPast ? Colors.black38 : Colors.black;
    final Color timeEndColor = isPast ? Colors.black38 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 시간 표시 영역
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeStart, // 화면 표시용 'timeStart'
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 2,
                    color: timeStartColor,
                  ),
                ),
                Text(
                  item.timeEnd,   // 화면 표시용 'timeEnd'
                  style: TextStyle(
                    fontSize: 14,
                    height: 1,
                    color: timeEndColor,
                    decoration: (isPast && item.isChecked) ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),

          // 일정 카드 영역
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
                // 옅은 회색 카드는 테두리를 추가
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
                        Flexible(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                              decoration: (isPast && item.isChecked) ? TextDecoration.lineThrough : null,
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
                                  ? null // 🚨 지난 스케줄은 비활성화
                                  : (bool? newValue) {
                                setState(() {
                                  _scheduleList[index].isChecked = newValue!;
                                });
                              },
                              // 체크박스 스타일링
                              activeColor: isCurrent ? Colors.white : Colors.black,
                              checkColor: bgColor,
                              fillColor: MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.disabled)) {
                                    return Colors.transparent; // 비활성화 상태에서는 배경 투명
                                  }
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.black;
                                  }
                                  return Colors.white;
                                },
                              ),
                              side: BorderSide(
                                width: 1.5,
                                color: isPast
                                    ? Colors.transparent // 비활성화 테두리 투명
                                    : Colors.black26,
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
                                color: textColor.withOpacity(0.7),
                                decoration: isPast && item.isChecked ? TextDecoration.lineThrough : null,
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


  @override
  Widget build(BuildContext context) {
    // 🚨 'build'가 호출될 때마다 현재 날짜/시간 정보를 새로 가져옴
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
            // 상단 날짜 및 요일
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 (일)만 크게
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
                        // 요일만 표기
                        Text(
                          displayWeekday,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                        // 월/년도 표기를 요일 아래로 이동
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

                // Today 버튼
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 시간 및 할 일 헤더
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

            // 스케줄 항목 리스트
            Column(
              children: List.generate(_scheduleList.length, (index) {
                return _buildScheduleItem(item: _scheduleList[index], index: index);
              }),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}