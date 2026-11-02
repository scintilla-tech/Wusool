import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../home/account_screen.dart';
import 'admin_buses_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_students_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          AdminDashboardScreen(
            onOpenStudents: () => _select(1),
            onOpenBuses: () => _select(2),
          ),
          const AdminStudentsScreen(),
          const AdminBusesScreen(),
          const AccountScreen(roleLabel: 'إدارة النقل · جامعة الملك خالد'),
        ],
      ),
      bottomNavigationBar: NdsTabBar(
        currentIndex: _index,
        onTap: _select,
        items: const [
          NdsTabItem(HugeIcons.strokeRoundedDashboardSquare01, 'الرئيسية'),
          NdsTabItem(HugeIcons.strokeRoundedMortarboard01, 'الطالبات'),
          NdsTabItem(HugeIcons.strokeRoundedBus01, 'الحافلات'),
          NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'الحساب'),
        ],
      ),
    );
  }
}
