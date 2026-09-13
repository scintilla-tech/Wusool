import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'supervisor_providers.dart';

class SupervisorScreen extends ConsumerWidget {
  const SupervisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorBusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المشرفة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(supervisorBusesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الحافلات\n$e', textAlign: TextAlign.center)),
        data: (buses) {
          if (buses.isEmpty) {
            return const Center(child: Text('لا توجد حافلات مسندة إليك'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(supervisorBusesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: buses.length,
              itemBuilder: (context, i) => _BusCard(bus: buses[i]),
            ),
          );
        },
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final SupervisorBusView bus;
  const _BusCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (bus.tripStatus) {
      'IN_PROGRESS' => WaslColors.emerald,
      'COMPLETED' => WaslColors.textSecondary,
      'SCHEDULED' => WaslColors.navy,
      _ => WaslColors.textSecondary,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: WaslColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bus.name ?? bus.plateNumber,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _tripLabel(bus.tripStatus),
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${bus.plateNumber}${bus.routeName != null ? ' • ${bus.routeName}' : ''}',
              style: const TextStyle(color: WaslColors.textSecondary),
            ),
            if (bus.hasTrip) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _Count(label: 'إجمالي', value: bus.total, color: WaslColors.navy),
                  _Count(label: 'صعدن', value: bus.boarded, color: WaslColors.success),
                  _Count(label: 'متأخرات', value: bus.notReady, color: WaslColors.warning),
                  _Count(label: 'لم يحضرن', value: bus.missed, color: WaslColors.danger),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tripLabel(String? status) {
    return switch (status) {
      'SCHEDULED' => 'مجدولة',
      'IN_PROGRESS' => 'جارية',
      'COMPLETED' => 'مكتملة',
      _ => 'لا رحلة',
    };
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Count({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: WaslColors.textSecondary)),
        ],
      ),
    );
  }
}
