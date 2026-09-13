import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('وصــل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, size: 72, color: WaslColors.emerald),
            const SizedBox(height: 16),
            Text(
              'مرحباً، ${user?.firstName ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _roleLabel(user?.role),
              style: const TextStyle(fontSize: 15, color: WaslColors.textSecondary),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'قيد التطوير — ستظهر شاشات الدور هنا قريباً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: WaslColors.textSecondary),
              ),
            ),
          ],
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
