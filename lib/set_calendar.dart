import 'package:flutter/material.dart';

void main() {
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

// 1. 일정 데이터 모델 정의 (Color 속성 추가)
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

  // 스케줄 데이터 맵: Key는 날짜 문자열 (YYYY-MM-DD), Value는 List<일정 항목>
  late Map<String, List<CalendarScheduleItem>> _schedules;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime(2025, 7, 1);
    _selectedDate = DateTime(2025, 7, 17);

    // 초기 더미 데이터 (7월 17일에 두 개의 다른 색상 스케줄 추가)
    _schedules = {
      '2025-07-17': [
        CalendarScheduleItem(
          id: '1',
          title: '아르바이트',
          time: '14:00-17:00',
          color: _scheduleColors[0], // Green
        ),
        CalendarScheduleItem(
          id: '2',
          title: '팀 회의',
          time: '18:00-19:00',
          color: _scheduleColors[1], // Blue
        ),
      ],
    };
  }

  // ===========================================
  // 2. 일정 관리 함수
  // ===========================================

  // 일정 추가 (색상 순환 로직 추가)
  void _addSchedule(String dateKey, String title, String time) {
    // 해당 날짜에 이미 등록된 스케줄 개수를 확인하여 다음 색상을 순환 선택
    final existingCount = _schedules[dateKey]?.length ?? 0;
    final colorIndex = existingCount % _scheduleColors.length;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = CalendarScheduleItem(
      id: newId,
      title: title,
      time: time,
      color: _scheduleColors[colorIndex], // 새로운 색상 할당
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

  // 시간 형식 변환 (TimeOfDay -> HH:MM)
  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '선택';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 일정 추가 다이얼로그 표시 (Time Picker 포함)
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    decoration: const InputDecoration(labelText: '일정 제목'),
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 15),
                  // 시작 시간 Time Picker
                  ListTile(
                    title: const Text('시작 시간'),
                    trailing: Text(_formatTimeOfDay(startTime)),
                    onTap: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        ),
                      );
                      if (pickedTime != null) {
                        setStateInDialog(() => startTime = pickedTime);
                      }
                    },
                  ),
                  // 종료 시간 Time Picker
                  ListTile(
                    title: const Text('종료 시간'),
                    trailing: Text(_formatTimeOfDay(endTime)),
                    onTap: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        ),
                      );
                      if (pickedTime != null) {
                        setStateInDialog(() => endTime = pickedTime);
                      }
                    },
                  ),
                ],
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
  // 3. 달력 제어 함수 (월 변경 시 1일로 설정 유지)
  // ===========================================

  void _goToPreviousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      _selectedDate = _currentDate; // 새 달의 1일로 선택
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      _selectedDate = _currentDate; // 새 달의 1일로 선택
    });
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }


  // ===========================================
  // 4. UI 빌드 위젯 (달력 점 표시 로직 변경)
  // ===========================================

  // 달력 날짜 그리드 (스케줄 개수/색상에 따른 점 표시 로직 변경)
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
          final schedulesForDay = _schedules[dateKey] ?? []; // 해당 날짜의 스케줄 리스트

          return Center(
            child: GestureDetector(
              onTap: () => _selectDay(date),
              child: Container(
                width: 35,
                height: 35,
                decoration: isSelected
                    ? BoxDecoration(
                  color: Theme.of(context).primaryColor?.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor!, width: 1.5),
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
                    // 🚨 스케줄 개수만큼 점 표시
                    if (schedulesForDay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          // 최대 3개까지만 점을 표시하여 화면 혼잡을 방지 (선택 사항)
                          children: schedulesForDay.take(3).map((schedule) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                // 선택된 날짜는 메인 색상, 아니면 스케줄별 색상
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

  // 선택된 날짜의 일정 목록을 표시하는 항목 빌더 (시간 텍스트 색상 변경)
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
                    style: TextStyle( // 🚨 일정 색상으로 시간 텍스트 색상 변경
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

          // 일정 카드 오른쪽 위 삭제 버튼 (휴지통 아이콘)
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
    final schedules = _schedules[dateKey] ?? [];

    if (schedules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Text(
          '등록된 일정이 없습니다.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: schedules.map((item) => _buildScheduleDetailItem(item)).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 나머지 UI 코드는 이전과 동일하게 유지
    return Scaffold(
      backgroundColor: Colors.white,
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
          _buildDateGrid(), // 업데이트된 달력 그리드
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
                  _buildScheduleList(), // 업데이트된 일정 목록
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
      // 하단 네비게이션 바는 생략
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

  // 달력 헤더 (이전과 동일)
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

  // 달력 요일 표시 (이전과 동일)
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

  // 하단 네비게이션 바 아이템 (이전과 동일)
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, bool isSelected) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8) : null,
        decoration: isSelected
            ? BoxDecoration(
          color: Theme.of(context).primaryColor?.withOpacity(0.1),
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