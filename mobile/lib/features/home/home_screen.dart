import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../admin/admin_shell.dart';
import '../auth/auth_state.dart';
import '../driver/driver_screen.dart';
import '../platform/platform_screen.dart';
import '../student/student_shell.dart';
import '../supervisor/supervisor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user?.role == 'STUDENT') {
      return const StudentShell();
    }
    if (user?.role == 'DRIVER') {
      return const DriverScreen();
    }
    if (user?.role == 'SUPERVISOR' || user?.role == 'FIELD_SUPERVISOR') {
      return const SupervisorScreen();
    }
    if (user?.role == 'UNIVERSITY_ADMIN') {
      return const AdminShell();
    }
    if (user?.role == 'PLATFORM_SUPER_ADMIN') {
      return const PlatformScreen();
    }

    return Scaffold(
      appBar: BrandBar(
        title: 'نظام النقل الجامعي للطالبات',
        subtitle: _roleLabel(user?.role),
        actions: [
          CircleIconButton(
            icon: HugeIcons.strokeRoundedLogout01,
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: MessageView(
            icon: HugeIcons.strokeRoundedBus01,
            tone: Tone.primary,
            title: 'مرحباً، ${user?.firstName ?? ''}',
            message: 'لا تتوفر شاشات لهذا الدور بعد.',
          ),
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'STUDENT':
        return 'طالبة';
      case 'DRIVER':
        return 'سائق';
      case 'SUPERVISOR':
        return 'مشرفة';
      case 'FIELD_SUPERVISOR':
        return 'مشرفة ميدانية';
      case 'UNIVERSITY_ADMIN':
        return 'إدارة الجامعة';
      case 'PLATFORM_SUPER_ADMIN':
        return 'إدارة المنصة';
      default:
        return '';
    }
  }
}
