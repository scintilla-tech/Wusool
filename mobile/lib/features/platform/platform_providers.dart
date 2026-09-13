import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class PlatformTenant {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int users;
  final int buses;

  const PlatformTenant({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = true,
    this.users = 0,
    this.buses = 0,
  });

  factory PlatformTenant.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'];
    int c(String k) => (counts is Map ? (counts[k] as num?)?.toInt() : null) ?? 0;
    return PlatformTenant(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      users: c('users'),
      buses: c('buses'),
    );
  }
}

final platformTenantsProvider = FutureProvider.autoDispose<List<PlatformTenant>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get<Map<String, dynamic>>('/platform/tenants');
  final data = res.data?['data'];
  if (data is! List) return const [];
  return data.whereType<Map>().map((e) => PlatformTenant.fromJson(e.cast<String, dynamic>())).toList();
});
