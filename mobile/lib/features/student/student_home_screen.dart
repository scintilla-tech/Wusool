import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import 'report_absence_screen.dart';
import 'student_providers.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onTrack;

  const StudentHomeScreen({super.key, required this.onTrack});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  bool _saving = false;

  Future<bool> _setIntent(
    AttendanceSessionView session,
    String intent, {
    String? expectedFinishTime,
    bool sendFinishTime = false,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put(
            '/attendance/today/${session.direction}',
            data: {
              'intent': intent,
              if (sendFinishTime) 'expectedFinishTime': expectedFinishTime,
            },
          );
      ref.invalidate(attendanceTodayProvider);
      return true;
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'تعذر تحديث التحضير. قد تكون الجلسة مغلقة.',
          error: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFinishTime(AttendanceSessionView session) async {
    final current = session.expectedFinishTime
        ?.split(':')
        .map(int.parse)
        .toList();
    final selected = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay(hour: current[0], minute: current[1])
          : const TimeOfDay(hour: 15, minute: 0),
      helpText: 'متى تتوقعين انتهاء دوامك اليوم؟',
    );
    if (selected == null) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    await _setIntent(
      session,
      session.intent!,
      expectedFinishTime: value,
      sendFinishTime: true,
    );
  }

  Future<void> _reportAbsence(
    AttendanceToday attendance,
    StudentTripView? trip,
  ) async {
    final reported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ReportAbsenceScreen(sessions: attendance.sessions, trip: trip),
      ),
    );
    if (reported == true && mounted) {
      ref.invalidate(attendanceTodayProvider);
      showMessage(context, 'تم إرسال بلاغ عدم الحضور');
    }
  }

  Future<void> _cancelAbsence(List<AttendanceSessionView> sessions) async {
    for (final session in sessions) {
      if (!await _setIntent(session, 'ATTENDING')) return;
    }
    if (mounted) showMessage(context, 'أُلغي البلاغ، وسُجّلتِ حاضرة');
  }

  Future<void> _refresh() async {
    ref.invalidate(studentTripProvider);
    ref.invalidate(attendanceTodayProvider);
    await ref.read(attendanceTodayProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final attendanceAsync = ref.watch(attendanceTodayProvider);
    final trip = ref.watch(studentTripProvider).value;
    final fullName = '${user?.firstName ?? ''} ${user?.lastName ?? ''}';

    return Scaffold(
      appBar: const BrandBar(
        title: 'بوابة الطالبات',
        subtitle: 'نظام النقل الجامعي للطالبات',
      ),
      body: attendanceAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => apiErrorCode(error) == 'NO_ACTIVE_ROUTE'
            ? PageBody(
                onRefresh: _refresh,
                children: [
                  GreetingHeader(
                    name: fullName,
                    greeting: 'مرحباً، ${user?.firstName ?? ''}',
                  ),
                  const MessageView(
                    icon: HugeIcons.strokeRoundedRoute01,
                    title: 'لم يُحدَّد مسارك بعد',
                    message: 'تظهر رحلاتك هنا بعد أن تُسند إدارة النقل إليكِ مساراً وحافلة.',
                  ),
                ],
              )
            : ErrorView(onRetry: () => ref.invalidate(attendanceTodayProvider)),
        data: (attendance) {
          final absent = attendance.sessions
              .where((session) => session.intent == 'ABSENT')
              .toList();
          final cancellable = absent.where((s) => s.isOpen).toList();
          final canReport = attendance.sessions.any((s) => s.isOpen);

          return PageBody(
            onRefresh: _refresh,
            children: [
              GreetingHeader(
                name: fullName,
                greeting: 'مرحباً، ${user?.firstName ?? ''}',
                subtitle: formatArabicDate(DateTime.now()),
              ),
              if (absent.isNotEmpty)
                NdsAlert(
                  status: TagStatus.info,
                  title: 'أبلغتِ بعدم حضورك ${_tripsLabel(absent)} اليوم',
                  description: 'يظهر البلاغ للسائق ومشرف الحافلة.',
                  action: cancellable.isEmpty
                      ? null
                      : OutlinedButton(
                          style: NdsButtons.small,
                          onPressed: _saving
                              ? null
                              : () => _cancelAbsence(cancellable),
                          child: const Text('إلغاء البلاغ'),
                        ),
                ),
              _TripHero(trip: trip),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onTrack,
                      icon: const AppIcon(
                        HugeIcons.strokeRoundedMaps,
                        size: 22,
                      ),
                      label: const Text('تتبع الحافلة'),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canReport && !_saving
                          ? () => _reportAbsence(attendance, trip)
                          : null,
                      child: const Text('لن أحضر اليوم'),
                    ),
                  ),
                ],
              ),
              Section(
                title: 'تحضير اليوم',
                children: [
                  if (attendance.sessions.isEmpty)
                    const NdsPanel(
                      child: InlineNote('لا يوجد تحضير لكِ اليوم.'),
                    ),
                  for (final session in attendance.sessions)
                    _SessionCard(
                      session: session,
                      disabled: _saving,
                      onIntent: (intent) => _setIntent(session, intent),
                      onPickFinish: () => _pickFinishTime(session),
                      onClearFinish: () => _setIntent(
                        session,
                        session.intent!,
                        expectedFinishTime: null,
                        sendFinishTime: true,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _tripsLabel(List<AttendanceSessionView> sessions) =>
      sessions.length > 1
      ? 'الرحلتين'
      : directionLabel(sessions.first.direction);
}

class _TripHero extends StatelessWidget {
  final StudentTripView? trip;

  const _TripHero({required this.trip});

  @override
  Widget build(BuildContext context) {
    final trip = this.trip;
    if (trip == null || !trip.hasActiveTrip) {
      return const HeroPanel(
        children: [
          HeroHeading(caption: 'رحلة اليوم', title: 'لا توجد رحلة الآن'),
          HeroDivider(),
          HeroInfoRow(
            icon: HugeIcons.strokeRoundedClock01,
            label: 'موعد الرحلة',
            value: 'ستظهر رحلتكِ هنا عند جدولتها',
          ),
        ],
      );
    }
    return HeroPanel(
      children: [
        HeroHeading(
          caption: 'رحلة اليوم',
          title: trip.busPlate == null ? 'حافلتكِ' : ltr(trip.busPlate!),
          tag: trip.routeName,
        ),
        const HeroDivider(),
        HeroInfoRow(
          icon: HugeIcons.strokeRoundedBus01,
          label: 'حالة الحافلة',
          value: trip.isInProgress ? 'الحافلة في الطريق' : 'لم تنطلق بعد',
        ),
        HeroInfoRow(
          icon: HugeIcons.strokeRoundedUserCheck01,
          label: 'حالتكِ',
          value: boardingStatusLabel(trip.myStatus),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceSessionView session;
  final bool disabled;
  final ValueChanged<String> onIntent;
  final VoidCallback onPickFinish;
  final VoidCallback onClearFinish;

  const _SessionCard({
    required this.session,
    required this.disabled,
    required this.onIntent,
    required this.onPickFinish,
    required this.onClearFinish,
  });

  @override
  Widget build(BuildContext context) {
    final outbound = session.direction == 'OUTBOUND';
    final canEdit = session.isOpen && !disabled;
    final closed = session.status == 'CLOSED';
    final (tagLabel, tagStatus) = switch (session.intent) {
      'ATTENDING' => ('ستحضرين', TagStatus.success),
      'ABSENT' => ('لن تحضري', TagStatus.neutral),
      _ => ('لم تحددي', TagStatus.warning),
    };
    final stateLabel = closed
        ? 'أُغلق التحضير'
        : session.isOpen
        ? 'التحضير مفتوح الآن'
        : 'يفتح التحضير الساعة ${ltr(clockLabel(session.opensAt))}';

    return NdsPanel(
      child: NdsGroup(
        gap: Space.lg,
        children: [
          Row(
            children: [
              FeaturedIcon(
                outbound
                    ? HugeIcons.strokeRoundedSunrise
                    : HugeIcons.strokeRoundedSunset,
                tone: closed ? Tone.neutral : Tone.primary,
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      directionLabel(session.direction),
                      style: NdsText.textMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Nds.textDisplay,
                      ),
                    ),
                    Text(
                      stateLabel,
                      style: NdsText.textSm.copyWith(color: Nds.textSecondary),
                    ),
                  ],
                ),
              ),
              NdsTag(tagLabel, status: tagStatus),
            ],
          ),
          if (closed)
            const InlineNote(
              'أغلق السائق التحضير لهذه الرحلة، ولا يمكن تعديله.',
              icon: HugeIcons.strokeRoundedSquareLock01,
              color: Nds.iconNeutral,
            )
          else
            Row(
              children: [
                Expanded(
                  child: ChoiceButton(
                    label: 'سأحضر',
                    selected: session.intent == 'ATTENDING',
                    onPressed: canEdit ? () => onIntent('ATTENDING') : null,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: ChoiceButton(
                    label: 'لن أحضر',
                    selected: session.intent == 'ABSENT',
                    onPressed: canEdit ? () => onIntent('ABSENT') : null,
                  ),
                ),
              ],
            ),
          if (outbound) ...[
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الانتهاء المتوقع لدوامك',
                        style: NdsText.textSm.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Nds.textDefault,
                        ),
                      ),
                      Text(
                        'اختياري وتقديري، ولا يسجّل تحضير العودة.',
                        style: NdsText.textXs.copyWith(
                          color: Nds.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                OutlinedButton.icon(
                  style: NdsButtons.compact,
                  onPressed: canEdit && session.intent != null
                      ? onPickFinish
                      : null,
                  icon: const AppIcon(HugeIcons.strokeRoundedClock01, size: 18),
                  label: Text(
                    session.expectedFinishTime == null
                        ? 'تحديد'
                        : ltr(session.expectedFinishTime!),
                  ),
                ),
                if (session.expectedFinishTime != null)
                  IconButton(
                    tooltip: 'مسح الوقت',
                    onPressed: canEdit && session.intent != null
                        ? onClearFinish
                        : null,
                    icon: const AppIcon(
                      HugeIcons.strokeRoundedCancel01,
                      size: 20,
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
