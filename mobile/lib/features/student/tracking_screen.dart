import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'student_providers.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentTripProvider);
    final refresh = CircleIconButton(
      icon: HugeIcons.strokeRoundedRefresh,
      tooltip: 'تحديث',
      onPressed: () => ref.invalidate(studentTripProvider),
    );

    return Scaffold(
      appBar: NdsAppBar(title: 'تتبع الحافلة', trailing: refresh),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(studentTripProvider)),
        data: (trip) {
          if (!trip.hasActiveTrip) {
            return const _TrackingLayout(
              map: MapPlaceholder(
                text: 'سيظهر موقع الحافلة هنا عند انطلاق رحلتك',
              ),
              caption: 'رحلة اليوم',
              headline: 'لا توجد رحلة اليوم',
              detail: 'سيظهر التتبع هنا عند جدولة رحلتك.',
            );
          }
          if (!trip.isInProgress) {
            return _TrackingLayout(
              strip: _TripStrip(trip: trip),
              map: const MapPlaceholder(
                text: 'سيظهر موقع الحافلة عند انطلاقها',
              ),
              caption: 'حالة الرحلة',
              headline: 'في انتظار انطلاق الحافلة',
              detail: 'تظهر الحافلة على الخريطة فور بدء السائق الرحلة.',
            );
          }
          return _LiveTracking(trip: trip);
        },
      ),
    );
  }
}

/// Strip, map and bottom sheet arrangement of the tracking screen.
class _TrackingLayout extends StatelessWidget {
  final Widget? strip;
  final Widget map;
  final String caption;
  final String headline;
  final String detail;

  const _TrackingLayout({
    this.strip,
    required this.map,
    required this.caption,
    required this.headline,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = NdsText.textSm.copyWith(color: Nds.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?strip,
        Expanded(child: map),
        Container(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.x2l,
            Space.xl,
            Space.x2l,
          ),
          decoration: const BoxDecoration(
            color: Nds.backgroundDefault,
            border: Border(top: BorderSide(color: Nds.borderNeutral)),
          ),
          child: Semantics(
            liveRegion: true,
            child: NdsGroup(
              gap: Space.xxs,
              children: [
                Text(caption, style: secondary),
                Text(
                  headline,
                  style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
                ),
                Text(detail, style: secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TripStrip extends StatelessWidget {
  final StudentTripView trip;

  const _TripStrip({required this.trip});

  @override
  Widget build(BuildContext context) {
    final title = [
      if (trip.busPlate != null) ltr(trip.busPlate!),
      ?trip.routeName,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.md,
      ),
      decoration: const BoxDecoration(
        color: Nds.backgroundDefault,
        border: Border(bottom: BorderSide(color: Nds.borderNeutral)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.isEmpty ? 'رحلة اليوم' : title,
              style: NdsText.textMd.copyWith(
                fontWeight: FontWeight.w600,
                color: Nds.textDisplay,
              ),
            ),
          ),
          trip.isInProgress
              ? const NdsTag('في الطريق إليكِ', status: TagStatus.info)
              : const NdsTag('لم تنطلق بعد'),
        ],
      ),
    );
  }
}

class _LiveTracking extends ConsumerStatefulWidget {
  final StudentTripView trip;

  const _LiveTracking({required this.trip});

  @override
  ConsumerState<_LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends ConsumerState<_LiveTracking> {
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
  void didUpdateWidget(covariant _LiveTracking oldWidget) {
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
        : const LatLng(18.2465, 42.5117);

    return _TrackingLayout(
      strip: _TripStrip(trip: trip),
      map: hasLocation
          ? FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'tech.scintilla.wusool',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      child: Semantics(
                        label: 'موقع الحافلة',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Nds.backgroundPrimaryStrong,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Nds.textOnColor,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const AppIcon(
                            HugeIcons.strokeRoundedBus01,
                            size: 22,
                            color: Nds.textOnColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            )
          : const MapPlaceholder(text: 'بانتظار أول موقع من الحافلة'),
      caption: 'آخر تحديث لموقع الحافلة',
      headline: hasLocation ? _freshnessLabel(_updatedAt) : 'بانتظار الموقع',
      detail: boardingStatusLabel(trip.myStatus),
    );
  }

  String _freshnessLabel(int? timestamp) {
    if (timestamp == null) return 'تم استلام الموقع';
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age < 60 * 1000) return 'الآن';
    return 'منذ ${age ~/ (60 * 1000)} دقيقة';
  }
}
