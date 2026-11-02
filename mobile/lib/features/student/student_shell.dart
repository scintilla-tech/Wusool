import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import 'profile_screen.dart';
import 'student_home_screen.dart';
import 'tracking_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          StudentHomeScreen(onTrack: () => _select(1)),
          const TrackingScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NdsTabBar(
        currentIndex: _index,
        onTap: _select,
        items: const [
          NdsTabItem(HugeIcons.strokeRoundedHome01, 'الرئيسية'),
          NdsTabItem(HugeIcons.strokeRoundedMaps, 'التتبع'),
          NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'حسابي'),
        ],
      ),
    );
  }
}
