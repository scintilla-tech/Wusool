import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'driver_providers.dart';

class DriverScreen extends ConsumerStatefulWidget {
  const DriverScreen({super.key});

  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen> {
  final _socket = SocketService();
  Timer? _locationTimer;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  Future<void> _startTrip(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/start');
      _beginLocationSharing();
      ref.invalidate(driverTripProvider);
    } catch (_) {
      _snack('تعذر بدء الرحلة');
    }
  }

  void _beginLocationSharing() {
    final config = ref.read(configProvider);
    final token = ref.read(tokenStoreProvider).accessToken;
    if (token == null) return;
    _socket.connect(config.socketUrl, token);
    _publishOnce();
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (_) => _publishOnce());
  }

  Future<void> _publishOnce() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _socket.publishLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // location unavailable — skip this cycle
    }
  }

  Future<void> _mark(DriverTrip trip, String studentProfileId, String status) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch('/driver/${trip.id}/students/$studentProfileId', data: {'status': status});
      ref.invalidate(driverTripProvider);
    } catch (_) {
      _snack('تعذر تحديث حالة الطالبة');
    }
  }

  Future<void> _complete(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/complete');
      _locationTimer?.cancel();
      _socket.disconnect();
      ref.invalidate(driverTripProvider);
    } catch (_) {
      _snack('تعذر إنهاء الرحلة');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driverTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الرحلة\n$e', textAlign: TextAlign.center)),
        data: (trip) {
          if (!trip.hasTrip) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد رحلة مجدولة اليوم', style: TextStyle(fontSize: 18)),
              ),
            );
          }
          return Column(
            children: [
              _TripHeader(trip: trip),
              Expanded(
                child: trip.isScheduled
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _startTrip(trip),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('بدء الرحلة'),
                        ),
                      )
                    : _StudentList(trip: trip, onMark: (id, status) => _mark(trip, id, status)),
              ),
              if (trip.isInProgress)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _complete(trip),
                      style: OutlinedButton.styleFrom(foregroundColor: WaslColors.danger),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('إنهاء الرحلة'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  final DriverTrip trip;
  const _TripHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: WaslColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.routeName ?? 'الرحلة',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'الحافلة: ${trip.busPlate ?? '-'} • الحالة: ${_statusLabel(trip.status)}',
            style: const TextStyle(color: WaslColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final DriverTrip trip;
  final void Function(String studentProfileId, String status) onMark;

  const _StudentList({required this.trip, required this.onMark});

  @override
  Widget build(BuildContext context) {
    if (trip.students.isEmpty) {
      return const Center(child: Text('لا توجد طالبات مسجلات الحضور'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: trip.students.length,
      itemBuilder: (context, i) {
        final s = trip.students[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.firstName} ${s.lastName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    _StatusChip(status: s.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ActionButton(
                      label: 'صعدت',
                      color: WaslColors.success,
                      onTap: () => onMark(s.studentProfileId, 'BOARDED'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'غير جاهزة',
                      color: WaslColors.warning,
                      onTap: () => onMark(s.studentProfileId, 'NOT_READY'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'لم تحضر',
                      color: WaslColors.danger,
                      onTap: () => onMark(s.studentProfileId, 'MISSED'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: color),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'BOARDED' => WaslColors.success,
      'NOT_READY' => WaslColors.warning,
      'MISSED' => WaslColors.danger,
      _ => WaslColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

String _statusLabel(String? status) {
  return switch (status) {
    'SCHEDULED' => 'مجدولة',
    'IN_PROGRESS' => 'جارية',
    'COMPLETED' => 'مكتملة',
    'WAITING' => 'بالانتظار',
    'BOARDED' => 'صعدت',
    'NOT_READY' => 'غير جاهزة',
    'MISSED' => 'لم تحضر',
    _ => status ?? '-',
  };
}
