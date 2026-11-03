/// Arabic labels for API enum values shared across roles.
library;

import 'ui.dart';

String directionLabel(String direction) =>
    direction == 'OUTBOUND' ? 'رحلة الذهاب' : 'رحلة العودة';

String tripStatusLabel(String? status) => switch (status) {
  'SCHEDULED' => 'لم تنطلق',
  'IN_PROGRESS' => 'في الطريق',
  'COMPLETED' => 'مكتملة',
  'CANCELLED' => 'ملغاة',
  _ => 'لا رحلة اليوم',
};

TagStatus tripStatusTag(String? status) => switch (status) {
  'IN_PROGRESS' => TagStatus.info,
  'COMPLETED' => TagStatus.success,
  'CANCELLED' => TagStatus.error,
  _ => TagStatus.neutral,
};

/// HH:MM in the device's local time.
String clockLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Counted Arabic noun with number agreement, e.g. "طالبة واحدة",
/// "طالبتان", "3 طالبات", "11 طالبة".
String countOf(
  int n, {
  required String one,
  required String two,
  required String few,
  required String many,
}) {
  if (n == 1) return one;
  if (n == 2) return two;
  final rest = n % 100;
  return rest >= 3 && rest <= 10 ? '$n $few' : '$n $many';
}

String studentCount(int n) => countOf(
  n,
  one: 'طالبة واحدة',
  two: 'طالبتان',
  few: 'طالبات',
  many: 'طالبة',
);

String busCount(int n) => countOf(
  n,
  one: 'حافلة واحدة',
  two: 'حافلتان',
  few: 'حافلات',
  many: 'حافلة',
);

String seatCount(int n) =>
    countOf(n, one: 'مقعد واحد', two: 'مقعدان', few: 'مقاعد', many: 'مقعداً');

String routeCount(int n) =>
    countOf(n, one: 'مسار واحد', two: 'مساران', few: 'مسارات', many: 'مساراً');

String campusCount(int n) =>
    countOf(n, one: 'مقر واحد', two: 'مقران', few: 'مقرات', many: 'مقراً');

String neighborhoodCount(int n) =>
    countOf(n, one: 'حي واحد', two: 'حيّان', few: 'أحياء', many: 'حياً');

String stopCount(int n) =>
    countOf(n, one: 'محطة واحدة', two: 'محطتان', few: 'محطات', many: 'محطة');

/// +966501234567 as people write it: 0501234567.
String localPhone(String phone) =>
    phone.startsWith('+966') ? '0${phone.substring(4)}' : phone;

/// "طالبتان", or "بلا طالبات" for none.
String studentsOn(int n) => n == 0 ? 'بلا طالبات' : studentCount(n);

/// Arabic-Indic and Persian digits, as Arabic keyboards type them, become 0-9.
String asciiDigits(String value) => value.replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (m) => '${m[0]!.codeUnitAt(0) % 16}',
);

/// "05:30" → "5:30 صباحاً", "13:15" → "1:15 مساءً".
String clockWords(String hhmm) {
  final parts = hhmm.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? parts[1] : '00';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minute ${hour < 12 ? 'صباحاً' : 'مساءً'}';
}
