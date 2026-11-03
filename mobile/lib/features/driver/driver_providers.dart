import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../admin/admin_api.dart' show Neighborhood;

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

  /// The bus's own driver, when this driver covers the trip for them.
  final String? coveringFor;

  const DriverTrip({
    this.id,
    this.status,
    this.routeName,
    this.busPlate,
    this.coveringFor,
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
    final covered = json['coveredDriverProfile'];
    final coveredUser = covered is Map ? covered['user'] : null;
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
      coveringFor: coveredUser is Map
          ? '${coveredUser['firstName'] ?? ''} ${coveredUser['lastName'] ?? ''}'
                .trim()
          : null,
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

class DriverRoute {
  final String id;
  final String name;
  final String? code;

  /// The campus the route goes to.
  final String? campusId;
  final String? campusName;

  /// In visiting order.
  final List<Neighborhood> stops;

  const DriverRoute(
    this.id,
    this.name, {
    this.code,
    this.campusId,
    this.campusName,
    this.stops = const [],
  });

  /// "النرجس ← الملقا"; each name isolated so mixed scripts keep their order.
  String get stopsLine =>
      stops.map((stop) => '\u2068${stop.name}\u2069').join(' ← ');

  static DriverRoute? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final campus = raw['branch'];
    return DriverRoute(
      raw['id'] as String,
      raw['name'] as String? ?? '',
      code: raw['code'] as String?,
      campusId: campus is Map ? campus['id'] as String? : null,
      campusName: campus is Map ? campus['name'] as String? : null,
      stops: [
        for (final stop in raw['stops'] as List? ?? const [])
          if (stop is Map) Neighborhood.fromJson(stop.cast<String, dynamic>()),
      ],
    );
  }
}

/// The driver's bus, its fixed route, and how trips are made for it.
class DriverBus {
  final String? busId;
  final String? plateNumber;
  final String? busName;

  /// The route the bus runs every school day, once built.
  final DriverRoute? route;

  /// Directions that already have a trip today.
  final Set<String> todayDirections;

  /// Trips are made automatically at [autoTripTime] ("05:30") unless paused.
  final bool autoTrips;
  final String autoTripTime;

  /// Today's holiday, when it is one.
  final String? holiday;

  const DriverBus({
    this.busId,
    this.plateNumber,
    this.busName,
    this.route,
    this.todayDirections = const {},
    this.autoTrips = true,
    this.autoTripTime = '05:30',
    this.holiday,
  });

  bool get hasBus => busId != null;

  String get busLabel => busName ?? plateNumber ?? '';

  /// Going or return trips not made yet today.
  List<String> get missing => [
    for (final direction in const ['OUTBOUND', 'RETURN'])
      if (!todayDirections.contains(direction)) direction,
  ];

  factory DriverBus.fromJson(Map<String, dynamic> json) {
    final bus = json['bus'];
    return DriverBus(
      busId: bus is Map ? bus['id'] as String? : null,
      plateNumber: bus is Map ? bus['plateNumber'] as String? : null,
      busName: bus is Map ? bus['name'] as String? : null,
      route: DriverRoute.fromJson(json['route']),
      todayDirections: {
        for (final trip in json['today'] as List? ?? const [])
          if (trip is Map && trip['direction'] is String)
            trip['direction'] as String,
      },
      autoTrips: json['autoTrips'] as bool? ?? true,
      autoTripTime: json['autoTripTime'] as String? ?? '05:30',
      holiday: json['holiday'] as String?,
    );
  }
}

final driverBusProvider = FutureProvider.autoDispose<DriverBus>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/driver/bus');
  final data = res.data?['data'];
  return DriverBus.fromJson(data is Map<String, dynamic> ? data : const {});
});

/// A day the driver told the supervisor they cannot drive.
class DriverAbsence {
  final String id;
  final DateTime date;
  final String? note;

  /// Who drives instead, once the supervisor picks them.
  final String? coverName;

  const DriverAbsence({
    required this.id,
    required this.date,
    this.note,
    this.coverName,
  });

  factory DriverAbsence.fromJson(Map<String, dynamic> json) => DriverAbsence(
    id: json['id'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
    coverName: json['coverName'] as String?,
  );
}

final driverAbsencesProvider = FutureProvider.autoDispose<List<DriverAbsence>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/driver/absences');
  return [
    for (final item in res.data?['data']?['items'] as List? ?? const [])
      if (item is Map) DriverAbsence.fromJson(item.cast<String, dynamic>()),
  ];
});

/// "اليوم", "غداً" or "الثلاثاء 4 نوفمبر" for a calendar day.
String dayLabel(DateTime day, {DateTime? now}) {
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const months = [
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
  final today = now ?? DateTime.now();
  final a = DateTime.utc(day.year, day.month, day.day);
  final b = DateTime.utc(today.year, today.month, today.day);
  final days = a.difference(b).inDays;
  if (days == 0) return 'اليوم';
  if (days == 1) return 'غداً';
  return '${weekdays[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}

/// YYYY-MM-DD, as the API takes days.
String isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
