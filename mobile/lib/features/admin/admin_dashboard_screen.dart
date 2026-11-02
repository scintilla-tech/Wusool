import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import 'admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenBuses;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenStudents,
    required this.onOpenBuses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: const BrandBar(
        title: 'إدارة الحركة والنقل',
        subtitle: 'جامعة الملك خالد',
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(adminDashboardProvider)),
        data: (d) => PageBody(
          onRefresh: () async {
            ref.invalidate(adminDashboardProvider);
            await ref.read(adminDashboardProvider.future);
          },
          children: [
            const PageHeading(
              'لوحة المعلومات',
              lead: 'مرحباً بك في لوحة التحكم الإدارية لنظام النقل.',
            ),
            Section(
              title: 'التشغيل',
              children: [
                NdsGrid(
                  columns: 3,
                  children: [
                    StatTile(value: '${d.buses}', label: 'الحافلات'),
                    StatTile(value: '${d.routes}', label: 'المسارات'),
                    StatTile(value: '${d.tripsToday}', label: 'رحلات اليوم'),
                  ],
                ),
              ],
            ),
            Section(
              title: 'المستخدمون',
              children: [
                NdsGrid(
                  columns: 2,
                  children: [
                    StatTile(value: '${d.students}', label: 'الطالبات'),
                    StatTile(value: '${d.drivers}', label: 'السائقون'),
                    StatTile(value: '${d.supervisors}', label: 'المشرفات'),
                    StatTile(
                      value: '${d.fieldSupervisors}',
                      label: 'المشرفات الميدانيات',
                    ),
                  ],
                ),
              ],
            ),
            Section(
              title: 'إجراءات سريعة',
              children: [
                NdsGrid(
                  columns: 2,
                  children: [
                    NdsTile(
                      icon: HugeIcons.strokeRoundedMortarboard01,
                      label: 'دليل الطالبات',
                      onTap: onOpenStudents,
                    ),
                    NdsTile(
                      icon: HugeIcons.strokeRoundedBus01,
                      label: 'الحافلات',
                      onTap: onOpenBuses,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
