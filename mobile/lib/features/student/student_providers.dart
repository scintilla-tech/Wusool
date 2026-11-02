import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AttendanceSessionView {
  final String id;
  final String direction;
  final String status;
  final String? intent;
  final String? expectedFinishTime;
  final DateTime operationalDate;
  final DateTime opensAt;
  final bool isOpen;

  const AttendanceSessionView({
    required this.id,
    required this.direction,
    required this.status,
    required this.operationalDate,
    required this.opensAt,
    required this.isOpen,
    this.intent,
    this.expectedFinishTime,
  });

  factory AttendanceSessionView.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionView(
        id: json['id'] as String? ?? '',
        direction: json['direction'] as String? ?? 'OUTBOUND',
        status: json['status'] as String? ?? 'OPEN',
        operationalDate: DateTime.parse(json['operationalDate'] as String),
        opensAt: DateTime.parse(json['opensAt'] as String),
        isOpen: json['isOpen'] as bool? ?? false,
        intent: json['intent'] as String?,
        expectedFinishTime: json['expectedFinishTime'] as String?,
      );
}

class AttendanceToday {
  final List<AttendanceSessionView> sessions;
  const AttendanceToday({required this.sessions});

  AttendanceSessionView byDirection(String direction) =>
      sessions.firstWhere((session) => session.direction == direction);
}

final attendanceTodayProvider = FutureProvider.autoDispose<AttendanceToday>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/attendance/today');
  final data = res.data?['data'];
  final raw = data is Map ? data['sessions'] : null;
  final sessions = raw is List
      ? raw
            .whereType<Map>()
            .map(
              (item) =>
                  AttendanceSessionView.fromJson(item.cast<String, dynamic>()),
            )
            .toList()
      : <AttendanceSessionView>[];
  return AttendanceToday(sessions: sessions);
});

class StudentTripView {
  final String? tripId;
  final String? status;
  final String? routeName;
  final String? busPlate;
  final String? myStatus;
  final double? latitude;
  final double? longitude;
  final int? updatedAt;

  const StudentTripView({
    this.tripId,
    this.status,
    this.routeName,
    this.busPlate,
    this.myStatus,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  bool get hasActiveTrip => tripId != null;
  bool get isInProgress => status == 'IN_PROGRESS';

  factory StudentTripView.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'];
    final loc = json['latestLocation'];
    return StudentTripView(
      tripId: trip is Map ? trip['id'] as String? : null,
      status: trip is Map ? trip['status'] as String? : null,
      routeName: trip is Map ? trip['routeName'] as String? : null,
      busPlate: trip is Map ? trip['busPlate'] as String? : null,
      myStatus: json['myStatus'] as String?,
      latitude: loc is Map ? (loc['latitude'] as num?)?.toDouble() : null,
      longitude: loc is Map ? (loc['longitude'] as num?)?.toDouble() : null,
      updatedAt: loc is Map ? loc['at'] as int? : null,
    );
  }
}

final studentTripProvider = FutureProvider.autoDispose<StudentTripView>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/students/me/trip');
  final data = res.data?['data'];
  return StudentTripView.fromJson(
    data is Map<String, dynamic> ? data : const {},
  );
});

class StudentProfile {
  final String firstName;
  final String lastName;
  final String? email;
  final String phone;
  final String? studentId;
  final double? homeLatitude;
  final double? homeLongitude;

  const StudentProfile({
    required this.firstName,
    required this.lastName,
    this.email,
    required this.phone,
    this.studentId,
    this.homeLatitude,
    this.homeLongitude,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      studentId: json['studentId'] as String?,
      homeLatitude: (json['homeLatitude'] as num?)?.toDouble(),
      homeLongitude: (json['homeLongitude'] as num?)?.toDouble(),
    );
  }
}

final studentProfileProvider = FutureProvider.autoDispose<StudentProfile>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/students/me');
  final data = res.data?['data'];
  return StudentProfile.fromJson(
    data is Map<String, dynamic> ? data : const {},
  );
});

/// The student's own boarding status on today's trip.
String boardingStatusLabel(String? status) => switch (status) {
  'WAITING' => 'بانتظار صعودك',
  'BOARDED' => 'صعدتِ الحافلة',
  'NOT_READY' => 'سُجّلتِ غير جاهزة',
  'MISSED' => 'فاتتكِ الحافلة',
  _ => 'لم تُسجَّل بعد',
};
