import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'admin_providers.dart';

class AdminStudentsScreen extends ConsumerWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطالبات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminStudentsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الطالبات\n$e', textAlign: TextAlign.center)),
        data: (students) {
          if (students.isEmpty) return const Center(child: Text('لا توجد طالبات'));
          return ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = students[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: s.isActive ? WaslColors.navy : WaslColors.textSecondary,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text('${s.firstName} ${s.lastName}'),
                subtitle: Text('${s.studentId ?? ''} • ${s.phone}'),
                trailing: s.isActive
                    ? null
                    : const Text('معطّل', style: TextStyle(color: WaslColors.danger, fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
