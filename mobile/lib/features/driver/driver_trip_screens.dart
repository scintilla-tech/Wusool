import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'driver_providers.dart';
import 'driver_screen.dart';

/// Opens the screen that fits the trip's state: the pre-trip attendance
/// screen, the live boarding screen, or the summary.
void openDriverTrip(
  BuildContext context,
  DriverTrip trip,
  DriverActions actions,
) {
  final Widget page = trip.isInProgress
      ? TripActiveScreen(tripId: trip.id!, actions: actions)
      : trip.isScheduled
      ? StartTripScreen(tripId: trip.id!, actions: actions)
      : TripSummaryScreen(trip: trip);
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Confirms, completes the trip and shows its summary.
Future<void> endDriverTrip(
  BuildContext context,
  DriverTrip trip,
  DriverActions actions, {
  bool replace = false,
}) async {
  final pending = trip.expected - trip.boarded;
  final confirmed = await showConfirmSheet(
    context,
    title: 'إنهاء الرحلة؟',
    message:
        'صعدت ${trip.boarded} من ${trip.expected}.'
        '${pending > 0 ? ' لم تصعد $pending بعد.' : ''}',
    confirmLabel: 'إنهاء الرحلة',
    cancelLabel: 'متابعة الرحلة',
    destructive: true,
  );
  if (!confirmed || !await actions.completeTrip(trip) || !context.mounted) {
    return;
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => TripSummaryScreen(trip: trip),
  );
  final navigator = Navigator.of(context);
  replace ? navigator.pushReplacement(route) : navigator.push(route);
}

String _studentName(DriverTripStudent student) =>
    '${student.firstName} ${student.lastName}';

String _tripSubtitle(DriverTrip trip) => [
  if (trip.busPlate != null) ltr(trip.busPlate!),
  ?trip.routeName,
].join(' · ');

/// Looks the trip up in the live trip list so the screen follows refreshes.
class _TripLookup extends ConsumerWidget {
  final String tripId;
  final String title;
  final Widget Function(DriverTrip trip, bool otherTripRunning) builder;

  const _TripLookup({
    required this.tripId,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverTripsProvider);
    final trips = async.value ?? const <DriverTrip>[];
    final trip = trips.where((trip) => trip.id == tripId).firstOrNull;
    if (trip != null) {
      final otherRunning = trips.any(
        (other) => other.isInProgress && other.id != tripId,
      );
      return builder(trip, otherRunning);
    }
    return Scaffold(
      appBar: NdsAppBar(title: title),
      body: async.isLoading
          ? const LoadingView()
          : async.hasError
          ? ErrorView(onRetry: () => ref.invalidate(driverTripsProvider))
          : const MessageView(
              icon: HugeIcons.strokeRoundedBus01,
              title: 'لم تعد هذه الرحلة متاحة',
            ),
    );
  }
}

/// Pre-trip screen: trip details, attendance and the start button.
class StartTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  final DriverActions actions;

  const StartTripScreen({
    super.key,
    required this.tripId,
    required this.actions,
  });

  @override
  ConsumerState<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends ConsumerState<StartTripScreen> {
  bool _starting = false;

  Future<void> _start(DriverTrip trip) async {
    setState(() => _starting = true);
    final started = await widget.actions.startTrip(trip);
    if (!mounted) return;
    setState(() => _starting = false);
    if (started) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              TripActiveScreen(tripId: widget.tripId, actions: widget.actions),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TripLookup(
      tripId: widget.tripId,
      title: 'بدء الرحلة',
      builder: (trip, otherTripRunning) {
        final closed = trip.attendanceClosed;
        return Scaffold(
          appBar: NdsAppBar(
            title: 'بدء الرحلة',
            subtitle: directionLabel(trip.direction),
          ),
          body: PageBody(
            onRefresh: () async {
              ref.invalidate(driverTripsProvider);
              await ref.read(driverTripsProvider.future);
            },
            children: [
              TitledPanel(
                title: 'تفاصيل الرحلة',
                trailing: trip.routeName == null
                    ? null
                    : NdsTag(trip.routeName!),
                child: KvList([
                  KvEntry(
                    'الحافلة',
                    trip.busPlate == null ? '—' : ltr(trip.busPlate!),
                  ),
                  KvEntry('الاتجاه', directionLabel(trip.direction)),
                  KvEntry('حالة التحضير', closed ? 'مغلق' : 'مفتوح'),
                ]),
              ),
              Section(
                title: 'حضور الطالبات اليوم',
                children: [
                  NdsGrid(
                    columns: 4,
                    children: [
                      StatTile(
                        value: '${trip.students.length}',
                        label: 'مسجلات',
                        centered: true,
                      ),
                      StatTile(
                        value: '${trip.attending}',
                        label: 'حاضرات',
                        color: Nds.textSuccess,
                        centered: true,
                      ),
                      StatTile(
                        value: '${trip.absent}',
                        label: 'غائبات',
                        color: Nds.textSecondary,
                        centered: true,
                      ),
                      StatTile(
                        value: '${trip.unregistered}',
                        label: 'لم يسجلن',
                        color: Nds.textWarning,
                        centered: true,
                      ),
                    ],
                  ),
                  if (closed)
                    const InlineNote(
                      'أُغلق التحضير، ولم يعد بإمكان الطالبات تعديله.',
                      icon: HugeIcons.strokeRoundedSquareLock01,
                      color: Nds.iconNeutral,
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.actions.closeAttendance(context, trip),
                      icon: const AppIcon(
                        HugeIcons.strokeRoundedTickDouble02,
                        size: 20,
                      ),
                      label: const Text('اكتمال التحضير'),
                    ),
                ],
              ),
              Section(
                title: 'تحضير الطالبات (${trip.students.length})',
                children: [
                  if (trip.students.isEmpty)
                    const InlineNote('لا توجد طالبات في هذه الرحلة.'),
                  for (final student in trip.students)
                    _AttendanceItem(
                      student: student,
                      closed: closed,
                      onIntent: (intent) =>
                          widget.actions.setAttendance(trip, student, intent),
                    ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: NdsFooter(
            children: [
              if (otherTripRunning)
                const InlineNote(
                  'لديك رحلة جارية. أنهِها قبل بدء هذه الرحلة.',
                  icon: HugeIcons.strokeRoundedAlert02,
                  color: NdsColors.yellow600,
                ),
              ElevatedButton.icon(
                onPressed: trip.isScheduled && !otherTripRunning && !_starting
                    ? () => _start(trip)
                    : null,
                icon: _starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppIcon(HugeIcons.strokeRoundedPlay, size: 22),
                label: const Text('ابدأ الرحلة الآن'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceItem extends StatelessWidget {
  final DriverTripStudent student;
  final bool closed;
  final ValueChanged<String> onIntent;

  const _AttendanceItem({
    required this.student,
    required this.closed,
    required this.onIntent,
  });

  @override
  Widget build(BuildContext context) {
    final name = _studentName(student);
    final (label, status) = switch (student.attendanceIntent) {
      'ATTENDING' => ('حاضرة', TagStatus.success),
      'ABSENT' => ('غائبة', TagStatus.neutral),
      _ => ('لم تسجل', TagStatus.warning),
    };
    return NdsListItem(
      leading: InitialsAvatar(name),
      title: name,
      meta: student.expectedFinishTime == null
          ? null
          : 'الانتهاء المتوقع ${ltr(student.expectedFinishTime!)}',
      trailing: NdsTag(label, status: status),
      bottom: closed
          ? null
          : Row(
              children: [
                Expanded(
                  child: ChoiceButton(
                    label: 'حاضرة',
                    selected: student.attendanceIntent == 'ATTENDING',
                    onPressed: () => onIntent('ATTENDING'),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: ChoiceButton(
                    label: 'غائبة',
                    selected: student.attendanceIntent == 'ABSENT',
                    onPressed: () => onIntent('ABSENT'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Live boarding screen while the trip is running.
class TripActiveScreen extends ConsumerStatefulWidget {
  final String tripId;
  final DriverActions actions;

  const TripActiveScreen({
    super.key,
    required this.tripId,
    required this.actions,
  });

  @override
  ConsumerState<TripActiveScreen> createState() => _TripActiveScreenState();
}

class _TripActiveScreenState extends ConsumerState<TripActiveScreen> {
  String? _busyStudent;

  Future<void> _mark(
    DriverTrip trip,
    DriverTripStudent student,
    String status,
  ) async {
    setState(() => _busyStudent = student.studentProfileId);
    await widget.actions.markTransport(trip, student, status);
    if (mounted) setState(() => _busyStudent = null);
  }

  @override
  Widget build(BuildContext context) {
    return _TripLookup(
      tripId: widget.tripId,
      title: 'الرحلة نشطة',
      builder: (trip, _) {
        final boarded = trip.students
            .where((student) => student.status == 'BOARDED')
            .toList();
        final pending =
            trip.students
                .where((student) => student.status != 'BOARDED')
                .toList()
              ..sort(
                (a, b) => (a.attendanceIntent == 'ABSENT' ? 1 : 0).compareTo(
                  b.attendanceIntent == 'ABSENT' ? 1 : 0,
                ),
              );
        final waiting = trip.expected - trip.boarded;

        return Scaffold(
          appBar: NdsAppBar(
            title: trip.isInProgress ? 'الرحلة نشطة' : 'الرحلة',
            subtitle: _tripSubtitle(trip),
          ),
          body: PageBody(
            onRefresh: () async {
              ref.invalidate(driverTripsProvider);
              await ref.read(driverTripsProvider.future);
            },
            children: [
              NdsPanel(
                child: NdsGroup(
                  gap: Space.lg,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'صعدن ${trip.boarded}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Nds.textSuccess,
                                  ),
                                ),
                                TextSpan(
                                  text: ' من ${trip.expected} حاضرة',
                                  style: const TextStyle(
                                    color: Nds.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            style: NdsText.textSm,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'لم يصعدن ',
                                style: TextStyle(color: Nds.textSecondary),
                              ),
                              TextSpan(
                                text: '${waiting < 0 ? 0 : waiting}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Nds.textWarning,
                                ),
                              ),
                            ],
                          ),
                          style: NdsText.textSm,
                        ),
                      ],
                    ),
                    ProgressTrack(
                      value: trip.expected == 0
                          ? 0
                          : trip.boarded / trip.expected,
                      semanticsLabel:
                          'صعدت ${trip.boarded} من ${trip.expected} طالبة',
                    ),
                  ],
                ),
              ),
              if (!trip.attendanceClosed)
                NdsAlert(
                  status: TagStatus.warning,
                  title: 'التحضير ما زال مفتوحاً',
                  description: 'أغلقه لتثبيت قائمة الحاضرات لهذه الرحلة.',
                  action: OutlinedButton(
                    style: NdsButtons.small,
                    onPressed: () =>
                        widget.actions.closeAttendance(context, trip),
                    child: const Text('اكتمال التحضير'),
                  ),
                ),
              if (pending.isNotEmpty)
                Section(
                  title: 'لم يصعدن بعد (${pending.length})',
                  children: [
                    for (final student in pending)
                      _BoardingItem(
                        student: student,
                        busy: _busyStudent == student.studentProfileId,
                        actionsEnabled: trip.isInProgress,
                        onMark: (status) => _mark(trip, student, status),
                      ),
                  ],
                ),
              if (boarded.isNotEmpty)
                Section(
                  title: 'صعدن (${boarded.length})',
                  children: [
                    for (final student in boarded)
                      NdsListItem(
                        leading: InitialsAvatar(_studentName(student)),
                        title: _studentName(student),
                        trailing: const NdsTag(
                          'صعدت',
                          status: TagStatus.success,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: trip.isInProgress
              ? NdsFooter(
                  children: [
                    OutlinedButton(
                      style: NdsButtons.destructiveOutline,
                      onPressed: () => endDriverTrip(
                        context,
                        trip,
                        widget.actions,
                        replace: true,
                      ),
                      child: const Text('إنهاء الرحلة'),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class _BoardingItem extends StatelessWidget {
  final DriverTripStudent student;
  final bool busy;
  final bool actionsEnabled;
  final ValueChanged<String> onMark;

  const _BoardingItem({
    required this.student,
    required this.busy,
    required this.actionsEnabled,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final name = _studentName(student);
    final (label, status) = switch (student.status) {
      'NOT_READY' => ('غير جاهزة', TagStatus.warning),
      'MISSED' => ('لم تحضر', TagStatus.error),
      _ =>
        student.attendanceIntent == 'ABSENT'
            ? ('غائبة', TagStatus.neutral)
            : ('بانتظار', TagStatus.warning),
    };
    final enabled = actionsEnabled && !busy;
    return NdsListItem(
      leading: InitialsAvatar(name),
      title: name,
      meta: student.attendanceIntent == 'ABSENT' ? 'أبلغت بعدم الحضور' : null,
      trailing: NdsTag(label, status: status),
      bottom: !actionsEnabled
          ? null
          : Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: NdsButtons.compact,
                    onPressed: enabled ? () => onMark('BOARDED') : null,
                    icon: const AppIcon(
                      HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 18,
                    ),
                    label: const Text('صعدت'),
                  ),
                ),
                const SizedBox(width: Space.md),
                OutlinedButton(
                  style: NdsButtons.compact,
                  onPressed: enabled && student.status != 'NOT_READY'
                      ? () => onMark('NOT_READY')
                      : null,
                  child: const Text('غير جاهزة'),
                ),
                const SizedBox(width: Space.md),
                OutlinedButton(
                  style: NdsButtons.compact,
                  onPressed: enabled && student.status != 'MISSED'
                      ? () => onMark('MISSED')
                      : null,
                  child: const Text('لم تحضر'),
                ),
              ],
            ),
    );
  }
}

/// Outcome of a finished trip.
class TripSummaryScreen extends StatelessWidget {
  final DriverTrip trip;

  const TripSummaryScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NdsAppBar(title: 'ملخص الرحلة', showBack: false),
      body: PageBody(
        gap: Space.x2l,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: NdsGroup(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FeaturedIcon(
                  HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 56,
                  tone: Tone.success,
                  circle: true,
                ),
                Text(
                  'تم إكمال الرحلة',
                  textAlign: TextAlign.center,
                  style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
                ),
                Text(
                  _tripSubtitle(trip),
                  textAlign: TextAlign.center,
                  style: NdsText.textMd.copyWith(color: Nds.textSecondary),
                ),
              ],
            ),
          ),
          TitledPanel(
            title: directionLabel(trip.direction),
            trailing: const NdsTag('مكتملة', status: TagStatus.success),
            child: KvList([
              KvEntry('الطالبات المسجلات', studentCount(trip.students.length)),
              KvEntry('الحاضرات', studentCount(trip.expected)),
              KvEntry(
                'صعدن',
                studentCount(trip.boarded),
                color: Nds.textSuccess,
              ),
              KvEntry(
                'غير جاهزات',
                studentCount(trip.notReady),
                color: Nds.textWarning,
              ),
              KvEntry(
                'لم يحضرن',
                studentCount(trip.missed),
                color: Nds.textError,
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: NdsFooter(
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('العودة للرئيسية'),
          ),
        ],
      ),
    );
  }
}
