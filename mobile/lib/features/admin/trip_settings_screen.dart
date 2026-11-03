import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../driver/driver_providers.dart' show isoDay;
import 'admin_api.dart';

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// "4 نوفمبر".
String shortDate(DateTime day) => '${day.day} ${_months[day.month - 1]}';

/// "15 – 19 نوفمبر (5 أيام)" or "4 نوفمبر".
String holidayRange(Holiday holiday) {
  final count = countOf(
    holiday.days,
    one: 'يوم واحد',
    two: 'يومان',
    few: 'أيام',
    many: 'يوماً',
  );
  if (holiday.days == 1) return shortDate(holiday.start);
  final sameMonth = holiday.start.month == holiday.end.month;
  final from = sameMonth ? '${holiday.start.day}' : shortDate(holiday.start);
  return '$from – ${shortDate(holiday.end)} ($count)';
}

/// When and whether trips are made each school day, and the holidays they
/// skip.
class TripSettingsScreen extends ConsumerStatefulWidget {
  const TripSettingsScreen({super.key});

  @override
  ConsumerState<TripSettingsScreen> createState() => _TripSettingsScreenState();
}

class _TripSettingsScreenState extends ConsumerState<TripSettingsScreen> {
  bool _busy = false;

  Future<void> _update({bool? autoTrips, String? autoTripTime}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminApiProvider)
          .updateTripSettings(autoTrips: autoTrips, autoTripTime: autoTripTime);
      ref.invalidate(tripSettingsProvider);
      if (!mounted) return;
      showMessage(
        context,
        autoTripTime != null
            ? 'تُنشأ الرحلات ${clockWords(autoTripTime)}'
            : autoTrips == true
            ? 'شُغّلت الرحلات التلقائية'
            : 'أُوقفت الرحلات التلقائية',
      );
    } catch (error) {
      if (mounted) showMessage(context, adminFailure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      final confirmed = await showConfirmSheet(
        context,
        title: 'إيقاف الرحلات التلقائية؟',
        message:
            'لن تُنشأ رحلات أيام الدراسة حتى تعيد تشغيلها. لإجازة معروفة '
            'أضفها إلى التقويم بدلاً من ذلك.',
        confirmLabel: 'إيقاف',
        icon: HugeIcons.strokeRoundedCalendar03,
      );
      if (!confirmed || !mounted) return;
    }
    await _update(autoTrips: on);
  }

  Future<void> _pickTime(String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 5,
        minute: int.tryParse(parts.last) ?? 30,
      ),
      helpText: 'وقت إنشاء الرحلات',
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (value != current) await _update(autoTripTime: value);
  }

  Future<void> _editHoliday([Holiday? holiday]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => HolidayFormScreen(holiday: holiday)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(tripSettingsProvider);
    final holidays = ref.watch(holidaysProvider);
    return Scaffold(
      appBar: const NdsAppBar(title: 'الرحلات التلقائية'),
      body: PageBody(
        onRefresh: () async {
          ref.invalidate(tripSettingsProvider);
          ref.invalidate(holidaysProvider);
          await ref.read(tripSettingsProvider.future);
        },
        children: [
          ...settings.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(onRetry: () => ref.invalidate(tripSettingsProvider)),
            ],
            data: (s) => [
              NdsPanel(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إنشاء الرحلات تلقائياً',
                            style: NdsText.textMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Nds.textDisplay,
                            ),
                          ),
                          Text(
                            'من الأحد إلى الخميس، للحافلات ذات المسار الثابت، '
                            'عدا الإجازات.',
                            style: NdsText.textSm.copyWith(
                              color: Nds.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.autoTrips,
                      onChanged: _busy ? null : _toggle,
                    ),
                  ],
                ),
              ),
              NdsListItem(
                leading: const FeaturedIcon(HugeIcons.strokeRoundedClock01),
                title: 'وقت الإنشاء',
                meta:
                    '${clockWords(s.autoTripTime)} بتوقيت الرياض، ويُبلَّغ السائقون حينها',
                trailing: Text(
                  ltr(s.autoTripTime),
                  style: NdsText.textMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Nds.textPrimary,
                  ),
                ),
                onTap: _busy ? null : () => _pickTime(s.autoTripTime),
              ),
            ],
          ),
          Section(
            title: 'الإجازات',
            trailing: TextButton.icon(
              onPressed: _editHoliday,
              icon: const AppIcon(HugeIcons.strokeRoundedAdd01, size: 18),
              label: const Text('إضافة إجازة'),
            ),
            children: holidays.when(
              loading: () => const [LoadingView()],
              error: (_, _) => [
                ErrorView(onRetry: () => ref.invalidate(holidaysProvider)),
              ],
              data: (items) => [
                if (items.isEmpty)
                  const InlineNote(
                    'لا إجازات قادمة. أضف الإجازات الرسمية والفصلية لئلا تُنشأ '
                    'فيها رحلات.',
                  )
                else
                  for (final holiday in items)
                    NdsListItem(
                      leading: const FeaturedIcon(
                        HugeIcons.strokeRoundedCalendar03,
                        tone: Tone.warning,
                      ),
                      title: holiday.name,
                      meta: holidayRange(holiday),
                      chevron: true,
                      onTap: () => _editHoliday(holiday),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds a holiday, or edits or removes [holiday].
class HolidayFormScreen extends ConsumerStatefulWidget {
  final Holiday? holiday;

  const HolidayFormScreen({super.key, this.holiday});

  @override
  ConsumerState<HolidayFormScreen> createState() => _HolidayFormScreenState();
}

class _HolidayFormScreenState extends ConsumerState<HolidayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.holiday?.name);
  late DateTimeRange? _range = widget.holiday == null
      ? null
      : DateTimeRange(start: widget.holiday!.start, end: widget.holiday!.end);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _range,
      helpText: 'أيام الإجازة',
      saveText: 'تم',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_range == null) {
      showMessage(context, 'اختر أيام الإجازة', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminApiProvider).saveHoliday(widget.holiday?.id, {
        'name': _name.text.trim(),
        'startDate': isoDay(_range!.start),
        'endDate': isoDay(_range!.end),
      });
      ref.invalidate(holidaysProvider);
      if (!mounted) return;
      showMessage(
        context,
        widget.holiday == null ? 'أُضيفت الإجازة' : 'حُفظت الإجازة',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, adminFailure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'حذف ${widget.holiday!.name}؟',
      message: 'تُنشأ الرحلات في أيامها كأيام الدراسة.',
      confirmLabel: 'حذف الإجازة',
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(adminApiProvider).deleteHoliday(widget.holiday!.id);
      ref.invalidate(holidaysProvider);
      if (!mounted) return;
      showMessage(context, 'حُذفت الإجازة');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, adminFailure(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final days = range == null
        ? 0
        : range.end.difference(range.start).inDays + 1;
    return Scaffold(
      appBar: NdsAppBar(
        title: widget.holiday == null ? 'إضافة إجازة' : 'تعديل الإجازة',
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            NdsField(
              label: 'الاسم',
              controller: _name,
              hint: 'مثل: إجازة اليوم الوطني',
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'مطلوب';
                return text.length > 100 ? 'أطول من المسموح' : null;
              },
            ),
            NdsListItem(
              leading: const FeaturedIcon(HugeIcons.strokeRoundedCalendar03),
              title: range == null
                  ? 'اختر أيام الإجازة'
                  : holidayRange(
                      Holiday(
                        id: '',
                        name: '',
                        start: range.start,
                        end: range.end,
                        days: days,
                      ),
                    ),
              meta: 'من أول يوم إلى آخر يوم، شاملة',
              chevron: true,
              onTap: _pickRange,
            ),
            if (days > 120)
              const InlineNote(
                'الإجازة الواحدة 120 يوماً على الأكثر؛ قسّمها إلى إجازتين.',
                icon: HugeIcons.strokeRoundedAlert02,
                color: NdsColors.yellow600,
              ),
          ],
        ),
      ),
      bottomNavigationBar: NdsFooter(
        children: [
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: Text(widget.holiday == null ? 'إضافة الإجازة' : 'حفظ'),
          ),
          if (widget.holiday != null)
            OutlinedButton(
              style: NdsButtons.destructiveOutline,
              onPressed: _busy ? null : _delete,
              child: const Text('حذف الإجازة'),
            ),
        ],
      ),
    );
  }
}
