import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'main.dart'; // ScheduleScreen, getDb, getUserId 임포트
import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. 일정 데이터 모델 정의
class CalendarScheduleItem {
  final String id;
  String title;
  String time; // "HH:MM-HH:MM" 형식
  final int colorValue; // 색상 정수 값으로 저장

  CalendarScheduleItem({
    required this.id,
    required this.title,
    required this.time,
    required this.colorValue,
  });

  factory CalendarScheduleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarScheduleItem(
      id: doc.id,
      title: data['title'] ?? '',
      time: data['time'] ?? '00:00-00:00',
      colorValue: data['colorValue'] ?? Colors.blue.value,
    );
  }

  Map<String, dynamic> toFirestore() {
    // 🌟 [수정 1] Firestore 쿼리를 위해 'yearMonthKey' 필드 추가
    final timeParts = time.split('-');
    if (timeParts.isEmpty) {
      // 시간 형식이 잘못된 경우 대비
      return {'title': title, 'time': time, 'colorValue': colorValue};
    }

    // time 필드가 HH:MM-HH:MM 형식이므로, 날짜 정보를 알 수 없음.
    // 임시로 오늘 날짜를 기준으로 DateFormat을 적용하기 어려움.
    // 이전에 _addSchedule에서 id를 통해 날짜를 포함시켰으므로,
    // 여기서는 dateKey와 yearMonthKey를 필수 필드로 간주하고 작성합니다.

    // 실제 Firestore에 저장되는 문서가 dateKey 필드를 포함한다고 가정
    final dateKey = timeParts[0]; // 실제로는 YYYY-MM-DD가 포함되어야 함

    // 날짜 키에서 연월 추출 (YYYY-MM 형식의 문자열이 필요)
    String yearMonthKey;
    try {
      yearMonthKey = dateKey.substring(0, 7); // 예: "2025-11-06" -> "2025-11"
    } catch (e) {
      yearMonthKey = '0000-00'; // 예외 처리
    }

    return {
      'title': title,
      'time': time,
      'colorValue': colorValue,
      'dateKey': dateKey,
      'yearMonthKey': yearMonthKey, // 👈 쿼리 필터링을 위한 필드
    };
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentDate; // 현재 달력에 표시되는 월/년도
  late DateTime _selectedDate; // 사용자가 선택한 날짜
  final DateTime _today = DateTime.now().toLocal(); // 오늘 날짜
  int _selectedIndex = 0;

  // 1-1. 스케줄에 사용할 색상 리스트 정의
  final List<Color> _scheduleColors = const [
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.teal,
    Colors.deepPurple,
  ];

  // 스케줄 데이터 맵 (날짜 키: List<일정>)
  Map<String, List<CalendarScheduleItem>> _schedules = {};
  StreamSubscription? _scheduleSubscription;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, 1); // 현재 달의 1일
    _selectedDate = DateTime(now.year, now.month, now.day); // 오늘 날짜

    // initState에서 리스너 시작
    _startScheduleListener();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    super.dispose();
  }

  // ===========================================
  // 2. Firebase 연동 및 리스너
  // ===========================================

  void _startScheduleListener() {
    // 🚨 [수정 2] 리스너 중복 방지를 위해 기존 리스너 취소
    _scheduleSubscription?.cancel();

    final db = getDb();
    final collectionPath = getScheduleCollectionPath();

    // 🌟 현재 달의 키를 기반으로 쿼리 필터링 (YYYY-MM 형식)
    final yearMonth = DateFormat('yyyy-MM').format(_currentDate);

    // 🚨 [수정 2] where 쿼리를 사용하여 해당 월의 데이터만 로드하도록 변경
    _scheduleSubscription = db
        .collection(collectionPath)
        .where('yearMonthKey', isEqualTo: yearMonth)
        .snapshots()
        .listen(
          (snapshot) {
            final newSchedules = <String, List<CalendarScheduleItem>>{};

            for (var doc in snapshot.docs) {
              final item = CalendarScheduleItem.fromFirestore(doc);
              final data = doc.data() as Map<String, dynamic>;

              // Firestore 문서에 저장된 'dateKey' 필드를 사용하여 그룹핑
              final String dateKey = data['dateKey'] ?? '0000-00-00';

              if (!newSchedules.containsKey(dateKey)) {
                newSchedules[dateKey] = [];
              }
              newSchedules[dateKey]!.add(item);
            }

            // 일정 시간 기준으로 정렬
            newSchedules.forEach((key, list) {
              list.sort(
                (a, b) => a.time.split('-')[0].compareTo(b.time.split('-')[0]),
              );
            });

            setState(() {
              _schedules = newSchedules;
            });
          },
          onError: (error) {
            print("Error loading schedules: $error");
          },
        );
  }

  // ===========================================
  // 3. 일정 관리 (CRUD) 함수
  // ===========================================

  // 날짜 키 생성 (YYYY-MM-DD)
  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 일정 추가 (Create)
  Future<void> _addSchedule(String dateKey, String title, String time) async {
    final db = getDb();
    final collectionPath = getScheduleCollectionPath();
    final existingCount = _schedules[dateKey]?.length ?? 0;
    final colorIndex = existingCount % _scheduleColors.length;

    final newItem = CalendarScheduleItem(
      // Firestore Doc ID로 사용될 고유 ID 생성 (날짜 정보 포함)
      id: '${DateTime.now().millisecondsSinceEpoch}_$dateKey',
      title: title,
      time: time,
      colorValue: _scheduleColors[colorIndex].value,
    );

    // 🌟 toFirestore 호출 시 dateKey와 yearMonthKey가 계산되어 포함됨
    final firestoreData = newItem.toFirestore();

    try {
      await db.collection(collectionPath).doc(newItem.id).set({
        ...firestoreData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('일정이 추가되었습니다.', Colors.green);
    } catch (e) {
      _showSnackBar('일정 추가에 실패했습니다: $e', Colors.red);
    }
  }

  // 일정 삭제 (Delete)
  Future<void> _deleteSchedule(String itemId) async {
    if (!_canModifySchedule(_selectedDate)) {
      _showAlertDialog('알림', '오늘을 포함하여 이전 날짜의 일정은 수정 또는 삭제할 수 없습니다.');
      return;
    }

    final db = getDb();
    final collectionPath = getScheduleCollectionPath();

    try {
      await db.collection(collectionPath).doc(itemId).delete();
      _showSnackBar('일정이 삭제되었습니다.', Colors.orange);
    } catch (e) {
      _showSnackBar('일정 삭제에 실패했습니다: $e', Colors.red);
    }
  }

  // ===========================================
  // 4. 날짜 및 UI 유틸리티
  // ===========================================

  // 시간 형식 변환
  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '선택';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt); // 24시간 형식 유지
  }

  // 일정 수정/삭제 가능 여부 확인 (오늘 날짜 포함 이전 날짜는 불가능)
  bool _canModifySchedule(DateTime date) {
    // 날짜 정규화: 시, 분, 초를 제거하고 날짜만 비교
    final normalizedSelectedDate = DateTime(date.year, date.month, date.day);
    final normalizedToday = DateTime(_today.year, _today.month, _today.day);

    // 선택된 날짜가 오늘보다 이전이거나 오늘과 같은 경우
    return !(normalizedSelectedDate.isBefore(normalizedToday) ||
        normalizedSelectedDate.isAtSameMomentAs(normalizedToday));
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
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

  // 일정 추가 다이얼로그
  void _showAddScheduleDialog() {
    if (!_canModifySchedule(_selectedDate)) {
      _showAlertDialog('알림', '오늘을 포함하여 이전 날짜에는 일정을 추가하거나 수정할 수 없습니다.');
      return;
    }

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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      decoration: const InputDecoration(labelText: '일정 제목'),
                      onChanged: (value) => title = value,
                    ),
                    const SizedBox(height: 15),
                    ListTile(
                      title: const Text('시작 시간'),
                      trailing: Text(_formatTimeOfDay(startTime)),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (pickedTime != null) {
                          setStateInDialog(() => startTime = pickedTime);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('종료 시간'),
                      trailing: Text(_formatTimeOfDay(endTime)),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
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
                    if (title.isNotEmpty &&
                        startTime != null &&
                        endTime != null) {
                      final timeString =
                          '${_formatTimeOfDay(startTime)}-${_formatTimeOfDay(endTime)}';
                      final dateKey = _getDateKey(_selectedDate);

                      _addSchedule(dateKey, title, timeString);
                      Navigator.of(context).pop();
                    } else {
                      _showSnackBar('제목과 시간을 모두 입력해주세요.', Colors.redAccent);
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
  // 5. 달력 제어 및 UI
  // ===========================================

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Already on the Calendar screen
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

  void _goToPreviousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      _selectedDate = DateTime(_currentDate.year, _currentDate.month, 1);
    });
    // 🚨 [수정 3] 월 변경 시 리스너 재시작
    _startScheduleListener();
  }

  void _goToNextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      _selectedDate = DateTime(_currentDate.year, _currentDate.month, 1);
    });
    // 🚨 [수정 3] 월 변경 시 리스너 재시작
    _startScheduleListener();
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  // 달력 날짜 그리드
  Widget _buildDateGrid() {
    final DateTime firstDayOfMonth = DateTime(
      _currentDate.year,
      _currentDate.month,
      1,
    );
    final int daysInMonth = DateTime(
      _currentDate.year,
      _currentDate.month + 1,
      0,
    ).day;
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

    final normalizedToday = DateTime(_today.year, _today.month, _today.day);

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

          final isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final normalizedDate = DateTime(date.year, date.month, date.day);
          final isPastOrToday =
              normalizedDate.isBefore(normalizedToday) ||
              normalizedDate.isAtSameMomentAs(normalizedToday);

          final dateKey = _getDateKey(date);
          final schedulesForDay = _schedules[dateKey] ?? [];

          return Center(
            child: GestureDetector(
              onTap: () => _selectDay(date),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.15)
                      : null,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 1.5,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : (isPastOrToday && !isSelected
                                  ? Colors.grey
                                  : Colors.black),
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
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Color(schedule.colorValue),
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
    final canModify = _canModifySchedule(_selectedDate);

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
                      color: Color(item.colorValue),
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
            child: canModify
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.grey,
                      size: 24,
                    ),
                    onPressed: () => _deleteSchedule(item.id),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // 선택된 날짜의 일정 목록 표시
  Widget _buildScheduleList() {
    final dateKey = _getDateKey(_selectedDate);

    final schedules = List<CalendarScheduleItem>.from(
      _schedules[dateKey] ?? [],
    );

    if (schedules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    // 일정 시작 시간 기준으로 정렬
    schedules.sort((a, b) {
      final timeA = a.time.split('-')[0];
      final timeB = b.time.split('-')[0];
      return timeA.compareTo(timeB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: schedules
          .map((item) => _buildScheduleDetailItem(item))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canModify = _canModifySchedule(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: <Widget>[
          const SizedBox(height: 60),
          const Padding(
            padding: EdgeInsets.only(bottom: 30.0),
            child: Text(
              '당신의 일정을 알려주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'yyyy년 MM월 dd일',
                          'ko_KR',
                        ).format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!canModify)
                        const Icon(Icons.lock, color: Colors.grey, size: 24),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1),
                  _buildScheduleList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: GestureDetector(
                      onTap: canModify
                          ? _showAddScheduleDialog
                          : () {
                              _showAlertDialog(
                                '알림',
                                '오늘을 포함하여 이전 날짜에는 일정을 추가하거나 수정할 수 없습니다.',
                              );
                            },
                      child: Icon(
                        Icons.add_circle,
                        size: 40,
                        color: canModify
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
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
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.black54,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                DateFormat('M월', 'ko_KR').format(_currentDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 달력 요일 표시 (영문 유지)
  Widget _buildWeekdays() {
    const List<String> weekdays = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ];
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
                  color: (day == 'Sun' || day == 'Sat')
                      ? Colors.grey
                      : Colors.black,
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

  // BottomNavigationBar (영문 라벨 유지)
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
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
}
