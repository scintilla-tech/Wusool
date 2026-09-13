import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import 'admin_buses_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_students_screen.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminShellBody(
      onLogout: () => ref.read(authProvider.notifier).logout(),
    );
  }
}

class _AdminShellBody extends StatefulWidget {
  final VoidCallback onLogout;
  const _AdminShellBody({required this.onLogout});

  @override
  State<_AdminShellBody> createState() => _AdminShellBodyState();
}

class _AdminShellBodyState extends State<_AdminShellBody> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const AdminDashboardScreen(),
      const AdminStudentsScreen(),
      const AdminBusesScreen(),
      _LogoutScreen(onLogout: widget.onLogout),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.school), label: 'الطالبات'),
          NavigationDestination(icon: Icon(Icons.directions_bus), label: 'الحافلات'),
          NavigationDestination(icon: Icon(Icons.logout), label: 'خروج'),
        ],
      ),
    );
  }
}

class _LogoutScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutScreen({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحساب')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ),
    );
  }
}
