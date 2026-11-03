import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'driver_providers.dart';

enum _Day { today, tomorrow, other }

/// A driver tells the bus supervisor which day they cannot drive; the
/// supervisor picks a cover. Lists the days already reported.
class AbsenceScreen extends ConsumerStatefulWidget {
  const AbsenceScreen({super.key});

  @override
  ConsumerState<AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends ConsumerState<AbsenceScreen> {
  final _note = TextEditingController();
  _Day _day = _Day.tomorrow;
  DateTime? _other;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get _date => switch (_day) {
    _Day.today => _today,
    _Day.tomorrow => _today.add(const Duration(days: 1)),
    _Day.other => _other,
  };

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _other ?? _today.add(const Duration(days: 2)),
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 60)),
      helpText: 'اليوم الذي لن تقود فيه',
    );
    if (picked != null) {
      setState(() {
        _other = picked;
        _day = _Day.other;
      });
    }
  }

  Future<void> _report() async {
    final date = _date;
    if (date == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/driver/absences',
            data: {
              'date': isoDay(date),
              if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
            },
          );
      if (!mounted) return;
      _note.clear();
      ref.invalidate(driverAbsencesProvider);
      showMessage(context, 'أُبلغت المشرفة بغيابك ${dayLabel(date)}');
    } catch (error) {
      if (mounted) showMessage(context, _failure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(DriverAbsence absence) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'ستقود ${dayLabel(absence.date)}؟',
      message: 'يُلغى الإبلاغ وتُخبر المشرفة.',
      confirmLabel: 'إلغاء الإبلاغ',
      icon: HugeIcons.strokeRoundedCalendar03,
      tone: Tone.primary,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .delete('/driver/absences/${absence.id}');
      ref.invalidate(driverAbsencesProvider);
      if (mounted) showMessage(context, 'أُلغي الإبلاغ');
    } catch (error) {
      if (mounted) showMessage(context, _failure(error), error: true);
    }
  }

  String _failure(Object error) => switch (apiErrorCode(error)) {
    'ABSENCE_EXISTS' => 'أبلغت عن هذا اليوم من قبل',
    'NO_SUPERVISOR' => 'لا مشرفة لحافلتك؛ تواصل مع إدارة النقل',
    'INVALID_DATE' => 'اختر اليوم أو يوماً خلال 60 يوماً',
    'COVER_CHOSEN' => 'اختارت المشرفة بديلاً؛ تواصل معها',
    'NO_BUS' => 'لست معيّناً على حافلة',
    _ => 'تعذّر الإبلاغ، حاول مرة أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final reported = ref.watch(driverAbsencesProvider);
    final date = _date;
    return Scaffold(
      appBar: const NdsAppBar(title: 'الإبلاغ عن غياب'),
      body: PageBody(
        onRefresh: () async {
          ref.invalidate(driverAbsencesProvider);
          await ref.read(driverAbsencesProvider.future);
        },
        children: [
          const InlineNote(
            'تصل المشرفة رسالة لتختار سائقاً بديلاً، وتُنشأ رحلات ذلك اليوم '
            'باسمه.',
          ),
          Section(
            title: 'اليوم',
            children: [
              NdsChoiceChips<_Day>(
                options: [
                  (_Day.today, 'اليوم'),
                  (_Day.tomorrow, 'غداً'),
                  (_Day.other, _other == null ? 'يوم آخر' : dayLabel(_other!)),
                ],
                selected: _day,
                onSelected: (value) => value == _Day.other
                    ? _pickDay()
                    : setState(() => _day = value),
              ),
            ],
          ),
          NdsField(
            label: 'السبب (اختياري)',
            controller: _note,
            hint: 'مثل: موعد طبي',
          ),
          ...reported.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(onRetry: () => ref.invalidate(driverAbsencesProvider)),
            ],
            data: (absences) => [
              if (absences.isNotEmpty)
                Section(
                  title: 'أيام أبلغت عنها',
                  children: [
                    for (final absence in absences)
                      NdsListItem(
                        leading: const FeaturedIcon(
                          HugeIcons.strokeRoundedCalendar03,
                          tone: Tone.warning,
                        ),
                        title: dayLabel(absence.date),
                        titleBadge: absence.coverName == null
                            ? const NdsTag(
                                'بلا بديل',
                                status: TagStatus.warning,
                              )
                            : const NdsTag('محدد', status: TagStatus.success),
                        meta: absence.coverName == null
                            ? 'بانتظار اختيار بديل'
                            : 'البديل: ${absence.coverName}',
                        meta2: absence.note,
                        trailing: absence.coverName == null
                            ? IconButton(
                                tooltip: 'إلغاء الإبلاغ',
                                onPressed: () => _cancel(absence),
                                icon: const AppIcon(
                                  HugeIcons.strokeRoundedCancel01,
                                  size: 20,
                                  color: Nds.textError,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NdsFooter(
        children: [
          ElevatedButton(
            onPressed: _busy || date == null ? null : _report,
            child: Text(
              date == null
                  ? 'اختر اليوم'
                  : 'إبلاغ المشرفة بغيابي ${dayLabel(date)}',
            ),
          ),
        ],
      ),
    );
  }
}
