import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'supervisor_providers.dart';
import 'supervisor_widgets.dart';

/// Searchable, filterable list of every bus the field supervisor follows.
class FieldBusListScreen extends ConsumerStatefulWidget {
  const FieldBusListScreen({super.key});

  @override
  ConsumerState<FieldBusListScreen> createState() => _FieldBusListScreenState();
}

class _FieldBusListScreenState extends ConsumerState<FieldBusListScreen> {
  final _search = TextEditingController();
  String _filter = 'ALL';

  static const _filters = [
    ('ALL', 'الكل'),
    ('IN_PROGRESS', 'في الطريق'),
    ('SCHEDULED', 'لم تنطلق'),
    ('COMPLETED', 'وصلت'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(SupervisorBusView bus) {
    if (_filter != 'ALL' && bus.tripStatus != _filter) return false;
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      bus.plateNumber,
      bus.name,
      bus.routeName,
    ].nonNulls.any((value) => value.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supervisorBusesProvider);

    return Scaffold(
      appBar: const NdsAppBar(title: 'الحافلات والمتابعة'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(supervisorBusesProvider)),
        data: (buses) {
          final shown = buses.where(_matches).toList();
          return PageBody(
            onRefresh: () async {
              ref.invalidate(supervisorBusesProvider);
              await ref.read(supervisorBusesProvider.future);
            },
            children: [
              NdsField(
                label: 'البحث عن حافلة',
                controller: _search,
                icon: HugeIcons.strokeRoundedSearch01,
                hint: 'رقم الحافلة أو المسار',
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
              NdsChoiceChips<String>(
                options: _filters,
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              Text(
                shown.length == buses.length
                    ? busCount(buses.length)
                    : '${shown.length} من ${busCount(buses.length)}',
                style: NdsText.textSm.copyWith(color: Nds.textSecondary),
              ),
              if (shown.isEmpty)
                const MessageView(
                  icon: HugeIcons.strokeRoundedBus01,
                  title: 'لا توجد حافلات بهذه الحالة الآن',
                ),
              if (shown.isNotEmpty)
                NdsGroup(
                  children: [
                    for (final bus in shown) SupervisorBusItem(bus: bus),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
