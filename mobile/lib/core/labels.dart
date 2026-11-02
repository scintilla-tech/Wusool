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
