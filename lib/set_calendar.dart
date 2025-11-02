import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
        primaryColor: Colors.purple[300], // 메인 색상 (보라색)
        splashFactory: NoSplash.splashFactory,
      ),
      home: const CalendarScreen(),
    );
  }
}

// 1. 일정 데이터 모델 정의
class CalendarScheduleItem {
  final String id;
  String title;
  String time;
  Color color; // 일정 색상

  CalendarScheduleItem({required this.id, required this.title, required this.time, required this.color});
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentDate; // 현재 달력에 표시되는 월/년도
  late DateTime _selectedDate; // 사용자가 선택한 날짜

  // 1-1. 스케줄에 사용할 색상 리스트 정의
  final List<Color> _scheduleColors = const [
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.teal,
    Colors.deepPurple,
  ];

  // 스케줄 데이터 맵
  late Map<String, List<CalendarScheduleItem>> _schedules;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, 1); // 현재 달의 1일
    _selectedDate = DateTime(now.year, now.month, now.day); // 오늘 날짜

    final String todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _schedules = {
      todayKey: [
      ],
    };
  }

  // ===========================================
  // 2. 일정 관리 함수
  // ===========================================

  // 일정 추가
  void _addSchedule(String dateKey, String title, String time) {
    final existingCount = _schedules[dateKey]?.length ?? 0;
    final colorIndex = existingCount % _scheduleColors.length;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = CalendarScheduleItem(
      id: newId,
      title: title,
      time: time,
      color: _scheduleColors[colorIndex],
    );

    setState(() {
      if (_schedules.containsKey(dateKey)) {
        _schedules[dateKey]!.add(newItem);
      } else {
        _schedules[dateKey] = [newItem];
      }
    });
  }

  // 일정 삭제
  void _deleteSchedule(String dateKey, String itemId) {
    setState(() {
      _schedules[dateKey]?.removeWhere((item) => item.id == itemId);
      if (_schedules[dateKey]?.isEmpty ?? false) {
        _schedules.remove(dateKey);
      }
    });
  }

  // 시간 형식 변환
  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '선택';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // CupertinoTimerPicker 헬퍼 함수
  Future<TimeOfDay?> _showCupertinoPicker(BuildContext context, TimeOfDay initialTime) {
    TimeOfDay selectedTime = initialTime;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(hours: initialTime.hour, minutes: initialTime.minute),
                    minuteInterval: 1,
                    onTimerDurationChanged: (duration) {
                      selectedTime = TimeOfDay(hour: duration.inHours, minute: duration.inMinutes % 60);
                    },
                  ),
                ),
              ),
              TextButton(
                child: Text('선택 완료', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop(selectedTime);
                },
              )
            ],
          ),
        );
      },
    );
  }


  // 일정 추가 다이얼로그 (SingleChildScrollView 추가됨)
  void _showAddScheduleDialog() {
    String title = '';
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('새 일정 추가'),

              // 키보드 오버플로우 방지를 위해 SingleChildScrollView 추가
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      decoration: const InputDecoration(labelText: '일정 제목'),
                      onChanged: (value) => title = value,
                    ),
                    const SizedBox(height: 15),
                    // 시작 시간 선택
                    ListTile(
                      title: const Text('시작 시간'),
                      trailing: Text(_formatTimeOfDay(startTime)),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await _showCupertinoPicker(
                          context,
                          startTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setStateInDialog(() => startTime = pickedTime);
                        }
                      },
                    ),
                    // 종료 시간 선택
                    ListTile(
                      title: const Text('종료 시간'),
                      trailing: Text(_formatTimeOfDay(endTime)),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await _showCupertinoPicker(
                          context,
                          endTime ?? startTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setStateInDialog(() => endTime = pickedTime);
                        }
                      },
                    ),
                  ],
                ),
              ),

              actions: <Widget>[
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('추가'),
                  onPressed: () {
                    if (title.isNotEmpty && startTime != null && endTime != null) {
                      final timeString = '${_formatTimeOfDay(startTime)}-${_formatTimeOfDay(endTime)}';
                      final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

                      _addSchedule(dateKey, title, timeString);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('제목과 시간을 모두 입력해주세요.')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================
  // 3. 달력 제어 함수
  // ===========================================

  void _goToPreviousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      _selectedDate = _currentDate;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      _selectedDate = _currentDate;
    });
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }


  // ===========================================
  // 4. UI 빌드 위젯
  // ===========================================

  // 달력 날짜 그리드
  Widget _buildDateGrid() {
    final DateTime firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final int daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    final int weekdayOfFirstDay = firstDayOfMonth.weekday % 7;

    final List<DateTime?> days = [];
    for (int i = 0; i < weekdayOfFirstDay; i++) {
      days.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentDate.year, _currentDate.month, i));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 0,
          childAspectRatio: 1.0,
        ),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];

          if (date == null) {
            return const Center();
          }

          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final schedulesForDay = _schedules[dateKey] ?? [];

          return Center(
            child: GestureDetector(
              onTap: () => _selectDay(date),
              child: Container(
                width: 35,
                height: 35,
                decoration: isSelected
                    ? BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.black,
                      ),
                    ),
                    if (schedulesForDay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: schedulesForDay.take(3).map((schedule) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).primaryColor : schedule.color,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 선택된 날짜의 일정 목록을 표시하는 항목 빌더
  Widget _buildScheduleDetailItem(CalendarScheduleItem item) {
    final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.time,
                    style: TextStyle(
                      color: item.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 40),
            ],
          ),
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 24),
              onPressed: () => _deleteSchedule(dateKey, item.id),
            ),
          ),
        ],
      ),
    );
  }

  // 선택된 날짜의 일정 목록 표시
  Widget _buildScheduleList() {
    final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    // 스케줄 리스트를 가져와서 복사본을 만듭니다. (원본 맵을 직접 정렬하지 않기 위해)
    final schedules = List<CalendarScheduleItem>.from(_schedules[dateKey] ?? []);

    if (schedules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Text(
          '등록된 일정이 없습니다.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 🚨 일정 시작 시간 기준으로 정렬
    schedules.sort((a, b) {
      // '14:00-17:00' 문자열에서 시작 시간 '14:00'만 추출
      final timeA = a.time.split('-')[0];
      final timeB = b.time.split('-')[0];

      // 시간을 문자열로 비교하여 정렬합니다. (예: "09:00" < "14:00")
      return timeA.compareTo(timeB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: schedules.map((item) => _buildScheduleDetailItem(item)).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 🚨 오버플로우/키보드 문제 해결을 위한 속성 추가
      resizeToAvoidBottomInset: false,
      body: Column(
        children: <Widget>[
          const SizedBox(height: 60),
          const Padding(
            padding: EdgeInsets.only(bottom: 30.0),
            child: Text(
              '당신의 일정을 알려주세요',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCalendarHeader(),
          const SizedBox(height: 20),
          _buildWeekdays(),
          const SizedBox(height: 10),
          _buildDateGrid(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(top: 20, bottom: 20),
                  ),
                  _buildScheduleList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: GestureDetector(
                      onTap: _showAddScheduleDialog,
                      child: Icon(
                        Icons.add_circle,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          _buildNavItem(Icons.calendar_today, 'Schedule', true),
          _buildNavItem(Icons.home, 'Home', false),
          _buildNavItem(Icons.person, 'profile', false),
        ],
        currentIndex: 0,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // 달력 헤더
  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _goToPreviousMonth,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black54),
            ),
          ),
          Column(
            children: [
              Text(
                '${_currentDate.month}월',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_currentDate.year}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          GestureDetector(
            onTap: _goToNextMonth,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // 달력 요일 표시
  Widget _buildWeekdays() {
    const List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: (day == 'Sun' || day == 'Sat') ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 하단 네비게이션 바 아이템
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, bool isSelected) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8) : null,
        decoration: isSelected
            ? BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        )
            : null,
        child: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[500],
        ),
      ),
      label: label,
    );
  }
}