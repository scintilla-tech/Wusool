import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AttendanceToday {
  final String? intent; // ATTENDING | ABSENT | null
  final DateTime date;

  const AttendanceToday({required this.intent, required this.date});
}

final attendanceTodayProvider = FutureProvider.autoDispose<AttendanceToday>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/attendance/today');
  final data = res.data?['data'];
  final intent = (data is Map) ? data['intent'] as String? : null;
  return AttendanceToday(intent: intent, date: DateTime.now());
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

final studentTripProvider = FutureProvider.autoDispose<StudentTripView>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/students/me/trip');
  final data = res.data?['data'];
  return StudentTripView.fromJson(data is Map<String, dynamic> ? data : const {});
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

final studentProfileProvider = FutureProvider.autoDispose<StudentProfile>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/students/me');
  final data = res.data?['data'];
  return StudentProfile.fromJson(data is Map<String, dynamic> ? data : const {});
});
