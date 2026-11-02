import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'supervisor_providers.dart';

class BusDetailScreen extends ConsumerWidget {
  final String busId;

  const BusDetailScreen({super.key, required this.busId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorBusesProvider);
    final bus = async.value?.where((bus) => bus.busId == busId).firstOrNull;
    if (bus == null) {
      return Scaffold(
        appBar: const NdsAppBar(title: 'الحافلة'),
        body: async.isLoading
            ? const LoadingView()
            : ErrorView(
                title: 'تعذر عرض الحافلة',
                onRetry: () => ref.invalidate(supervisorBusesProvider),
              ),
      );
    }

    return Scaffold(
      appBar: NdsAppBar(
        title: bus.name ?? ltr(bus.plateNumber),
        subtitle: bus.routeName ?? ltr(bus.plateNumber),
      ),
      body: PageBody(
        onRefresh: () async {
          ref.invalidate(supervisorBusesProvider);
          await ref.read(supervisorBusesProvider.future);
        },
        children: [
          NdsListItem(
            leading: FeaturedIcon(
              HugeIcons.strokeRoundedBus01,
              tone: bus.tripStatus == 'IN_PROGRESS'
                  ? Tone.primary
                  : Tone.neutral,
            ),
            title: ltr(bus.plateNumber),
            meta: bus.routeName,
            trailing: NdsTag(
              tripStatusLabel(bus.tripStatus),
              status: tripStatusTag(bus.tripStatus),
            ),
          ),
          if (!bus.hasTrip)
            const MessageView(
              icon: HugeIcons.strokeRoundedCalendar03,
              title: 'لا توجد رحلة لهذه الحافلة اليوم',
            )
          else ...[
            Section(
              title: bus.tripDirection == null
                  ? 'صعود الطالبات'
                  : 'صعود الطالبات · ${directionLabel(bus.tripDirection!)}',
              children: [
                NdsGrid(
                  columns: 4,
                  children: [
                    StatTile(
                      value: '${bus.total}',
                      label: 'الإجمالي',
                      centered: true,
                    ),
                    StatTile(
                      value: '${bus.boarded}',
                      label: 'صعدن',
                      color: Nds.textSuccess,
                      centered: true,
                    ),
                    StatTile(
                      value: '${bus.waiting + bus.notReady}',
                      label: 'بانتظار',
                      color: Nds.textWarning,
                      centered: true,
                    ),
                    StatTile(
                      value: '${bus.missed}',
                      label: 'فائتات',
                      color: Nds.textError,
                      centered: true,
                    ),
                  ],
                ),
                if (bus.total > 0)
                  ProgressTrack(
                    value: bus.boarded / bus.total,
                    semanticsLabel: 'صعدت ${bus.boarded} من ${bus.total} طالبة',
                  ),
                if (bus.notReady > 0)
                  InlineNote(
                    '${bus.notReady} من المنتظرات سجّلهن السائق غير جاهزات.',
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: NdsColors.yellow600,
                  ),
              ],
            ),
            if (bus.attendanceSessions.isNotEmpty)
              Section(
                title: 'ملخص التحضير',
                children: [
                  for (final session in bus.attendanceSessions)
                    TitledPanel(
                      title: session.direction == 'OUTBOUND'
                          ? 'تحضير الذهاب'
                          : 'تحضير العودة',
                      trailing: session.status == 'CLOSED'
                          ? const NdsTag('مغلق')
                          : const NdsTag('مفتوح', status: TagStatus.success),
                      child: MiniStats(
                        items: [
                          ('${session.attending}', 'حاضرات', Nds.textSuccess),
                          ('${session.absent}', 'غائبات', Nds.textSecondary),
                          (
                            '${session.unregistered}',
                            'لم يسجلن',
                            Nds.textWarning,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
