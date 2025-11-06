import 'package:flutter/material.dart';
import 'main.dart'; // ScheduleScreen 임포트
import 'set_calendar.dart'; // CalendarScreen 임포트
import 'wish.dart'; // GoalSettingScreen 임포트

// main.dart에서 실행되므로 main 함수는 제거하고 ProfileScreen만 남김

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 2; // Profile screen is active by default

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
        // Already on the Profile screen
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildLogoutButton(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이백수 (임시 사용자)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'test_user@goalapp.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Text(
                  '현재 목표',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Text(
                  '맞춤형 목표 진행 중',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      // pushReplacement 사용
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GoalSettingScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '목표 재설정',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '진행기간',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Text(
                  'N/A',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Image.asset 대신 Icon으로 대체
          Icon(Icons.person_pin, size: 130, color: Colors.purple[300]),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () {
        // 실제 로그아웃 로직 (Firebase Auth) 필요
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '로그아웃 하기',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
        children: [
          _buildStatCard(
            icon: Icons.vpn_key,
            title: '인증 상태',
            value: 'OK',
            isProgress: false,
          ),
          _buildStatCard(
            color: Colors.green[300],
            title: '목표 달성률',
            value: '27%',
            isProgress: true,
          ),
          _buildStatCard(title: '퍼펙트 데이', value: '7', isProgress: false),
          _buildStatCard(title: '평균 달성률', value: '70%', isProgress: false),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    IconData? icon,
    Color? color,
    required String title,
    required String value,
    required bool isProgress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isProgress)
            Text(
              value,
              style: const TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 60,
              color: color == null ? Colors.black : Colors.white,
            )
          else
            Text(
              value,
              style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isProgress ? Colors.white : Colors.black54,
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
