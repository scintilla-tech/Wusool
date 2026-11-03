import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AdminDashboard {
  final int buses;
  final int routes;
  final int students;
  final int drivers;
  final int supervisors;
  final int fieldSupervisors;
  final int tripsToday;

  const AdminDashboard({
    this.buses = 0,
    this.routes = 0,
    this.students = 0,
    this.drivers = 0,
    this.supervisors = 0,
    this.fieldSupervisors = 0,
    this.tripsToday = 0,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AdminDashboard(
      buses: i('buses'),
      routes: i('routes'),
      students: i('students'),
      drivers: i('drivers'),
      supervisors: i('supervisors'),
      fieldSupervisors: i('fieldSupervisors'),
      tripsToday: i('tripsToday'),
    );
  }
}

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/admin/dashboard');
  final data = res.data?['data'];
  return AdminDashboard.fromJson(
    data is Map<String, dynamic> ? data : const {},
  );
});
