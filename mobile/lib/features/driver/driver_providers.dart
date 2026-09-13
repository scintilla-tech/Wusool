import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class DriverTripStudent {
  final String studentProfileId;
  final String status;
  final String firstName;
  final String lastName;
  final String? phone;

  const DriverTripStudent({
    required this.studentProfileId,
    required this.status,
    required this.firstName,
    required this.lastName,
    this.phone,
  });
}

class DriverTrip {
  final String? id;
  final String? status;
  final String? routeName;
  final String? busPlate;
  final List<DriverTripStudent> students;

  const DriverTrip({
    this.id,
    this.status,
    this.routeName,
    this.busPlate,
    this.students = const [],
  });

  bool get hasTrip => id != null;
  bool get isScheduled => status == 'SCHEDULED';
  bool get isInProgress => status == 'IN_PROGRESS';

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    final route = json['route'];
    final bus = json['bus'];
    final rawStudents = (json['tripStudents'] as List?) ?? const [];
    return DriverTrip(
      id: json['id'] as String?,
      status: json['status'] as String?,
      routeName: route is Map ? route['name'] as String? : null,
      busPlate: bus is Map ? bus['plateNumber'] as String? : null,
      students: rawStudents.whereType<Map>().map((raw) {
        final profile = raw['studentProfile'];
        final user = profile is Map ? profile['user'] : null;
        return DriverTripStudent(
          studentProfileId: raw['studentProfileId'] as String? ?? '',
          status: raw['status'] as String? ?? 'WAITING',
          firstName: user is Map ? (user['firstName'] as String? ?? '') : '',
          lastName: user is Map ? (user['lastName'] as String? ?? '') : '',
          phone: user is Map ? user['phone'] as String? : null,
        );
      }).toList(),
    );
  }
}

final driverTripProvider = FutureProvider.autoDispose<DriverTrip>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/driver/today');
  final data = res.data?['data'];
  if (data is! Map<String, dynamic>) return const DriverTrip();
  return DriverTrip.fromJson(data);
});
