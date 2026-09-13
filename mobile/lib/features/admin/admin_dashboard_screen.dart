import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلومات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الإحصائيات\n$e', textAlign: TextAlign.center)),
        data: (d) => GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(label: 'الحافلات', value: d.buses, icon: Icons.directions_bus),
            _StatCard(label: 'المسارات', value: d.routes, icon: Icons.route),
            _StatCard(label: 'الطالبات', value: d.students, icon: Icons.school),
            _StatCard(label: 'السائقون', value: d.drivers, icon: Icons.person_pin),
            _StatCard(label: 'المشرفات', value: d.supervisors, icon: Icons.supervisor_account),
            _StatCard(label: 'رحلات اليوم', value: d.tripsToday, icon: Icons.today),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: WaslColors.emerald, size: 26),
            Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: WaslColors.navy)),
            Text(label, style: const TextStyle(color: WaslColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
