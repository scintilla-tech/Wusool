import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../core/theme.dart';
import 'student_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _saving = false;

  Future<void> _setIntent(
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث التحضير. قد تكون الجلسة مغلقة.'),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceTodayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الحضور')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('تعذر تحميل الحضور\n$error')),
        data: (attendance) => RefreshIndicator(
          onRefresh: () async => ref.refresh(attendanceTodayProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: attendance.sessions
                .map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AttendanceCard(
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
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceSessionView session;
  final bool disabled;
  final ValueChanged<String> onIntent;
  final VoidCallback onPickFinish;
  final VoidCallback onClearFinish;

  const _AttendanceCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  outbound ? Icons.wb_sunny_outlined : Icons.home_outlined,
                  color: WaslColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    outbound ? 'تحضير الذهاب' : 'تحضير العودة',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StateChip(
                  open: session.isOpen,
                  closed: session.status == 'CLOSED',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatArabicDate(session.operationalDate)} • يفتح ${_timeLabel(session.opensAt)}',
              style: const TextStyle(color: WaslColors.textSecondary),
            ),
            if (session.status == 'CLOSED') ...[
              const SizedBox(height: 12),
              const Text(
                'أغلق السائق التحضير لهذه الرحلة، ولا يمكن إجراء تعديلات إضافية.',
                style: TextStyle(
                  color: WaslColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _IntentButton(
                    label: 'حاضرة',
                    icon: Icons.check_circle,
                    color: WaslColors.success,
                    selected: session.intent == 'ATTENDING',
                    onPressed: canEdit ? () => onIntent('ATTENDING') : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _IntentButton(
                    label: 'غائبة',
                    icon: Icons.cancel,
                    color: WaslColors.danger,
                    selected: session.intent == 'ABSENT',
                    onPressed: canEdit ? () => onIntent('ABSENT') : null,
                  ),
                ),
              ],
            ),
            if (outbound) ...[
              const Divider(height: 28),
              const Text('متى تتوقعين انتهاء دوامك اليوم؟'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canEdit && session.intent != null
                          ? onPickFinish
                          : null,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        session.expectedFinishTime ?? 'اختياري — اختاري الوقت',
                      ),
                    ),
                  ),
                  if (session.expectedFinishTime != null)
                    IconButton(
                      tooltip: 'مسح الوقت',
                      onPressed: canEdit && session.intent != null
                          ? onClearFinish
                          : null,
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              const Text(
                'هذا الوقت تقديري فقط ولا يسجّل تحضير العودة تلقائياً.',
                style: TextStyle(fontSize: 12, color: WaslColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StateChip extends StatelessWidget {
  final bool open;
  final bool closed;
  const _StateChip({required this.open, required this.closed});

  @override
  Widget build(BuildContext context) {
    final color = open ? WaslColors.success : WaslColors.textSecondary;
    final label = closed ? 'مغلق' : (open ? 'مفتوح' : 'لم يفتح');
    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
    );
  }
}

class _IntentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;
  const _IntentButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: selected ? color.withValues(alpha: 0.1) : null,
      side: BorderSide(
        color: selected ? color : const Color(0xFFD7DEE6),
        width: selected ? 2 : 1,
      ),
    ),
  );
}
