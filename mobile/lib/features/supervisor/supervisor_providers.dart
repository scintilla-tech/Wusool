import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class SupervisorBusView {
  final String busId;
  final String plateNumber;
  final String? name;
  final String? tripId;
  final String? tripStatus;
  final String? routeName;
  final int total;
  final int boarded;
  final int missed;
  final int waiting;
  final int notReady;
  final List<SupervisorAttendanceSession> attendanceSessions;

  const SupervisorBusView({
    required this.busId,
    required this.plateNumber,
    this.name,
    this.tripId,
    this.tripStatus,
    this.routeName,
    this.total = 0,
    this.boarded = 0,
    this.missed = 0,
    this.waiting = 0,
    this.notReady = 0,
    this.attendanceSessions = const [],
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
      routeName: trip is Map ? trip['routeName'] as String? : null,
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
