import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/ui.dart';
import 'driver_home_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_providers.dart';

/// Trip actions the driver screens call. The driver shell implements them
/// because it also owns location sharing, which must outlive pushed screens.
abstract interface class DriverActions {
  Future<bool> startTrip(DriverTrip trip);
  Future<void> setAttendance(
    DriverTrip trip,
    DriverTripStudent student,
    String intent,
  );
  Future<void> closeAttendance(BuildContext context, DriverTrip trip);
  Future<void> markTransport(
    DriverTrip trip,
    DriverTripStudent student,
    String status,
  );
  Future<bool> completeTrip(DriverTrip trip);
}

class DriverScreen extends ConsumerStatefulWidget {
  const DriverScreen({super.key});

  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen>
    implements DriverActions {
  final _socket = SocketService();
  Timer? _locationTimer;
  bool _sharingLocation = false;
  int _index = 0;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  void _refresh() => ref.invalidate(driverTripsProvider);

  @override
  Future<bool> startTrip(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/start');
      _beginLocationSharing();
      _refresh();
      return true;
    } catch (_) {
      _snack('تعذر بدء الرحلة. تأكد من عدم وجود رحلة أخرى جارية.');
      return false;
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
      final locationSettings =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 20),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      _socket.publishLocation(position.latitude, position.longitude);
    } catch (_) {
      // A missed device location sample is retried on the next bounded interval.
    }
  }

  @override
  Future<void> setAttendance(
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

  @override
  Future<void> closeAttendance(BuildContext context, DriverTrip trip) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'تأكيد اكتمال التحضير',
      message:
          'حاضرات: ${trip.attending} · غائبات: ${trip.absent} · لم يسجلن: ${trip.unregistered}\n'
          'بعد التأكيد يُغلق التسجيل الذاتي للطالبات، ولا يمكن تعديل التحضير لهذه الرحلة.',
      confirmLabel: 'تأكيد الإغلاق',
      icon: HugeIcons.strokeRoundedTickDouble02,
      tone: Tone.primary,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/driver/${trip.id}/attendance/close', data: {'confirm': true});
      _snack('أُغلق التحضير دون إنهاء الرحلة');
      _refresh();
    } catch (_) {
      _snack('تعذر إغلاق التحضير أو أنه مغلق مسبقاً');
    }
  }

  @override
  Future<void> markTransport(
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

  @override
  Future<bool> completeTrip(DriverTrip trip) async {
    try {
      await ref.read(apiClientProvider).dio.post('/driver/${trip.id}/complete');
      _stopLocationSharing();
      _refresh();
      return true;
    } catch (_) {
      _snack('تعذر إنهاء الرحلة');
      return false;
    }
  }

  void _snack(String message) {
    if (mounted) showMessage(context, message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(driverTripsProvider).value ?? const [];
    if (trips.any((trip) => trip.isInProgress) && !_sharingLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beginLocationSharing();
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DriverHomeScreen(actions: this),
          const DriverProfileScreen(),
        ],
      ),
      bottomNavigationBar: NdsTabBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          NdsTabItem(HugeIcons.strokeRoundedHome01, 'الرئيسية'),
          NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'ملفي'),
        ],
      ),
    );
  }
}
