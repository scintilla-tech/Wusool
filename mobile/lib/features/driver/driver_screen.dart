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
  bool _sharingLocation = false;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  void _refresh() => ref.invalidate(driverTripsProvider);

  Future<void> _startTrip(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/start');
      _beginLocationSharing();
      _refresh();
    } catch (_) {
      _snack('تعذر بدء الرحلة. تأكدي من عدم وجود رحلة أخرى جارية.');
    }
  }

  void _beginLocationSharing() {
    if (_sharingLocation) return;
    final config = ref.read(configProvider);
    final token = ref.read(tokenStoreProvider).accessToken;
    if (token == null) return;
    _sharingLocation = true;
    _socket.connect(
      config.socketUrl,
      token,
      onTripCompleted: _stopLocationSharing,
      onAttendanceChanged: (_) => _refresh(),
      onAttendanceClosed: (_) => _refresh(),
    );
    _publishOnce();
    _locationTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _publishOnce(),
    );
  }

  void _stopLocationSharing() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _socket.disconnect();
    _sharingLocation = false;
    if (mounted) _refresh();
  }

  Future<void> _publishOnce() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _socket.publishLocation(position.latitude, position.longitude);
    } catch (_) {
      // A missed device location sample is retried on the next bounded interval.
    }
  }

  Future<void> _setAttendance(
    DriverTrip trip,
    DriverTripStudent student,
    String intent,
  ) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put(
            '/driver/${trip.id}/attendance/${student.studentProfileId}',
            data: {'intent': intent},
          );
      _refresh();
    } catch (_) {
      _snack('تعذر تحديث التحضير. قد تكون الجلسة مغلقة.');
    }
  }

  Future<void> _closeAttendance(DriverTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد اكتمال التحضير'),
        content: Text(
          'حاضرات: ${trip.attending}\nغائبات: ${trip.absent}\nغير مسجلات: ${trip.unregistered}\n\n'
          'بعد التأكيد سيُغلق التسجيل الذاتي للطالبات، ولن يمكن تعديل التحضير لهذه الرحلة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/driver/${trip.id}/attendance/close', data: {'confirm': true});
      _snack('تم إغلاق التحضير دون إنهاء الرحلة');
      _refresh();
    } catch (_) {
      _snack('تعذر إغلاق التحضير أو أنه مغلق مسبقاً');
    }
  }

  Future<void> _markTransport(
    DriverTrip trip,
    DriverTripStudent student,
    String status,
  ) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch(
            '/driver/${trip.id}/students/${student.studentProfileId}',
            data: {'status': status},
          );
      _refresh();
    } catch (_) {
      _snack('تعذر تحديث حالة صعود الطالبة');
    }
  }

  Future<void> _complete(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/complete');
      _stopLocationSharing();
      _refresh();
    } catch (_) {
      _snack('تعذر إنهاء الرحلة');
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driverTripsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي اليوم'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('تعذر تحميل الرحلات\n$error')),
        data: (trips) {
          if (trips.any((trip) => trip.isInProgress) && !_sharingLocation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _beginLocationSharing();
            });
          }
          if (trips.isEmpty) {
            return const Center(child: Text('لا توجد رحلات مجدولة اليوم'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(driverTripsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: trips
                  .map(
                    (trip) => _TripCard(
                      trip: trip,
                      onStart: () => _startTrip(trip),
                      onCloseAttendance: () => _closeAttendance(trip),
                      onAttendance: (student, intent) =>
                          _setAttendance(trip, student, intent),
                      onTransport: (student, status) =>
                          _markTransport(trip, student, status),
                      onComplete: () => _complete(trip),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final DriverTrip trip;
  final VoidCallback onStart;
  final VoidCallback onCloseAttendance;
  final void Function(DriverTripStudent, String) onAttendance;
  final void Function(DriverTripStudent, String) onTransport;
  final VoidCallback onComplete;

  const _TripCard({
    required this.trip,
    required this.onStart,
    required this.onCloseAttendance,
    required this.onAttendance,
    required this.onTransport,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: ExpansionTile(
      initiallyExpanded: trip.direction == 'OUTBOUND',
      title: Text(
        trip.direction == 'OUTBOUND' ? 'رحلة الذهاب' : 'رحلة العودة',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${trip.routeName ?? '-'} • ${trip.busPlate ?? '-'} • ${_statusLabel(trip.status)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      children: [
        _AttendanceSummary(trip: trip),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: trip.attendanceClosed ? null : onCloseAttendance,
            icon: Icon(trip.attendanceClosed ? Icons.lock : Icons.fact_check),
            label: Text(
              trip.attendanceClosed ? 'التحضير مغلق' : 'اكتمال التحضير',
            ),
          ),
        ),
        const Divider(height: 24),
        ...trip.students.map(
          (student) => _StudentAttendanceTile(
            student: student,
            attendanceClosed: trip.attendanceClosed,
            tripInProgress: trip.isInProgress,
            onAttendance: (intent) => onAttendance(student, intent),
            onTransport: (status) => onTransport(student, status),
          ),
        ),
        if (trip.isScheduled)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('بدء الرحلة'),
            ),
          ),
        if (trip.isInProgress)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onComplete,
              style: OutlinedButton.styleFrom(
                foregroundColor: WaslColors.danger,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('إنهاء الرحلة'),
            ),
          ),
      ],
    ),
  );
}

class _AttendanceSummary extends StatelessWidget {
  final DriverTrip trip;
  const _AttendanceSummary({required this.trip});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: WaslColors.navy.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _Count(
          label: 'حاضرات',
          value: trip.attending,
          color: WaslColors.success,
        ),
        _Count(label: 'غائبات', value: trip.absent, color: WaslColors.danger),
        _Count(
          label: 'غير مسجلات',
          value: trip.unregistered,
          color: WaslColors.warning,
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Count({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _StudentAttendanceTile extends StatelessWidget {
  final DriverTripStudent student;
  final bool attendanceClosed;
  final bool tripInProgress;
  final ValueChanged<String> onAttendance;
  final ValueChanged<String> onTransport;
  const _StudentAttendanceTile({
    required this.student,
    required this.attendanceClosed,
    required this.tripInProgress,
    required this.onAttendance,
    required this.onTransport,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${student.firstName} ${student.lastName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (student.expectedFinishTime != null)
            Text('انتهاء متوقع: ${student.expectedFinishTime}'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: attendanceClosed
                      ? null
                      : () => onAttendance('ATTENDING'),
                  child: Text(
                    student.attendanceIntent == 'ATTENDING'
                        ? '✓ حاضرة'
                        : 'حاضرة',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: attendanceClosed
                      ? null
                      : () => onAttendance('ABSENT'),
                  child: Text(
                    student.attendanceIntent == 'ABSENT' ? '✓ غائبة' : 'غائبة',
                  ),
                ),
              ),
            ],
          ),
          if (tripInProgress)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => onTransport('BOARDED'),
                    child: const Text('صعدت'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => onTransport('NOT_READY'),
                    child: const Text('غير جاهزة'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => onTransport('MISSED'),
                    child: const Text('لم تحضر'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

String _statusLabel(String? status) => switch (status) {
  'SCHEDULED' => 'مجدولة',
  'IN_PROGRESS' => 'جارية',
  'COMPLETED' => 'مكتملة',
  _ => status ?? '-',
};
