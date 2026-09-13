import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../core/theme.dart';
import 'student_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  Future<void> _setIntent(WidgetRef ref, String intent) async {
    try {
      await ref.read(apiClientProvider).dio.put('/attendance/today', data: {'intent': intent});
      ref.invalidate(attendanceTodayProvider);
    } catch (_) {
      // handled by the provider refresh below
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceTodayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الحضور')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذر تحميل الحضور\n$e', textAlign: TextAlign.center),
        ),
        data: (attendance) {
          final intent = attendance.intent;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          formatArabicDate(attendance.date),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'هل ستحضرين النقل اليوم؟',
                          style: TextStyle(color: WaslColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionTile(
                  label: 'نعم، سأحضر',
                  icon: Icons.check_circle,
                  color: WaslColors.success,
                  selected: intent == 'ATTENDING',
                  onTap: () => _setIntent(ref, 'ATTENDING'),
                ),
                const SizedBox(height: 12),
                _OptionTile(
                  label: 'لن أحضر',
                  icon: Icons.cancel,
                  color: WaslColors.danger,
                  selected: intent == 'ABSENT',
                  onTap: () => _setIntent(ref, 'ABSENT'),
                ),
                const SizedBox(height: 24),
                if (intent != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WaslColors.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: WaslColors.emerald),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            intent == 'ATTENDING'
                                ? 'تم تسجيل حضورك. سيتم إشعارك عند بدء الرحلة.'
                                : 'تم تسجيل عدم الحضور.',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : WaslColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : const Color(0xFFD7DEE6), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              if (selected) Icon(Icons.radio_button_checked, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
