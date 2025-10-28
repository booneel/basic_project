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
  final Color color;
  final List<String>? subItems;
  bool isChecked;
  final bool showCheckbox;

  ScheduleItem({
    required this.timeStart,
    required this.timeEnd,
    required this.title,
    required this.color,
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
  // 이미지 색상에 근접하게 설정
  static const Color scheduleColor1 = Color(0xFFEFEFF7); // 연한 회보라색 (기본색)
  static const Color scheduleColor2 = Color(0xFF67B77A); // 녹색 (점심식사/진행중인 스케줄 색상)
  static const Color scheduleColor3 = Colors.white; // 흰색 (아르바이트)
  static const Color scheduleColor4 = Color(0xFFF7F7F7); // 아주 연한 회색 (저녁식사)
  static const Color pastColor = Color(0xFFE0E0E0); // 종료된 스케줄 회색 톤

  // 2. 초기 일정 데이터 리스트 (상태로 관리)
  late List<ScheduleItem> _scheduleList;

  @override
  void initState() {
    super.initState();
    _scheduleList = [
      ScheduleItem(
        timeStart: '9:00',
        timeEnd: '11:00',
        title: '스트레칭 및 아침 조깅',
        color: scheduleColor1,
        isChecked: true,
        subItems: const ['youtube.com/1234', 'youtube.com/34996'],
      ),
      ScheduleItem(
        timeStart: '12:00',
        timeEnd: '13:00',
        title: '점심식사 (추천메뉴)',
        color: scheduleColor2,
        isChecked: false,
        subItems: const ['샐러드', '피자', '햄버거'],
      ),
      ScheduleItem(
        timeStart: '14:00',
        timeEnd: '17:00',
        title: '아르바이트',
        color: scheduleColor3,
        isChecked: false,
        subItems: null,
      ),
      ScheduleItem(
        timeStart: '18:00',
        timeEnd: '19:00',
        title: '저녁식사 (추천메뉴)',
        color: scheduleColor4,
        isChecked: true,
        subItems: const ['현미밥 + 닭가슴살', '족발', '보쌈'],
      ),
    ];
  }

  // 3. 시간 문자열을 오늘 날짜의 DateTime 객체로 변환
  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // 4. 일정이 현재 시간을 기준으로 종료되었는지 확인
  bool _isPastTime(String timeEnd) {
    final endTime = _parseTime(timeEnd);
    final currentTime = DateTime.now();
    return currentTime.isAfter(endTime);
  }

  // 5. 일정이 현재 시간에 진행 중인지 확인 (새로운 로직)
  bool _isCurrentSchedule(String timeStart, String timeEnd) {
    final startTime = _parseTime(timeStart);
    final endTime = _parseTime(timeEnd);
    final currentTime = DateTime.now();
    // 현재 시간이 시작 시간과 종료 시간 사이에 있으면 true
    return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
  }

  // 6. 일정 항목 빌드 위젯 (현재 시간 강조 기능 적용)
  Widget _buildScheduleItem({
    required ScheduleItem item,
    required int index,
  }) {
    final bool isPast = _isPastTime(item.timeEnd);
    final bool isCurrent = _isCurrentSchedule(item.timeStart, item.timeEnd);

    // 현재 진행 중이면 scheduleColor2 (녹색)을 사용, 종료되었으면 pastColor (회색)을 사용
    Color cardColor;
    if (isCurrent) {
      cardColor = scheduleColor2;
    } else if (isPast && item.color != scheduleColor3) {
      cardColor = pastColor; // 흰색 카드는 과거라도 배경색 변경 제외
    } else {
      cardColor = item.color; // 원래 색상 유지
    }

    // 텍스트 색상 결정
    final Color titleColor = isCurrent || item.color == scheduleColor2
        ? Colors.white // 녹색 배경이면 흰색
        : (isPast ? Colors.black45 : Colors.black87); // 과거는 진한 회색, 아니면 검정

    final Color subItemColor = isCurrent || item.color == scheduleColor2
        ? Colors.white70 // 녹색 배경이면 연한 흰색
        : (isPast ? Colors.black38 : Colors.black54); // 과거는 연한 회색, 아니면 진한 회색

    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
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
                  item.timeStart,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPast ? Colors.black38 : Colors.black,
                  ),
                ),
                Text(
                  item.timeEnd,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPast ? Colors.black38 : Colors.black54,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // 일정 카드 영역
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
                // 흰색/옅은색 카드는 테두리를 살짝 추가
                border: item.color == Colors.white || item.color == scheduleColor4
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
                              color: titleColor,
                              decoration: isPast && item.isChecked ? TextDecoration.lineThrough : null,
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
                                  ? null // 과거는 변경 불가
                                  : (bool? newValue) {
                                setState(() {
                                  _scheduleList[index].isChecked = newValue!;
                                });
                              },
                              // 체크박스 색상 설정 (녹색 배경에서는 흰색)
                              activeColor: isCurrent || item.color == scheduleColor2 ? Colors.white : Colors.black,
                              checkColor: cardColor,
                              fillColor: MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return isCurrent || item.color == scheduleColor2 ? Colors.white : Colors.black;
                                  }
                                  return Colors.white;
                                },
                              ),
                              side: BorderSide(
                                width: 1.5,
                                color: item.isChecked
                                    ? (isCurrent || item.color == scheduleColor2 ? Colors.white : Colors.black)
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
                                color: subItemColor,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 상단 날짜 및 요일 (이전과 동일)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '17',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '7월 2025',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '목요일',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 시간 및 할 일 헤더 (이전과 동일)
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

            const Divider(height: 20, thickness: 1, color: Colors.black12),

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
      // 하단 네비게이션 바 (이전과 동일)
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          _buildNavItem(Icons.calendar_today, 'Schedule', false),
          _buildNavItem(Icons.home, 'Home', true),
          _buildNavItem(Icons.person, 'profile', false),
        ],
        currentIndex: 1,
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
}