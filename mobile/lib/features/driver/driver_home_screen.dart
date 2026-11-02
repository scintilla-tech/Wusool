import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/date_format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import 'driver_providers.dart';
import 'driver_screen.dart';
import 'driver_trip_screens.dart';

class DriverHomeScreen extends ConsumerWidget {
  final DriverActions actions;

  const DriverHomeScreen({super.key, required this.actions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final async = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: const BrandBar(
        title: 'بوابة السائقين',
        subtitle: 'نظام النقل الجامعي للطالبات',
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
              await ref.read(driverTripsProvider.future);
            },
            children: [
              GreetingHeader(
                name: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                greeting: 'مرحباً، ${user?.firstName ?? ''}',
                subtitle: formatArabicDate(DateTime.now()),
              ),
              if (current == null)
                const HeroPanel(
                  children: [
                    HeroHeading(
                      caption: 'رحلات اليوم',
                      title: 'لا توجد رحلات مجدولة',
                    ),
                    HeroDivider(),
                    HeroInfoRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label: 'رحلاتك',
                      value: 'ستظهر هنا عند جدولتها من الإدارة',
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
              if (trips.isNotEmpty)
                Section(
                  title: 'رحلات اليوم',
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
                        trailing: NdsTag(
                          tripStatusLabel(trip.status),
                          status: tripStatusTag(trip.status),
                        ),
                        chevron: true,
                        onTap: () => openDriverTrip(context, trip, actions),
                      ),
                  ],
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
            caption: 'حافلتك اليوم · ${directionLabel(trip.direction)}',
            title: plate,
            tag: trip.routeName,
          ),
          const HeroDivider(),
          ValueRow(
            label: 'الطالبات المسجلات',
            value: studentCount(trip.students.length),
            onColor: true,
          ),
          ValueRow(
            label: 'حاضرات اليوم',
            value: studentCount(trip.attending),
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
