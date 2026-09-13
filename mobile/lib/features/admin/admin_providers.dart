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

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/admin/dashboard');
  final data = res.data?['data'];
  return AdminDashboard.fromJson(data is Map<String, dynamic> ? data : const {});
});

class AdminStudentRow {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? studentId;
  final bool isActive;

  const AdminStudentRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.studentId,
    this.isActive = true,
  });
}

final adminStudentsProvider = FutureProvider.autoDispose<List<AdminStudentRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/students', queryParameters: {'page': 1, 'limit': 50});
  final items = (res.data?['data']?['items'] as List?) ?? const [];
  return items.whereType<Map>().map((raw) {
    final m = raw.cast<String, dynamic>();
    return AdminStudentRow(
      id: m['id'] as String? ?? '',
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      studentId: m['studentId'] as String?,
      isActive: m['isActive'] as bool? ?? true,
    );
  }).toList();
});

class AdminBusRow {
  final String id;
  final String plateNumber;
  final String? name;
  final int? capacity;
  final bool isActive;

  const AdminBusRow({
    required this.id,
    required this.plateNumber,
    this.name,
    this.capacity,
    this.isActive = true,
  });
}

final adminBusesProvider = FutureProvider.autoDispose<List<AdminBusRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/structure/buses', queryParameters: {'page': 1, 'limit': 50});
  final items = (res.data?['data']?['items'] as List?) ?? const [];
  return items.whereType<Map>().map((raw) {
    final m = raw.cast<String, dynamic>();
    return AdminBusRow(
      id: m['id'] as String? ?? '',
      plateNumber: m['plateNumber'] as String? ?? '',
      name: m['name'] as String?,
      capacity: (m['capacity'] as num?)?.toInt(),
      isActive: m['isActive'] as bool? ?? true,
    );
  }).toList();
});
