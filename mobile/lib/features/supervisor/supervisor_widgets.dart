import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'bus_detail_screen.dart';
import 'supervisor_providers.dart';

/// Bus card with its trip status, boarding progress and counts.
class SupervisorBusItem extends StatelessWidget {
  final SupervisorBusView bus;

  const SupervisorBusItem({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    final active = bus.tripStatus == 'IN_PROGRESS';
    final showCounts = bus.hasTrip && bus.total > 0;
    return NdsListItem(
      leading: FeaturedIcon(
        HugeIcons.strokeRoundedBus01,
        tone: active ? Tone.primary : Tone.neutral,
      ),
      title: bus.name ?? ltr(bus.plateNumber),
      meta: [
        if (bus.name != null && bus.name != bus.plateNumber)
          ltr(bus.plateNumber),
        ?bus.routeName,
        if (bus.tripDirection != null) directionLabel(bus.tripDirection!),
      ].join(' · '),
      titleBadge: bus.uncovered > 0
          ? const NdsTag('غياب سائق', status: TagStatus.warning)
          : null,
      trailing: NdsTag(
        tripStatusLabel(bus.tripStatus),
        status: tripStatusTag(bus.tripStatus),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusDetailScreen(busId: bus.busId),
        ),
      ),
      bottom: showCounts
          ? NdsGroup(
              gap: Space.md,
              children: [
                ValueRow(
                  label: 'نسبة الصعود',
                  value: '${bus.boarded} من ${bus.total}',
                ),
                ProgressTrack(
                  value: bus.boarded / bus.total,
                  semanticsLabel: 'صعدت ${bus.boarded} من ${bus.total} طالبة',
                ),
                const Divider(height: Space.md),
                MiniStats(
                  items: [
                    ('${bus.total}', 'الإجمالي', null),
                    ('${bus.boarded}', 'صعدن', Nds.textSuccess),
                    ('${bus.waiting}', 'بانتظار', Nds.textWarning),
                    ('${bus.notReady}', 'غير جاهزات', Nds.textWarning),
                    ('${bus.missed}', 'فائتات', Nds.textError),
                  ],
                ),
              ],
            )
          : null,
    );
  }
}
