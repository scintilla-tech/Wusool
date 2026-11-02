import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class DriverTripStudent {
  final String studentProfileId;
  final String status;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? attendanceIntent;
  final String? attendanceSource;
  final String? expectedFinishTime;

  const DriverTripStudent({
    required this.studentProfileId,
    required this.status,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.attendanceIntent,
    this.attendanceSource,
    this.expectedFinishTime,
  });
}

class DriverTrip {
  final String? id;
  final String? status;
  final String? routeName;
  final String? busPlate;
  final String direction;
  final String attendanceStatus;
  final List<DriverTripStudent> students;

  const DriverTrip({
    this.id,
    this.status,
    this.routeName,
    this.busPlate,
    this.direction = 'OUTBOUND',
    this.attendanceStatus = 'OPEN',
    this.students = const [],
  });

  bool get hasTrip => id != null;
  bool get isScheduled => status == 'SCHEDULED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get attendanceClosed => attendanceStatus == 'CLOSED';
  int get attending => students
      .where((student) => student.attendanceIntent == 'ATTENDING')
      .length;
  int get absent =>
      students.where((student) => student.attendanceIntent == 'ABSENT').length;
  int get unregistered => students.length - attending - absent;
  bool get isCompleted => status == 'COMPLETED';
  int get boarded => _withStatus('BOARDED');
  int get notReady => _withStatus('NOT_READY');
  int get missed => _withStatus('MISSED');

  /// Students expected on the bus: everyone not marked absent.
  int get expected => students.length - absent;

  int _withStatus(String value) =>
      students.where((student) => student.status == value).length;

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    final route = json['route'];
    final bus = json['bus'];
    final rawStudents = (json['tripStudents'] as List?) ?? const [];
    final session = json['attendanceSession'];
    final rawIntents = session is Map
        ? (session['attendanceIntents'] as List? ?? const [])
        : const [];
    final intents = <String, Map>{
      for (final value in rawIntents.whereType<Map>())
        if (value['studentProfileId'] is String)
          value['studentProfileId'] as String: value,
    };
    return DriverTrip(
      id: json['id'] as String?,
      status: json['status'] as String?,
      routeName: route is Map ? route['name'] as String? : null,
      busPlate: bus is Map ? bus['plateNumber'] as String? : null,
      direction: json['direction'] as String? ?? 'OUTBOUND',
      attendanceStatus: session is Map
          ? session['status'] as String? ?? 'OPEN'
          : 'OPEN',
      students: rawStudents.whereType<Map>().map((raw) {
        final profile = raw['studentProfile'];
        final user = profile is Map ? profile['user'] : null;
        final attendance = intents[raw['studentProfileId']];
        final finishMinutes = (attendance?['expectedFinishMinutes'] as num?)
            ?.toInt();
        return DriverTripStudent(
          studentProfileId: raw['studentProfileId'] as String? ?? '',
          status: raw['status'] as String? ?? 'WAITING',
          firstName: user is Map ? (user['firstName'] as String? ?? '') : '',
          lastName: user is Map ? (user['lastName'] as String? ?? '') : '',
          phone: user is Map ? user['phone'] as String? : null,
          attendanceIntent: attendance?['intent'] as String?,
          attendanceSource: attendance?['source'] as String?,
          expectedFinishTime: finishMinutes == null
              ? null
              : '${(finishMinutes ~/ 60).toString().padLeft(2, '0')}:${(finishMinutes % 60).toString().padLeft(2, '0')}',
        );
      }).toList(),
    );
  }
}

final driverTripsProvider = FutureProvider.autoDispose<List<DriverTrip>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/driver/today/trips');
  final data = res.data?['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => DriverTrip.fromJson(item.cast<String, dynamic>()))
      .toList();
});

final driverTripProvider = FutureProvider.autoDispose<DriverTrip>((ref) async {
  final trips = await ref.watch(driverTripsProvider.future);
  return trips.isEmpty ? const DriverTrip() : trips.first;
});
