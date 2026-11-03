import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'driver_providers.dart';
import 'driver_route_screen.dart';

/// A driver adds today's going or return trip to their bus, on its fixed
/// route or, when it has none, a route they pick. Pops true once created.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  String? _direction;
  bool _busy = false;

  Future<void> _buildRoute() async {
    final built = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const DriverRouteScreen()));
    if (built == true) ref.invalidate(driverBusProvider);
  }

  Future<void> _create(DriverBus bus) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/driver/trips', data: {'direction': _direction});
      if (!mounted) return;
      showMessage(context, 'أُنشئت ${directionLabel(_direction!)}');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(driverBusProvider);
      showMessage(context, _failure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _failure(Object error) => switch (apiErrorCode(error)) {
    'TRIP_EXISTS' => 'لحافلتك هذه الرحلة اليوم',
    'TRIP_CONFLICT' => 'لديك رحلة أخرى في الاتجاه نفسه اليوم',
    'ROUTE_TRIP_EXISTS' => 'لهذا المسار رحلة اليوم على حافلة أخرى',
    'NO_ROUTE' => 'أنشئ مسار حافلتك أولاً',
    'NO_BUS' => 'لست معيّناً على حافلة',
    _ => 'تعذّر إنشاء الرحلة، حاول مرة أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driverBusProvider);
    return Scaffold(
      appBar: const NdsAppBar(title: 'إنشاء رحلة'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(driverBusProvider)),
        data: (bus) => PageBody(children: _content(bus)),
      ),
      bottomNavigationBar: switch (async.value) {
        final DriverBus bus?
            when bus.hasBus && bus.route != null && bus.missing.isNotEmpty =>
          NdsFooter(
            children: [
              ElevatedButton(
                onPressed: _busy || _direction == null
                    ? null
                    : () => _create(bus),
                child: Text(
                  _direction == null
                      ? 'اختر الرحلة'
                      : 'إنشاء ${directionLabel(_direction!)}',
                ),
              ),
            ],
          ),
        _ => null,
      },
    );
  }

  List<Widget> _content(DriverBus bus) {
    if (!bus.hasBus) {
      return const [
        MessageView(
          icon: HugeIcons.strokeRoundedBus01,
          title: 'لست معيّناً على حافلة',
          message: 'تواصل مع إدارة النقل لتعيينك على حافلة.',
        ),
      ];
    }
    if (bus.route == null) {
      return [
        MessageView(
          icon: HugeIcons.strokeRoundedRoute01,
          title: 'أنشئ مسار حافلتك أولاً',
          message:
              'مرة واحدة فقط: اسم المسار ومحطاته بالترتيب. بعدها تُنشأ رحلاتك '
              'تلقائياً كل يوم دراسي، ويمكنك تعديله متى شئت.',
          action: ElevatedButton.icon(
            onPressed: _buildRoute,
            icon: const AppIcon(HugeIcons.strokeRoundedAdd01, size: 20),
            label: const Text('إنشاء مسار الحافلة'),
          ),
        ),
      ];
    }
    if (bus.missing.isEmpty) {
      return const [
        MessageView(
          icon: HugeIcons.strokeRoundedTick02,
          tone: Tone.success,
          title: 'رحلتا اليوم موجودتان',
          message: 'تجدهما في الصفحة الرئيسية.',
        ),
      ];
    }
    final plate = ltr(bus.plateNumber ?? '');
    return [
      NdsListItem(
        leading: const FeaturedIcon(HugeIcons.strokeRoundedBus01),
        title: bus.busName ?? plate,
        meta: bus.busName == null ? null : plate,
      ),
      Section(
        title: 'الرحلة',
        children: [
          Row(
            children: [
              for (final (index, direction) in const [
                'OUTBOUND',
                'RETURN',
              ].indexed) ...[
                if (index > 0) const SizedBox(width: Space.md),
                Expanded(
                  child: ChoiceButton(
                    label: directionLabel(direction),
                    selected: _direction == direction,
                    onPressed: bus.missing.contains(direction)
                        ? () => setState(() => _direction = direction)
                        : null,
                  ),
                ),
              ],
            ],
          ),
          if (bus.todayDirections.isNotEmpty)
            InlineNote(
              '${directionLabel(bus.todayDirections.first)} موجودة اليوم.',
            ),
        ],
      ),
      Section(
        title: 'المسار',
        children: [
          NdsListItem(
            leading: const FeaturedIcon(HugeIcons.strokeRoundedRoute01),
            title: bus.route!.name,
            meta: bus.route!.stopsLine,
          ),
        ],
      ),
    ];
  }
}
