import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_state.dart';
import 'driver_providers.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final trips = ref.watch(driverTripsProvider).value ?? const <DriverTrip>[];
    final bus = trips.map((trip) => trip.busPlate).nonNulls.firstOrNull;
    final route = trips.map((trip) => trip.routeName).nonNulls.firstOrNull;

    return Scaffold(
      appBar: const NdsAppBar(title: 'ملفي'),
      body: PageBody(
        onRefresh: () async {
          ref.invalidate(driverTripsProvider);
          await ref.read(driverTripsProvider.future);
        },
        children: [
          ProfileHeader(
            name: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
            meta: 'سائق حافلة · جامعة الملك خالد',
          ),
          NdsGrid(
            columns: 2,
            children: [
              StatTile(value: '${trips.length}', label: 'رحلات اليوم'),
              StatTile(
                value: '${trips.where((trip) => trip.isCompleted).length}',
                label: 'رحلات مكتملة',
                color: Nds.textSuccess,
              ),
            ],
          ),
          NdsPanel(
            child: KvList([
              KvEntry('الحافلة', bus == null ? 'غير محددة' : ltr(bus)),
              KvEntry('خط السير', route ?? 'غير محدد'),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const AppIcon(HugeIcons.strokeRoundedLogout01, size: 20),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
