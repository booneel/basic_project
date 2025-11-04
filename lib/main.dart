import 'package:flutter/material.dart';
import 'profile.dart';
import 'set_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

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
  static const Color currentBgColor = Color(0xFF67B77A);
  static const Color pastBgColor = Color(0xFF616161);
  static const Color futureBgColor = Color(0xFFF7F7F7);

  late List<ScheduleItem> _scheduleList;
  Timer? _timer;
  int _selectedIndex = 1; // Home screen is active by default

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CalendarScreen()),
        );
        break;
      case 1:
      // 현재 화면이므로 아무 작업도 하지 않음
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleList = [
      ScheduleItem(
        timeStart: '9:00',
        timeEnd: '11:00',
        start: '09:00',
        end: '11:00',
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
        timeEnd: '',
        start: '22:00',
        end: '23:59',
        title: '취침',
        isChecked: false,
        subItems: null,
      ),
    ];

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

  DateTime _parseTime(String time, DateTime now) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
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

  Widget _buildScheduleItem({
    required ScheduleItem item,
    required int index,
  }) {
    final DateTime now = DateTime.now();
    final bool isPast = _isPastTime(item.end, now);
    final bool isCurrent = _isCurrentSchedule(item.start, item.end, now);

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
                Text(item.timeStart, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 2, color: timeStartColor)),
                Text(item.timeEnd, style: TextStyle(fontSize: 14, height: 1, color: timeEndColor, decoration: (isPast && item.isChecked) ? TextDecoration.lineThrough : null)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: bgColor.withAlpha(38), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
                border: bgColor == futureBgColor ? Border.all(color: Colors.grey.shade200, width: 1) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor, decoration: (isPast && item.isChecked) ? TextDecoration.lineThrough : null))),
                        if (item.showCheckbox)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: item.isChecked,
                              onChanged: isPast ? null : (bool? newValue) => setState(() => _scheduleList[index].isChecked = newValue!),
                              activeColor: isCurrent ? Colors.white : Colors.black,
                              checkColor: bgColor,
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                    (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.disabled)) return Colors.transparent;
                                  if (states.contains(WidgetState.selected)) return Colors.black;
                                  return Colors.white;
                                },
                              ),
                              side: BorderSide(width: 1.5, color: isPast ? Colors.transparent : Colors.black26),
                            ),
                          ),
                      ],
                    ),
                    if (item.subItems != null && item.subItems!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: item.subItems!.map((subItem) => Text('• $subItem', style: TextStyle(fontSize: 14, color: textColor.withAlpha(178), decoration: isPast && item.isChecked ? TextDecoration.lineThrough : null))).toList(),
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
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile'),
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
                    Text(displayDay, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Colors.black, height: 1.05)),
                    const SizedBox(width: 30),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(displayWeekday, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.6)),
                        Text(displayMonthYear, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)),
                  child: Text('Today', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 70, child: Text('시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                  const Expanded(child: Text('할 일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                  Icon(Icons.sort, color: Colors.grey[700]),
                ],
              ),
            ),
            const Divider(height: 25, thickness: 1, color: Colors.black12),
            Column(
              children: List.generate(_scheduleList.length, (index) {
                return _buildScheduleItem(item: _scheduleList[index], index: index);
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