import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../home/account_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_people_screen.dart';
import 'admin_transport_screen.dart';
import '../home/notifications.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  TransportView _transport = TransportView.buses;

  void _select(int index) => setState(() => _index = index);

  void _openTransport(TransportView view) => setState(() {
    _transport = view;
    _index = 3;
  });

  @override
  Widget build(BuildContext context) {
    // Admins hear when a driver builds a route that needs students.
    return NotificationWatcher(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            AdminDashboardScreen(
              onOpenStudents: () => _select(1),
              onOpenStaff: () => _select(2),
              onOpenBuses: () => _openTransport(TransportView.buses),
              onOpenRoutes: () => _openTransport(TransportView.routes),
            ),
            const AdminPeopleScreen.students(),
            const AdminPeopleScreen.staff(),
            AdminTransportScreen(
              view: _transport,
              onViewChanged: (view) => setState(() => _transport = view),
            ),
            const AccountScreen(roleLabel: 'إدارة النقل · جامعة الملك خالد'),
          ],
        ),
        bottomNavigationBar: NdsTabBar(
          currentIndex: _index,
          onTap: _select,
          items: const [
            NdsTabItem(HugeIcons.strokeRoundedDashboardSquare01, 'الرئيسية'),
            NdsTabItem(HugeIcons.strokeRoundedMortarboard01, 'الطالبات'),
            NdsTabItem(HugeIcons.strokeRoundedUserGroup, 'الموظفون'),
            NdsTabItem(HugeIcons.strokeRoundedBus01, 'النقل'),
            NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'الحساب'),
          ],
        ),
      ),
    );
  }
}
