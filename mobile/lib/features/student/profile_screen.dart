import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'student_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الملف\n$e', textAlign: TextAlign.center)),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: WaslColors.navy,
                      child: Icon(Icons.person, color: Colors.white, size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.firstName} ${profile.lastName}',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                          if (profile.studentId != null)
                            Text(
                              'الرقم الجامعي: ${profile.studentId}',
                              style: const TextStyle(color: WaslColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _InfoTile(icon: Icons.phone, label: 'رقم الجوال', value: profile.phone),
            if (profile.email != null)
              _InfoTile(icon: Icons.email, label: 'البريد الجامعي', value: profile.email!),
            _InfoTile(
              icon: Icons.home,
              label: 'الموقع المنزلي',
              value: (profile.homeLatitude != null && profile.homeLongitude != null)
                  ? '${profile.homeLatitude!.toStringAsFixed(4)}, ${profile.homeLongitude!.toStringAsFixed(4)}'
                  : 'غير محدد',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              style: OutlinedButton.styleFrom(foregroundColor: WaslColors.danger),
              icon: const Icon(Icons.delete_outline),
              label: const Text('طلب حذف الحساب'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('سيتم إرسال طلب حذف الحساب للإدارة. هل أنت متأكدة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تأكيد الطلب', style: TextStyle(color: WaslColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: WaslColors.navy),
        title: Text(label, style: const TextStyle(fontSize: 13, color: WaslColors.textSecondary)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, color: WaslColors.textPrimary)),
      ),
    );
  }
}
