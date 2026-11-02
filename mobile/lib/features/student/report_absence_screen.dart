import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'student_providers.dart';

/// Marks one or both of today's trips as absent.
class ReportAbsenceScreen extends ConsumerStatefulWidget {
  final List<AttendanceSessionView> sessions;
  final StudentTripView? trip;

  const ReportAbsenceScreen({super.key, required this.sessions, this.trip});

  @override
  ConsumerState<ReportAbsenceScreen> createState() =>
      _ReportAbsenceScreenState();
}

class _ReportAbsenceScreenState extends ConsumerState<ReportAbsenceScreen> {
  static const _both = 'BOTH';

  late final List<AttendanceSessionView> _open = widget.sessions
      .where((session) => session.isOpen)
      .toList();
  late String? _choice = _open.isEmpty ? null : _open.first.direction;
  bool _saving = false;

  List<(String, String)> get _options => [
    for (final session in _open)
      (session.direction, directionLabel(session.direction)),
    if (_open.length > 1) (_both, 'الرحلتان'),
  ];

  Future<void> _submit() async {
    final chosen = _choice == _both
        ? _open
        : _open.where((session) => session.direction == _choice);
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider).dio;
      for (final session in chosen) {
        await dio.put(
          '/attendance/today/${session.direction}',
          data: {'intent': 'ABSENT'},
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(
          context,
          'تعذر إرسال البلاغ. قد يكون التحضير مغلقاً.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      appBar: NdsAppBar(
        title: 'لن أحضر اليوم',
        subtitle: formatArabicDate(DateTime.now()),
      ),
      body: PageBody(
        gap: Space.x2l,
        children: [
          if (trip != null && trip.hasActiveTrip)
            NdsListItem(
              leading: const FeaturedIcon(HugeIcons.strokeRoundedBus01),
              title: trip.busPlate == null ? 'حافلتكِ' : ltr(trip.busPlate!),
              meta: trip.routeName,
            ),
          if (_options.isEmpty)
            const InlineNote('لا يوجد تحضير مفتوح الآن.')
          else
            NdsGroup(
              children: [
                Text(
                  'أي رحلة لن تحضريها؟',
                  style: NdsText.textSm.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Nds.textDefault,
                  ),
                ),
                RadioGroup<String>(
                  groupValue: _choice,
                  onChanged: (value) {
                    if (!_saving) setState(() => _choice = value);
                  },
                  child: Column(
                    children: [
                      for (final (value, label) in _options)
                        RadioListTile<String>(
                          value: value,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Nds.backgroundPrimary,
                          title: Text(
                            label,
                            style: NdsText.textMd.copyWith(
                              color: Nds.textDefault,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          const InlineNote(
            'يظهر البلاغ للسائق ومشرف الحافلة، ويمكنكِ إلغاؤه ما دام التحضير مفتوحاً.',
          ),
        ],
      ),
      bottomNavigationBar: NdsFooter(
        children: [
          ElevatedButton(
            onPressed: _choice == null || _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تأكيد عدم الحضور'),
          ),
        ],
      ),
    );
  }
}
