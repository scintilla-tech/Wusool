import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../home/notifications.dart';
import 'admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenStaff;
  final VoidCallback onOpenBuses;
  final VoidCallback onOpenRoutes;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenStudents,
    required this.onOpenStaff,
    required this.onOpenBuses,
    required this.onOpenRoutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: const BrandBar(
        title: 'إدارة الحركة والنقل',
        subtitle: 'جامعة الملك خالد',
        actions: [NotificationBell()],
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
                      icon: HugeIcons.strokeRoundedUserGroup,
                      label: 'الموظفون',
                      onTap: onOpenStaff,
                    ),
                    NdsTile(
                      icon: HugeIcons.strokeRoundedBus01,
                      label: 'الحافلات',
                      onTap: onOpenBuses,
                    ),
                    NdsTile(
                      icon: HugeIcons.strokeRoundedRoute01,
                      label: 'المسارات',
                      onTap: onOpenRoutes,
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
