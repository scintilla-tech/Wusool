import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import 'student_providers.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentTripProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('التتبع')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'تعذر تحميل حالة الرحلة\n$e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (trip) {
          if (!trip.hasActiveTrip) {
            return const _WaitingState(
              icon: Icons.schedule,
              title: 'لا توجد رحلة اليوم',
              subtitle: 'سيظهر التتبع هنا عند بدء رحلة الصباح.',
            );
          }
          if (!trip.isInProgress) {
            return const _WaitingState(
              icon: Icons.hourglass_top,
              title: 'في انتظار بدء الرحلة',
              subtitle: 'سيتم إشعارك عند انطلاق الحافلة.',
            );
          }
          return _TrackingView(trip: trip);
        },
      ),
    );
  }
}

class _WaitingState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WaitingState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: WaslColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WaslColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingView extends ConsumerStatefulWidget {
  final StudentTripView trip;

  const _TrackingView({required this.trip});

  @override
  ConsumerState<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<_TrackingView> {
  final _socket = SocketService();
  double? _latitude;
  double? _longitude;
  int? _updatedAt;

  @override
  void initState() {
    super.initState();
    _copySnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void didUpdateWidget(covariant _TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.tripId != widget.trip.tripId) {
      _copySnapshot();
      _connect();
    }
  }

  void _copySnapshot() {
    _latitude = widget.trip.latitude;
    _longitude = widget.trip.longitude;
    _updatedAt = widget.trip.updatedAt;
  }

  void _connect() {
    if (!mounted || !widget.trip.isInProgress) return;
    final token = ref.read(tokenStoreProvider).accessToken;
    if (token == null) return;
    _socket.connect(
      ref.read(configProvider).socketUrl,
      token,
      onLocation: (event) {
        if (!mounted || event['tripId'] != widget.trip.tripId) return;
        final latitude = (event['latitude'] as num?)?.toDouble();
        final longitude = (event['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) return;
        setState(() {
          _latitude = latitude;
          _longitude = longitude;
          _updatedAt = (event['at'] as num?)?.toInt();
        });
      },
      onTripCompleted: () {
        if (mounted) ref.invalidate(studentTripProvider);
      },
    );
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final hasLocation = _latitude != null && _longitude != null;
    final point = hasLocation
        ? LatLng(_latitude!, _longitude!)
        : const LatLng(24.7136, 46.6753);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.wasl.wasl_mobile',
                  ),
                  if (hasLocation)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.directions_bus,
                            size: 40,
                            color: WaslColors.navy,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          color: WaslColors.emerald,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${trip.routeName ?? 'الرحلة'} • ${trip.busPlate ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          hasLocation
                              ? _freshnessLabel(_updatedAt)
                              : 'بانتظار الموقع',
                          style: const TextStyle(
                            color: WaslColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: WaslColors.surface,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.call),
                  label: const Text('اتصال بالسائق — غير متاح حالياً'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.support_agent),
                  label: const Text('التواصل مع المشرفة — غير متاح حالياً'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _freshnessLabel(int? timestamp) {
    if (timestamp == null) return 'تم استلام الموقع';
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age < 60 * 1000) return 'الآن';
    return 'منذ ${age ~/ (60 * 1000)} دقيقة';
  }
}
