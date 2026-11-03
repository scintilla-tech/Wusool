import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/date_format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import '../home/notifications.dart';
import 'absence_screen.dart';
import 'create_trip_screen.dart';
import 'driver_providers.dart';
import 'driver_route_screen.dart';
import 'driver_screen.dart';
import 'driver_trip_screens.dart';

class DriverHomeScreen extends ConsumerWidget {
  final DriverActions actions;

  const DriverHomeScreen({super.key, required this.actions});

  Future<void> _createTrip(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateTripScreen()));
    if (created == true) {
      ref.invalidate(driverTripsProvider);
      ref.invalidate(driverBusProvider);
    }
  }

  Future<void> _editRoute(
    BuildContext context,
    WidgetRef ref,
    DriverRoute? route,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DriverRouteScreen(route: route)),
    );
    if (saved == true) ref.invalidate(driverBusProvider);
  }

  void _reportAbsence(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AbsenceScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final async = ref.watch(driverTripsProvider);
    final bus = ref.watch(driverBusProvider).value;
    final absences = ref.watch(driverAbsencesProvider).value ?? const [];
    final canCreate =
        bus != null &&
        bus.hasBus &&
        bus.route != null &&
        bus.missing.isNotEmpty;

    return Scaffold(
      appBar: const BrandBar(
        title: 'بوابة السائقين',
        subtitle: 'نظام النقل الجامعي للطالبات',
        actions: [NotificationBell()],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(driverTripsProvider)),
        data: (trips) {
          final running = trips.where((trip) => trip.isInProgress).firstOrNull;
          final current =
              running ??
              trips.where((trip) => trip.isScheduled).firstOrNull ??
              trips.lastOrNull;

          return PageBody(
            onRefresh: () async {
              ref.invalidate(driverTripsProvider);
              ref.invalidate(driverBusProvider);
              ref.invalidate(driverAbsencesProvider);
              ref.invalidate(unreadCountProvider);
              await ref.read(driverTripsProvider.future);
            },
            children: [
              GreetingHeader(
                name: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                greeting: 'مرحباً، ${user?.firstName ?? ''}',
                subtitle: formatArabicDate(DateTime.now()),
              ),
              if (current == null)
                HeroPanel(
                  children: [
                    const HeroHeading(
                      caption: 'رحلات اليوم',
                      title: 'لا توجد رحلات مجدولة',
                    ),
                    const HeroDivider(),
                    HeroInfoRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label: 'رحلاتك',
                      value: switch (bus) {
                        null => 'ستظهر رحلاتك هنا',
                        DriverBus(hasBus: false) => 'لست معيّناً على حافلة بعد',
                        // The bus has trips today, but another driver has them.
                        DriverBus(todayDirections: Set(isNotEmpty: true)) =>
                          'يقود سائق بديل رحلات حافلتك اليوم',
                        DriverBus(holiday: final String name) =>
                          'اليوم إجازة: $name',
                        DriverBus(route: null) =>
                          'أنشئ مسار حافلتك مرة واحدة لتُجدول رحلاتها',
                        DriverBus(autoTrips: false) =>
                          'الرحلات التلقائية موقوفة؛ أنشئ رحلتك',
                        final DriverBus bus =>
                          'تُنشأ تلقائياً ${clockWords(bus.autoTripTime)} أيام الدراسة',
                      },
                    ),
                    if (canCreate)
                      OutlinedButton.icon(
                        style: NdsButtons.onColorOutline,
                        onPressed: () => _createTrip(context, ref),
                        icon: const AppIcon(
                          HugeIcons.strokeRoundedAdd01,
                          size: 20,
                        ),
                        label: const Text('إنشاء رحلة'),
                      ),
                  ],
                )
              else
                _DriverHero(
                  trip: current,
                  onOpen: () => openDriverTrip(context, current, actions),
                ),
              NdsGroup(
                gap: Space.sm,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              running == null && current?.isScheduled == true
                              ? () => openDriverTrip(context, current!, actions)
                              : null,
                          icon: const AppIcon(
                            HugeIcons.strokeRoundedPlay,
                            size: 22,
                          ),
                          label: const Text('بدء الرحلة'),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: OutlinedButton(
                          style: NdsButtons.destructiveOutline,
                          onPressed: running == null
                              ? null
                              : () => endDriverTrip(context, running, actions),
                          child: const Text('إنهاء الرحلة'),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    running != null
                        ? 'لديك رحلة جارية. أنهِها قبل بدء رحلة جديدة.'
                        : 'يتاح إنهاء الرحلة بعد بدئها.',
                    textAlign: TextAlign.center,
                    style: NdsText.textSm.copyWith(color: Nds.textSecondary),
                  ),
                ],
              ),
              for (final absence in absences.take(2))
                NdsAlert(
                  status: TagStatus.warning,
                  title: 'أبلغت عن غيابك ${dayLabel(absence.date)}',
                  description: absence.coverName == null
                      ? 'بانتظار أن تختار المشرفة سائقاً بديلاً.'
                      : 'يقود ${absence.coverName} بدلاً منك.',
                ),
              if (trips.isNotEmpty)
                Section(
                  title: 'رحلات اليوم',
                  trailing: canCreate
                      ? TextButton.icon(
                          onPressed: () => _createTrip(context, ref),
                          icon: const AppIcon(
                            HugeIcons.strokeRoundedAdd01,
                            size: 18,
                          ),
                          label: const Text('إنشاء رحلة'),
                        )
                      : null,
                  children: [
                    for (final trip in trips)
                      NdsListItem(
                        leading: FeaturedIcon(
                          trip.direction == 'OUTBOUND'
                              ? HugeIcons.strokeRoundedSunrise
                              : HugeIcons.strokeRoundedSunset,
                          tone: trip.isCompleted ? Tone.neutral : Tone.primary,
                        ),
                        title: directionLabel(trip.direction),
                        meta: [
                          ?trip.routeName,
                          if (trip.busPlate != null) ltr(trip.busPlate!),
                        ].join(' · '),
                        meta2: trip.coveringFor == null
                            ? null
                            : 'بديلاً عن ${trip.coveringFor}',
                        trailing: NdsTag(
                          tripStatusLabel(trip.status),
                          status: tripStatusTag(trip.status),
                        ),
                        chevron: true,
                        onTap: () => openDriverTrip(context, trip, actions),
                      ),
                  ],
                ),
              if (bus != null && bus.hasBus)
                _BusRoutePanel(
                  bus: bus,
                  onEdit: () => _editRoute(context, ref, bus.route),
                ),
              if (bus != null && bus.hasBus)
                OutlinedButton.icon(
                  onPressed: () => _reportAbsence(context),
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedCalendar03,
                    size: 20,
                  ),
                  label: const Text('لن أتمكن من القيادة'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverHero extends StatelessWidget {
  final DriverTrip trip;
  final VoidCallback onOpen;

  const _DriverHero({required this.trip, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final plate = trip.busPlate == null ? 'حافلتك' : ltr(trip.busPlate!);
    if (trip.isScheduled) {
      return HeroPanel(
        children: [
          HeroHeading(
            caption: trip.coveringFor == null
                ? 'حافلتك اليوم · ${directionLabel(trip.direction)}'
                : 'بديلاً عن ${trip.coveringFor} · ${directionLabel(trip.direction)}',
            title: plate,
            tag: trip.routeName,
          ),
          const HeroDivider(),
          ValueRow(
            label: 'الطالبات المسجلات',
            value: studentsOn(trip.students.length),
            onColor: true,
          ),
          ValueRow(
            label: 'حاضرات اليوم',
            value: studentsOn(trip.attending),
            onColor: true,
          ),
        ],
      );
    }
    final progress = trip.expected == 0 ? 0.0 : trip.boarded / trip.expected;
    return HeroPanel(
      children: [
        HeroHeading(
          caption: trip.isInProgress
              ? 'الرحلة جارية · ${directionLabel(trip.direction)}'
              : 'اكتملت ${directionLabel(trip.direction)}',
          title: plate,
          tag: trip.routeName,
        ),
        NdsGroup(
          gap: Space.sm,
          children: [
            ValueRow(
              label: 'صعدن',
              value: '${trip.boarded} من ${trip.expected}',
              onColor: true,
            ),
            ProgressTrack(
              value: progress,
              onColor: true,
              semanticsLabel: 'صعدت ${trip.boarded} من ${trip.expected} طالبة',
            ),
          ],
        ),
        OutlinedButton(
          style: NdsButtons.onColorOutline,
          onPressed: onOpen,
          child: Text(trip.isInProgress ? 'عرض الرحلة' : 'ملخص الرحلة'),
        ),
      ],
    );
  }
}

/// The bus's fixed route, or the call to build it once.
class _BusRoutePanel extends StatelessWidget {
  final DriverBus bus;
  final VoidCallback onEdit;

  const _BusRoutePanel({required this.bus, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final route = bus.route;
    if (route == null) {
      return NdsAlert(
        status: TagStatus.warning,
        title: 'ليس لحافلتك مسار ثابت',
        description:
            'أنشئه مرة واحدة: تُنشأ بعدها رحلاتك تلقائياً كل يوم دراسي.',
        action: ElevatedButton(
          style: NdsButtons.small,
          onPressed: onEdit,
          child: const Text('إنشاء مسار الحافلة'),
        ),
      );
    }
    return TitledPanel(
      title: 'مسار حافلتك',
      trailing: TextButton.icon(
        onPressed: onEdit,
        icon: const AppIcon(HugeIcons.strokeRoundedPencilEdit02, size: 18),
        label: const Text('تعديل'),
      ),
      child: NdsGroup(
        gap: Space.xs,
        children: [
          Text(
            route.name,
            style: NdsText.textMd.copyWith(
              fontWeight: FontWeight.w600,
              color: Nds.textDisplay,
            ),
          ),
          Text(
            route.stops.isEmpty ? 'لا محطات' : route.stopsLine,
            style: NdsText.textSm.copyWith(color: Nds.textSecondary),
          ),
          if (route.campusName != null)
            Text(
              'إلى ${route.campusName}',
              style: NdsText.textSm.copyWith(color: Nds.textSecondary),
            ),
        ],
      ),
    );
  }
}
