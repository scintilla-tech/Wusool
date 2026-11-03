import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import '../driver/driver_providers.dart' show dayLabel;
import 'cover_driver_screen.dart';
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
          _TodayDriver(bus: bus),
          if (bus.absences.isNotEmpty) _DaysOff(bus: bus),
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

/// Who drives the bus today, and, for its own supervisor, choosing a cover.
class _TodayDriver extends ConsumerWidget {
  final SupervisorBusView bus;

  const _TodayDriver({required this.bus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownSupervisor = ref.watch(authProvider).user?.role == 'SUPERVISOR';
    final driver = bus.driverName ?? bus.regularDriverName;
    final covering = bus.drivers.any((trip) => trip.coveredDriverName != null);
    // Each trip gets its own row when the going and return drivers differ.
    final split = bus.drivers.map((trip) => trip.driverName).toSet().length > 1;
    return TitledPanel(
      title: 'سائق اليوم',
      trailing: covering
          ? const NdsTag('سائق بديل', status: TagStatus.info)
          : null,
      child: NdsGroup(
        children: [
          if (split)
            for (final trip in bus.drivers)
              NdsListItem(
                leading: InitialsAvatar(trip.driverName ?? '؟'),
                title: trip.driverName ?? 'بلا سائق',
                titleBadge: NdsTag(
                  tripStatusLabel(trip.status),
                  status: tripStatusTag(trip.status),
                ),
                meta: trip.coveredDriverName == null
                    ? directionLabel(trip.direction)
                    : '${directionLabel(trip.direction)} · بديلاً عن ${trip.coveredDriverName}',
              )
          else if (driver == null)
            const InlineNote(
              'لا سائق لهذه الحافلة.',
              icon: HugeIcons.strokeRoundedAlert02,
              color: NdsColors.yellow600,
            )
          else
            NdsListItem(
              leading: InitialsAvatar(driver),
              title: driver,
              meta: covering
                  ? 'بديلاً عن ${bus.coveredDriverName}'
                  : 'سائق الحافلة',
            ),
          if (ownSupervisor && bus.coverable > 0)
            OutlinedButton.icon(
              style: NdsButtons.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CoverDriverScreen(bus: bus),
                ),
              ),
              icon: const AppIcon(HugeIcons.strokeRoundedUserSwitch, size: 18),
              label: Text(covering ? 'تغيير السائق' : 'تعيين سائق بديل'),
            )
          else if (ownSupervisor && bus.hasTrip)
            const InlineNote('بدأت رحلات اليوم، فلا يمكن تغيير سائقها.'),
        ],
      ),
    );
  }
}

/// Days the bus's driver reported they cannot drive, with the cover chosen.
class _DaysOff extends ConsumerWidget {
  final SupervisorBusView bus;

  const _DaysOff({required this.bus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownSupervisor = ref.watch(authProvider).user?.role == 'SUPERVISOR';
    return TitledPanel(
      title: 'غياب السائق',
      child: NdsGroup(
        children: [
          for (final absence in bus.absences)
            NdsListItem(
              leading: const FeaturedIcon(
                HugeIcons.strokeRoundedCalendar03,
                tone: Tone.warning,
              ),
              title: '${absence.driverName} · ${dayLabel(absence.date)}',
              titleBadge: absence.coverName == null
                  ? const NdsTag('بلا بديل', status: TagStatus.warning)
                  : null,
              meta: absence.coverName == null
                  ? absence.note
                  : 'البديل: ${absence.coverName}',
              meta2: absence.coverName == null ? null : absence.note,
              chevron: ownSupervisor,
              onTap: ownSupervisor
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CoverDriverScreen(bus: bus, date: absence.date),
                      ),
                    )
                  : null,
            ),
          if (ownSupervisor)
            const InlineNote('اختاري اليوم لتعيين السائق البديل.'),
        ],
      ),
    );
  }
}
