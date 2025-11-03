
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                  '이백수',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'team@gmail.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Text(
                  '현재 목표',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Text(
                  '다이어트',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '목표 변경',
                    style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '진행기간',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Text(
                  '21일',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Image.asset(
            'asset/img/Mark.png', // You need to add your image to assets
            height: 130,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        '로그아웃 하기',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Adjust aspect ratio for better centering
        children: [
          _buildStatCard(
            imagePath: 'asset/img/google.png', // Path to your 구글 이미지
            title: '구글 로그인',
            value: '',
            isProgress: false,
          ),
          _buildStatCard(
            color: Colors.green[300],
            title: '목표 달성률',
            value: '27%',
            isProgress: true,
          ),
          _buildStatCard(
            title: '퍼펙트 데이',
            value: '7',
            isProgress: false,
          ),
          _buildStatCard(
            title: '평균 달성률',
            value: '70%',
            isProgress: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    IconData? icon,
    Color? iconColor,
    String? imagePath,
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
              style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white),
            )
          else if (imagePath != null)
            Image.asset(imagePath, height: 68) // Adjusted image height
          else if (icon != null)
            Icon(icon, size: 40, color: iconColor)
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
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'profile',
        ),
      ],
      currentIndex: 2, // Profile screen is active
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
