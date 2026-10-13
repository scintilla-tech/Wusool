import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'platform_providers.dart';

class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنصة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(platformTenantsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذر تحميل الجامعات\n$e', textAlign: TextAlign.center),
        ),
        data: (tenants) {
          if (tenants.isEmpty) {
            return const Center(child: Text('لا توجد جامعات'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: tenants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = tenants[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.isActive
                        ? WaslColors.navy
                        : WaslColors.textSecondary,
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    'الرمز: ${t.code} • المستخدمون: ${t.users} • الحافلات: ${t.buses}',
                  ),
                  trailing: t.isActive
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
