import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class SupervisorBusView {
  final String busId;
  final String plateNumber;
  final String? name;
  final String? tripId;
  final String? tripStatus;
  final String? tripDirection;
  final String? routeName;
  final int total;
  final int boarded;
  final int missed;
  final int waiting;
  final int notReady;
  final List<SupervisorAttendanceSession> attendanceSessions;

  /// Who drives today's trip, and whose trip it is when a cover drives it.
  final String? driverName;
  final String? coveredDriverName;

  /// The bus's own driver.
  final String? regularDriverName;

  /// Today's trips not started yet, which a cover driver can take.
  final int coverable;

  /// Who drives each of today's trips, going first.
  final List<TripDriver> drivers;

  /// Days off its driver reported, today onwards.
  final List<BusAbsence> absences;

  /// Reported days with no cover chosen yet.
  int get uncovered => absences.where((a) => a.coverName == null).length;

  const SupervisorBusView({
    required this.busId,
    required this.plateNumber,
    this.name,
    this.tripId,
    this.tripStatus,
    this.tripDirection,
    this.routeName,
    this.total = 0,
    this.boarded = 0,
    this.missed = 0,
    this.waiting = 0,
    this.notReady = 0,
    this.attendanceSessions = const [],
    this.driverName,
    this.coveredDriverName,
    this.regularDriverName,
    this.coverable = 0,
    this.drivers = const [],
    this.absences = const [],
  });

  bool get hasTrip => tripId != null;

  factory SupervisorBusView.fromJson(Map<String, dynamic> json) {
    final bus = json['bus'];
    final trip = json['trip'];
    final counts = json['counts'];
    int c(String key) =>
        (counts is Map ? (counts[key] as num?)?.toInt() : null) ?? 0;
    return SupervisorBusView(
      busId: bus is Map ? bus['id'] as String? ?? '' : '',
      plateNumber: bus is Map ? bus['plateNumber'] as String? ?? '' : '',
      name: bus is Map ? bus['name'] as String? : null,
      tripId: trip is Map ? trip['id'] as String? : null,
      tripStatus: trip is Map ? trip['status'] as String? : null,
      tripDirection: trip is Map ? trip['direction'] as String? : null,
      routeName: trip is Map ? trip['routeName'] as String? : null,
      driverName: trip is Map ? trip['driverName'] as String? : null,
      coveredDriverName: trip is Map
          ? trip['coveredDriverName'] as String?
          : null,
      regularDriverName: json['regularDriverName'] as String?,
      coverable: (json['coverable'] as num?)?.toInt() ?? 0,
      drivers: [
        for (final raw in json['drivers'] as List? ?? const [])
          if (raw is Map) TripDriver.fromJson(raw.cast<String, dynamic>()),
      ],
      absences: [
        for (final raw in json['absences'] as List? ?? const [])
          if (raw is Map) BusAbsence.fromJson(raw.cast<String, dynamic>()),
      ],
      total: c('total'),
      boarded: c('boarded'),
      missed: c('missed'),
      waiting: c('waiting'),
      notReady: c('notReady'),
      attendanceSessions: ((json['attendanceSessions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (value) => SupervisorAttendanceSession.fromJson(
              value.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

/// A day the bus's driver cannot drive.
class BusAbsence {
  final String id;
  final DateTime date;
  final String? note;
  final String driverName;
  final String? coverName;

  const BusAbsence({
    required this.id,
    required this.date,
    this.note,
    required this.driverName,
    this.coverName,
  });

  factory BusAbsence.fromJson(Map<String, dynamic> json) => BusAbsence(
    id: json['id'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
    driverName: json['driverName'] as String? ?? '',
    coverName: json['coverName'] as String?,
  );
}

class TripDriver {
  final String direction;
  final String status;
  final String? driverName;

  /// The bus's own driver, when a cover drives this trip.
  final String? coveredDriverName;

  const TripDriver({
    required this.direction,
    required this.status,
    this.driverName,
    this.coveredDriverName,
  });

  factory TripDriver.fromJson(Map<String, dynamic> json) => TripDriver(
    direction: json['direction'] as String? ?? 'OUTBOUND',
    status: json['status'] as String? ?? 'SCHEDULED',
    driverName: json['driverName'] as String?,
    coveredDriverName: json['coveredDriverName'] as String?,
  );
}

class SupervisorAttendanceSession {
  final String direction;
  final String status;
  final int attending;
  final int absent;
  final int unregistered;

  const SupervisorAttendanceSession({
    required this.direction,
    required this.status,
    required this.attending,
    required this.absent,
    required this.unregistered,
  });

  factory SupervisorAttendanceSession.fromJson(Map<String, dynamic> json) =>
      SupervisorAttendanceSession(
        direction: json['direction'] as String? ?? 'OUTBOUND',
        status: json['status'] as String? ?? 'OPEN',
        attending: (json['attending'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        unregistered: (json['unregistered'] as num?)?.toInt() ?? 0,
      );
}

final supervisorBusesProvider =
    FutureProvider.autoDispose<List<SupervisorBusView>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final res = await api.dio.get<Map<String, dynamic>>('/supervisor/buses');
      final data = res.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => SupervisorBusView.fromJson(e.cast<String, dynamic>()))
          .toList();
    });

/// A driver a supervisor can put on the bus's trips today.
class CoverCandidate {
  final String profileId;
  final String name;
  final String phone;
  final String? busLabel;

  /// Directions in which the driver has another trip today.
  final List<String> busy;

  /// Drives this bus's trips today.
  final bool current;

  /// The bus's own driver.
  final bool regular;

  /// Reported they cannot drive that day.
  final bool absent;

  const CoverCandidate({
    required this.profileId,
    required this.name,
    this.phone = '',
    this.busLabel,
    this.busy = const [],
    this.current = false,
    this.regular = false,
    this.absent = false,
  });

  factory CoverCandidate.fromJson(Map<String, dynamic> m) {
    final bus = m['bus'];
    return CoverCandidate(
      profileId: m['profileId'] as String? ?? '',
      name: '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim(),
      phone: m['phone'] as String? ?? '',
      busLabel: bus is Map
          ? (bus['name'] as String? ?? bus['plateNumber'] as String?)
          : null,
      busy: [for (final d in m['busy'] as List? ?? const []) '$d'],
      current: m['current'] as bool? ?? false,
      regular: m['regular'] as bool? ?? false,
      absent: m['absent'] as bool? ?? false,
    );
  }
}

/// Drivers for a bus on a day ("YYYY-MM-DD"), or today when the day is null.
final coverCandidatesProvider = FutureProvider.autoDispose
    .family<List<CoverCandidate>, ({String busId, String? day})>((
      ref,
      key,
    ) async {
      final api = ref.watch(apiClientProvider);
      final res = await api.dio.get<Map<String, dynamic>>(
        '/supervisor/buses/${key.busId}/drivers',
        queryParameters: {'date': ?key.day},
      );
      return [
        for (final item in res.data?['data']?['items'] as List? ?? const [])
          if (item is Map)
            CoverCandidate.fromJson(item.cast<String, dynamic>()),
      ];
    });
