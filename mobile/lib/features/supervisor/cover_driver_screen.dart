import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/ui.dart';
import '../driver/driver_providers.dart' show dayLabel, isoDay;
import 'supervisor_providers.dart';

/// A bus supervisor picks the driver for the bus's trips on [date] (today
/// when null): today, the trips that have not started; on a coming day the
/// driver reported, the trips made that morning. Choosing the bus's own
/// driver today hands the trips back. Both drivers are notified. Pops true
/// once changed.
class CoverDriverScreen extends ConsumerStatefulWidget {
  final SupervisorBusView bus;
  final DateTime? date;

  const CoverDriverScreen({super.key, required this.bus, this.date});

  @override
  ConsumerState<CoverDriverScreen> createState() => _CoverDriverScreenState();
}

class _CoverDriverScreenState extends ConsumerState<CoverDriverScreen> {
  bool _busy = false;

  String get _busLabel => widget.bus.name ?? ltr(widget.bus.plateNumber);

  bool get _today => widget.date == null || dayLabel(widget.date!) == 'اليوم';

  String get _day => widget.date == null ? 'اليوم' : dayLabel(widget.date!);

  ({String busId, String? day}) get _key =>
      (busId: widget.bus.busId, day: _today ? null : isoDay(widget.date!));

  Future<void> _choose(CoverCandidate driver) async {
    final regular = widget.bus.regularDriverName;
    final previous = _today ? widget.bus.driverName : null;
    final told = {?previous, ?regular}..remove(driver.name);
    final confirmed = await showConfirmSheet(
      context,
      title: driver.regular
          ? 'إعادة رحلات $_day إلى ${driver.name}؟'
          : 'تكليف ${driver.name} برحلات $_day؟',
      message: [
        _today
            ? 'يقود ${driver.name} رحلات $_busLabel التي لم تبدأ اليوم.'
            : 'تُنشأ رحلات $_busLabel $_day باسم ${driver.name}.',
        told.isEmpty
            ? 'يصله إشعار بذلك.'
            : 'يصل إشعار إليه وإلى ${told.join(' و')}.',
      ].join(' '),
      confirmLabel: driver.regular ? 'إعادة الرحلات' : 'تكليف ${driver.name}',
      icon: HugeIcons.strokeRoundedUserSwitch,
      tone: Tone.primary,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/supervisor/buses/${widget.bus.busId}/cover',
            data: {
              'driverProfileId': driver.profileId,
              if (!_today) 'date': isoDay(widget.date!),
            },
          );
      if (!mounted) return;
      ref.invalidate(supervisorBusesProvider);
      showMessage(
        context,
        driver.regular
            ? 'أُعيدت الرحلات إلى ${driver.name}'
            : 'كُلّف ${driver.name} برحلات $_day',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(coverCandidatesProvider(_key));
      showMessage(context, _failure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _failure(Object error) => switch (apiErrorCode(error)) {
    'DRIVER_BUSY' => 'لدى السائق رحلات أخرى في ذلك اليوم',
    'NO_TRIPS_TO_COVER' => 'لا رحلات لم تبدأ اليوم لهذه الحافلة',
    'NO_ABSENCE' => 'لم يبلّغ السائق عن غيابه في ذلك اليوم',
    'NOT_FOUND' => 'السائق لم يعد متاحاً',
    _ => 'تعذّر تغيير السائق، حاول مرة أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coverCandidatesProvider(_key));
    return Scaffold(
      appBar: NdsAppBar(title: 'سائق بديل', subtitle: '$_busLabel · $_day'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(coverCandidatesProvider(_key)),
        ),
        data: (drivers) => PageBody(
          onRefresh: () async {
            ref.invalidate(coverCandidatesProvider(_key));
            await ref.read(coverCandidatesProvider(_key).future);
          },
          children: [
            InlineNote(
              _today
                  ? 'يقود السائق الذي تختارينه رحلات اليوم التي لم تبدأ، ويصله إشعار.'
                  : 'تُنشأ رحلات $_day باسم السائق الذي تختارينه، ويصله إشعار الآن.',
            ),
            if (drivers.isEmpty)
              const MessageView(
                icon: HugeIcons.strokeRoundedUserGroup,
                title: 'لا سائقين',
              )
            else
              NdsGroup(
                children: [
                  for (final driver in _ordered(drivers)) _tile(driver),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Free drivers first, then the busy and the away ones.
  List<CoverCandidate> _ordered(List<CoverCandidate> drivers) {
    bool free(CoverCandidate d) => d.busy.isEmpty && !d.absent;
    return [
      ...drivers.where((d) => d.regular && free(d)),
      ...drivers.where((d) => !d.regular && free(d)),
      ...drivers.where((d) => !free(d)),
    ];
  }

  Widget _tile(CoverCandidate driver) {
    final available = !driver.current && !driver.absent && driver.busy.isEmpty;
    return NdsListItem(
      leading: InitialsAvatar(driver.name),
      title: driver.name,
      titleBadge: driver.absent
          ? const NdsTag('غائب', status: TagStatus.warning)
          : driver.current
          ? NdsTag(
              _today ? 'يقود اليوم' : 'البديل الحالي',
              status: TagStatus.info,
            )
          : driver.regular
          ? const NdsTag('سائق الحافلة')
          : null,
      meta: driver.regular
          ? null
          : driver.busLabel == null
          ? 'بلا حافلة'
          : 'حافلته: ${driver.busLabel}',
      meta2: driver.busy.isEmpty
          ? null
          : _today
          ? 'مشغول: ${driver.busy.map(directionLabel).join(' و')}'
          : 'يقود حافلة أخرى في ذلك اليوم',
      chevron: available,
      onTap: available && !_busy ? () => _choose(driver) : null,
    );
  }
}
