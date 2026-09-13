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
  });

  bool get hasTrip => tripId != null;

  factory SupervisorBusView.fromJson(Map<String, dynamic> json) {
    final bus = json['bus'];
    final trip = json['trip'];
    final counts = json['counts'];
    int c(String key) => (counts is Map ? (counts[key] as num?)?.toInt() : null) ?? 0;
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
    );
  }
}

final supervisorBusesProvider = FutureProvider.autoDispose<List<SupervisorBusView>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/supervisor/buses');
  final data = res.data?['data'];
  if (data is! List) return const [];
  return data.whereType<Map>().map((e) => SupervisorBusView.fromJson(e.cast<String, dynamic>())).toList();
});
