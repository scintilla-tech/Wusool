import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'admin_providers.dart';

class AdminBusesScreen extends ConsumerWidget {
  const AdminBusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminBusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحافلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminBusesProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذر تحميل الحافلات\n$e', textAlign: TextAlign.center),
        ),
        data: (buses) {
          if (buses.isEmpty) return const Center(child: Text('لا توجد حافلات'));
          return ListView.separated(
            itemCount: buses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = buses[i];
              return ListTile(
                leading: const Icon(
                  Icons.directions_bus,
                  color: WaslColors.navy,
                ),
                title: Text(b.name ?? b.plateNumber),
                subtitle: Text(
                  '${b.plateNumber}${b.capacity != null ? ' • ${b.capacity} مقعد' : ''}',
                ),
                trailing: b.isActive
                    ? const Icon(
                        Icons.check_circle,
                        color: WaslColors.success,
                        size: 20,
                      )
                    : const Icon(
                        Icons.cancel,
                        color: WaslColors.danger,
                        size: 20,
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
