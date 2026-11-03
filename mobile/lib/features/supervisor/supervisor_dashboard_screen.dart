import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import '../home/notifications.dart';
import 'supervisor_providers.dart';
import 'supervisor_widgets.dart';

/// Home for bus supervisors (their live buses) and field supervisors
/// (fleet-wide figures, with the bus list in its own tab).
class SupervisorDashboardScreen extends ConsumerWidget {
  final bool field;
  final VoidCallback? onShowBuses;

  const SupervisorDashboardScreen({
    super.key,
    required this.field,
    this.onShowBuses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final async = ref.watch(supervisorBusesProvider);

    return Scaffold(
      appBar: BrandBar(
        title: field ? 'لوحة التحكم الميدانية' : 'مشرفة الحافلات',
        subtitle: field
            ? 'نظام النقل الجامعي للطالبات'
            : '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
        actions: [if (!field) const NotificationBell()],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(supervisorBusesProvider)),
        data: (buses) {
          int sum(int Function(SupervisorBusView bus) pick) =>
              buses.fold(0, (total, bus) => total + pick(bus));
          int count(String? status) =>
              buses.where((bus) => bus.tripStatus == status).length;
          final missed = sum((bus) => bus.missed);
          final total = sum((bus) => bus.total);
          final boarded = sum((bus) => bus.boarded);

          return PageBody(
            onRefresh: () async {
              ref.invalidate(supervisorBusesProvider);
              await ref.read(supervisorBusesProvider.future);
            },
            children: [
              if (field)
                const PageHeading(
                  'حالة الحركة الميدانية',
                  lead: 'متابعة فورية لحركة الحافلات وصعود الطالبات اليوم.',
                ),
              if (missed > 0)
                NdsAlert(
                  status: TagStatus.error,
                  title: missed == 1
                      ? 'طالبة واحدة فاتتها الحافلة اليوم'
                      : '$missed طالبات فاتتهن الحافلة اليوم',
                  description: 'سجّل السائقون عدم صعودهن عند المرور بمواقعهن.',
                ),
              if (field) ...[
                Section(
                  title: 'الحافلات',
                  children: [
                    NdsGrid(
                      columns: 2,
                      children: [
                        StatTile(
                          value: '${buses.length}',
                          label: 'إجمالي الحافلات',
                        ),
                        StatTile(
                          value: '${count('IN_PROGRESS')}',
                          label: 'في الطريق',
                          color: Nds.textInfo,
                        ),
                        StatTile(
                          value: '${count('COMPLETED')}',
                          label: 'وصلت',
                          color: Nds.textSuccess,
                        ),
                        StatTile(
                          value: '${count('SCHEDULED')}',
                          label: 'لم تنطلق',
                          color: Nds.textWarning,
                        ),
                      ],
                    ),
                  ],
                ),
                TitledPanel(
                  title: 'صعود الطالبات اليوم',
                  child: NdsGroup(
                    gap: Space.lg,
                    children: [
                      MiniStats(
                        items: [
                          ('$total', 'الطالبات', null),
                          ('$boarded', 'صعدن', Nds.textSuccess),
                          (
                            '${sum((bus) => bus.waiting + bus.notReady)}',
                            'بانتظار',
                            Nds.textWarning,
                          ),
                          ('$missed', 'فائتات', Nds.textError),
                        ],
                      ),
                      ValueRow(
                        label: 'نسبة الاكتمال',
                        value: total == 0
                            ? '0٪'
                            : '${(boarded * 100 / total).round()}٪',
                      ),
                      ProgressTrack(
                        value: total == 0 ? 0 : boarded / total,
                        semanticsLabel: 'صعدت $boarded من $total طالبة',
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onShowBuses,
                  icon: const AppIcon(HugeIcons.strokeRoundedBus01, size: 20),
                  label: const Text('متابعة الحافلات'),
                ),
              ] else ...[
                Row(
                  children: [
                    const Expanded(child: PageHeading('حافلاتي المباشرة')),
                    Text(
                      busCount(buses.length),
                      style: NdsText.textSm.copyWith(color: Nds.textSecondary),
                    ),
                  ],
                ),
                if (buses.isEmpty)
                  const MessageView(
                    icon: HugeIcons.strokeRoundedBus01,
                    title: 'لا توجد حافلات مسندة إليك',
                    message: 'تظهر هنا الحافلات بعد إسنادها من الإدارة.',
                  ),
                if (buses.isNotEmpty)
                  NdsGroup(
                    children: [
                      for (final bus in buses) SupervisorBusItem(bus: bus),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
