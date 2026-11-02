import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import 'platform_providers.dart';

class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformTenantsProvider);

    return Scaffold(
      appBar: BrandBar(
        title: 'إدارة المنصة',
        subtitle: 'نظام النقل الجامعي للطالبات',
        showLogo: false,
        actions: [
          CircleIconButton(
            icon: HugeIcons.strokeRoundedLogout01,
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(platformTenantsProvider)),
        data: (tenants) => PageBody(
          onRefresh: () async {
            ref.invalidate(platformTenantsProvider);
            await ref.read(platformTenantsProvider.future);
          },
          children: [
            const PageHeading(
              'الجامعات',
              lead: 'الجامعات المشتركة في نظام النقل وحالة كل منها.',
            ),
            NdsGrid(
              columns: 3,
              children: [
                StatTile(value: '${tenants.length}', label: 'الجامعات'),
                StatTile(
                  value: '${tenants.where((t) => t.isActive).length}',
                  label: 'نشطة',
                  color: Nds.textSuccess,
                ),
                StatTile(
                  value: '${tenants.fold(0, (sum, t) => sum + t.users)}',
                  label: 'المستخدمون',
                ),
              ],
            ),
            if (tenants.isEmpty)
              const MessageView(
                icon: HugeIcons.strokeRoundedUniversity,
                title: 'لا توجد جامعات',
              )
            else
              NdsGroup(
                children: [
                  for (final tenant in tenants)
                    NdsListItem(
                      leading: FeaturedIcon(
                        HugeIcons.strokeRoundedUniversity,
                        tone: tenant.isActive ? Tone.primary : Tone.neutral,
                      ),
                      title: tenant.name,
                      titleBadge: NdsTag(
                        tenant.isActive ? 'نشطة' : 'موقوفة',
                        status: tenant.isActive
                            ? TagStatus.success
                            : TagStatus.error,
                      ),
                      meta: 'الرمز: ${ltr(tenant.code)}',
                      meta2:
                          '${tenant.users} مستخدم · ${busCount(tenant.buses)}',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
