// [profile.dart]

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart'; // getDb, getUserId 임포트 (필요 시)
import 'login.dart'; // LoginPage 임포트

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 2; // Profile screen active by default

  String _userName = '이백수 (임시 사용자)';
  String _userEmail = 'test_user@goalapp.com';
  String _currentGoal = '목표 로딩 중...';
  String _goalDuration = '1일';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // 화면이 다시 포커스될 때마다 자동으로 새로고침 (목표 재설정 후 반영용)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchUserData();
  }

  /// 사용자 정보 및 목표 로드
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.isAnonymous) {
        setState(() {
          _userName = '익명 사용자';
          _userEmail = '로그인 필요';
          _currentGoal = '목표 미설정';
          _goalDuration = '1일';
          _isLoading = false;
        });
        return;
      }

      final docSnapshot =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        setState(() {
          _userName = data['name'] ?? '이름 없음';
          _userEmail = data['email'] ?? user.email ?? '이메일 없음';
          _currentGoal = data['currentGoalText'] ?? '목표 미설정';
          _goalDuration = '1일';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userEmail = user.email ?? '이메일 정보 없음';
          _currentGoal = '목표 미설정';
          _goalDuration = '1일';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 로그아웃 처리
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // ✅ 로그인 페이지로 이동 (StreamBuilder 감지 X 시 수동 이동)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      print("Logout Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/calendar');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/schedule');
        break;
      case 2:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
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

  /// 프로필 카드
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
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _userEmail,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Text(
                  '현재 목표',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  _currentGoal,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '진행기간',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  _goalDuration,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.person_pin, size: 130, color: Colors.purple[300]),
        ],
      ),
    );
  }

  /// 로그아웃 버튼
  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _logout,
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

  /// 통계 그리드
  Widget _buildStatsGrid() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
        children: [
          _buildGoalResetCard(),
          _buildStatCard(
            color: Colors.green[300],
            title: '목표 달성률',
            value: '0%',
            isProgress: true,
          ),
          _buildStatCard(title: '퍼펙트 데이', value: '0', isProgress: false),
          _buildStatCard(title: '평균 달성률', value: '0%', isProgress: false),
        ],
      ),
    );
  }

  /// 목표 재설정 카드
  Widget _buildGoalResetCard() {
    return GestureDetector(
      onTap: () async {
        // ✅ pushNamed로 이동 후 돌아올 때 데이터 재로드
        await Navigator.pushNamed(context, '/goal');
        _fetchUserData();
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
          children: const [
            Icon(Icons.edit_note, size: 60, color: Colors.black),
            SizedBox(height: 8),
            Text(
              '목표 재설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 통계 카드 위젯
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

  /// 하단 네비게이션 바
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
