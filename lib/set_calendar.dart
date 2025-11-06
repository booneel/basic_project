import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'main.dart'; // ScheduleScreen, getDb, getUserId 임포트 (main.dart에 있다고 가정)
import 'profile.dart'; // ProfileScreen 임포트
import 'package:cloud_firestore/cloud_firestore.dart';

// ----------------------------------------------------------------------
// 1. 일정 데이터 모델 정의 (핵심 수정 부분)
// ----------------------------------------------------------------------
class CalendarScheduleItem {
  final String id;
  String title;
  String time; // "HH:MM-HH:MM" 형식 (예: 10:00-11:30)
  final int colorValue; // 색상 정수 값으로 저장
  final String dateKey; // 👈 [핵심 수정] YYYY-MM-DD 형식의 날짜 키 (쿼리 필터링용)

  CalendarScheduleItem({
    required this.id,
    required this.title,
    required this.time,
    required this.colorValue,
    required this.dateKey, // 👈 [핵심 수정] 생성자에 추가
  });

  factory CalendarScheduleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarScheduleItem(
      id: doc.id,
      title: data['title'] ?? '',
      time: data['time'] ?? '00:00-00:00',
      colorValue: data['colorValue'] ?? Colors.blue.value,
      dateKey: data['dateKey'] ?? '0000-00-00', // 👈 [핵심 수정] 필드 추가
    );
  }

  Map<String, dynamic> toFirestore() {
    // dateKey가 YYYY-MM-DD 형식이라고 가정하고 yearMonthKey 생성
    String yearMonthKey;
    try {
      yearMonthKey = dateKey.substring(0, 7); // YYYY-MM-DD -> YYYY-MM
    } catch (e) {
      yearMonthKey = '0000-00';
    }

    return {
      'title': title,
      'time': time,
      'colorValue': colorValue,
      'dateKey': dateKey, // 👈 [핵심 수정] Firestore에 날짜 키 저장
      'yearMonthKey': yearMonthKey, // 월별 필터링을 위한 키
    };
  }
}


// ----------------------------------------------------------------------
// 2. 캘린더 화면 위젯
// ----------------------------------------------------------------------
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // 캘린더는 한 달 단위로 데이터를 관리하고, 선택된 날짜의 일정을 보여줍니다.
  // 이 맵은 현재 달력에 보이는 모든 월의 일정을 담습니다. (키: YYYY-MM-DD)
  Map<String, List<CalendarScheduleItem>> _schedules = {};

  bool _isLoading = true;
  int _selectedIndex = 0; // 캘린더 화면이 0번 인덱스

  StreamSubscription<QuerySnapshot>? _scheduleSubscription; // 실시간 리스너

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR', null).then((_) {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);

      // 🚨 [Firebase 안정화] FutureBuilder가 완료될 때까지 지연 호출
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _startScheduleListener();
        }
      });
    });
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel(); // 위젯 종료 시 리스너 해제
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // Firestore 연동 및 데이터 관리
  // ----------------------------------------------------------------------

  /// Firestore에서 현재 달의 일정을 실시간으로 가져오는 리스너 설정
  void _startScheduleListener() {
    _scheduleSubscription?.cancel(); // 기존 리스너 해제

    // Firestore 인스턴스 및 경로를 main.dart에서 가져옴
    final db = getDb();
    final collectionPath = getScheduleCollectionPath();

    // 현재 달을 YYYY-MM 형식으로 필터링 키 생성
    final yearMonthKey = DateFormat('yyyy-MM').format(_focusedDay);

    try {
      _scheduleSubscription = db
          .collection(collectionPath)
          .where('yearMonthKey', isEqualTo: yearMonthKey) // 👈 월별 필터링
          .snapshots()
          .listen((snapshot) {
        final newSchedules = <String, List<CalendarScheduleItem>>{};

        for (var doc in snapshot.docs) {
          final item = CalendarScheduleItem.fromFirestore(doc);
          final String dateKey = item.dateKey; // YYYY-MM-DD

          if (!newSchedules.containsKey(dateKey)) {
            newSchedules[dateKey] = [];
          }
          newSchedules[dateKey]!.add(item);
        }

        // 일정 시간순 정렬
        newSchedules.forEach((key, list) {
          list.sort(
                (a, b) => a.time.split('-')[0].compareTo(b.time.split('-')[0]),
          );
        });

        setState(() {
          _schedules = newSchedules;
          _isLoading = false;
        });
      }, onError: (error) {
        print("Error listening to schedules: $error");
        setState(() {
          _isLoading = false;
          _schedules = {};
        });
      });
    } catch (e) {
      print("Firestore Listener setup error: $e");
      setState(() {
        _isLoading = false;
        _schedules = {};
      });
    }
  }

  /// 날짜 키 생성 (YYYY-MM-DD)
  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// 일정 추가
  Future<void> _addSchedule(String title, String startTime, String endTime, int color) async {
    final db = getDb();
    final collectionPath = getScheduleCollectionPath();
    final dateKey = _getDateKey(_selectedDay);
    final timeString = '$startTime-$endTime';

    // Firestore Doc ID로 사용될 고유 ID 생성
    final newId = '${DateTime.now().millisecondsSinceEpoch}_$dateKey';

    final newSchedule = CalendarScheduleItem(
      id: newId,
      title: title,
      time: timeString,
      colorValue: color,
      dateKey: dateKey, // 👈 [핵심 수정] dateKey 전달
    );

    try {
      await db
          .collection(collectionPath)
          .doc(newId)
          .set(newSchedule.toFirestore());
    } catch (e) {
      print("Error adding schedule: $e");
      // 에러 메시지를 사용자에게 보여주는 UI 로직 추가 가능
    }
  }

  /// 일정 삭제
  Future<void> _deleteSchedule(String scheduleId) async {
    final db = getDb();
    final collectionPath = getScheduleCollectionPath();

    try {
      await db
          .collection(collectionPath)
          .doc(scheduleId)
          .delete();
    } catch (e) {
      print("Error deleting schedule: $e");
    }
  }

  // ----------------------------------------------------------------------
  // UI 로직
  // ----------------------------------------------------------------------

  /// 날짜 선택 시 호출되는 함수
  void _onDaySelected(DateTime selectedDay) {
    if (selectedDay.month != _focusedDay.month) {
      // 월이 바뀌면 캘린더를 포커싱하고 리스너를 재설정해야 함
      _focusedDay = selectedDay;
      _startScheduleListener(); // 월이 바뀌었으니 DB 리스너 재시작
    }
    setState(() {
      _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      _isLoading = false;
    });
  }

  /// 일정 추가 다이얼로그
  void _showAddScheduleDialog() {
    final titleController = TextEditingController();
    DateTime startTime = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day, 9, 0);
    DateTime endTime = startTime.add(const Duration(hours: 1));
    int selectedColor = Colors.purple.value;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return CupertinoActionSheet(
              title: Text(
                  '${DateFormat('yyyy년 M월 d일', 'ko_KR').format(_selectedDay)} 일정 추가'),
              message: Column(
                children: [
                  CupertinoTextField(
                    controller: titleController,
                    placeholder: '일정 제목',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimePickerButton('시작 시간', startTime, (newTime) {
                        setModalState(() => startTime = newTime);
                      }),
                      _buildTimePickerButton('종료 시간', endTime, (newTime) {
                        setModalState(() => endTime = newTime);
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildColorPicker(selectedColor, (color) {
                    setModalState(() => selectedColor = color);
                  }),
                ],
              ),
              actions: <CupertinoActionSheetAction>[
                CupertinoActionSheetAction(
                  isDefaultAction: true,
                  onPressed: () {
                    if (titleController.text.isEmpty) {
                      // 제목이 비어있으면 알림
                      return;
                    }
                    _addSchedule(
                      titleController.text,
                      DateFormat('HH:mm').format(startTime),
                      DateFormat('HH:mm').format(endTime),
                      selectedColor,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('저장'),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 시간 선택 버튼
  Widget _buildTimePickerButton(String label, DateTime time,
      Function(DateTime) onTimeChanged) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoModalPopup<void>(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 200,
              color: Colors.white,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: time,
                onDateTimeChanged: (DateTime newDateTime) {
                  onTimeChanged(newDateTime);
                },
              ),
            );
          },
        );
      },
      child: Text('$label: ${DateFormat('HH:mm').format(time)}',
          style: TextStyle(color: Colors.purple)),
    );
  }

  /// 색상 선택 위젯
  Widget _buildColorPicker(int selectedColor, Function(int) onColorSelected) {
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => onColorSelected(color.value),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: CircleAvatar(
              radius: selectedColor == color.value ? 14 : 10,
              backgroundColor: color,
              child: selectedColor == color.value
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 달력 헤더
  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            DateFormat('yyyy년 M월', 'ko_KR').format(_focusedDay),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
                    _selectedDay = _focusedDay;
                    _startScheduleListener(); // 월 변경 시 리스너 재시작
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
                    _selectedDay = _focusedDay;
                    _startScheduleListener(); // 월 변경 시 리스너 재시작
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 요일 표시 (일월화수목금토)
  Widget _buildWeekdays() {
    const weekdays = [
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

  /// 달력 격자 (간단 버전)
  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7; // 0=일, 6=토
    final daysInMonth = lastDayOfMonth.day;

    final days = <DateTime>[];
    // 이전 달의 날짜 채우기
    for (int i = startWeekday; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }
    // 이번 달의 날짜
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_focusedDay.year, _focusedDay.month, i));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final isToday = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;
        final isSelected = day.year == _selectedDay.year &&
            day.month == _selectedDay.month &&
            day.day == _selectedDay.day;
        final isCurrentMonth = day.month == _focusedDay.month;

        return GestureDetector(
          onTap: () => _onDaySelected(day),
          child: Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple[100] : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: Colors.purple, width: 2)
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isCurrentMonth
                          ? (day.weekday == DateTime.sunday ||
                          day.weekday == DateTime.saturday
                          ? Colors.grey[700]
                          : Colors.black)
                          : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  // 여기에 이벤트 표시 로직을 추가할 수 있지만, 일단 건너뜁니다.
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 선택된 날짜의 일정 목록
  Widget _buildEventList() {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ));
    }

    // 현재 선택된 날짜의 일정만 필터링하여 가져옵니다.
    final selectedDateKey = _getDateKey(_selectedDay);
    final schedulesForSelectedDay = _schedules.containsKey(selectedDateKey)
        ? _schedules[selectedDateKey]!
        : [];

    if (schedulesForSelectedDay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            '선택하신 날짜에 일정이 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }
    return Column(
      children: schedulesForSelectedDay.map((item) {
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteSchedule(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${item.title} 일정이 삭제되었습니다.')),
            );
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(item.colorValue),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.time,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 하단 네비게이션 바
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
    );
  }

  /// 네비게이션 아이템 탭 핸들러
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleScreen()), // 👈 const 유지 가능
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()), // 👈 const 유지 가능
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('개인 일정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildCalendarHeader(),
            const SizedBox(height: 10),
            _buildWeekdays(),
            const Divider(height: 10, thickness: 1, color: Colors.black12),
            _buildCalendar(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${DateFormat('M월 d일', 'ko_KR').format(_selectedDay)}의 일정',
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            _buildEventList(),
            const SizedBox(height: 80), // 하단 버튼 공간 확보
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
        backgroundColor: Colors.purple[300],
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}