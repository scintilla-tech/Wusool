import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_providers.dart';

class AdminBusesScreen extends ConsumerStatefulWidget {
  const AdminBusesScreen({super.key});

  @override
  ConsumerState<AdminBusesScreen> createState() => _AdminBusesScreenState();
}

class _AdminBusesScreenState extends ConsumerState<AdminBusesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AdminBusRow bus) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      bus.plateNumber,
      bus.name,
    ].nonNulls.any((value) => value.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminBusesProvider);

    return Scaffold(
      appBar: const NdsAppBar(title: 'الحافلات'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(adminBusesProvider)),
        data: (buses) {
          final shown = buses.where(_matches).toList();
          return PageBody(
            onRefresh: () async {
              ref.invalidate(adminBusesProvider);
              await ref.read(adminBusesProvider.future);
            },
            children: [
              NdsField(
                label: 'البحث عن حافلة',
                controller: _search,
                icon: HugeIcons.strokeRoundedSearch01,
                hint: 'رقم اللوحة أو اسم الحافلة',
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
              Text(
                busCount(shown.length),
                style: NdsText.textSm.copyWith(color: Nds.textSecondary),
              ),
              if (shown.isEmpty)
                const MessageView(
                  icon: HugeIcons.strokeRoundedBus01,
                  title: 'لا توجد حافلات',
                )
              else
                NdsGroup(
                  children: [
                    for (final bus in shown)
                      NdsListItem(
                        leading: FeaturedIcon(
                          HugeIcons.strokeRoundedBus01,
                          tone: bus.isActive ? Tone.primary : Tone.neutral,
                        ),
                        title: bus.name ?? ltr(bus.plateNumber),
                        titleBadge: NdsTag(
                          bus.isActive ? 'نشطة' : 'معطّلة',
                          status: bus.isActive
                              ? TagStatus.success
                              : TagStatus.error,
                        ),
                        meta: [
                          if (bus.name != null && bus.name != bus.plateNumber)
                            ltr(bus.plateNumber),
                          if (bus.capacity != null) seatCount(bus.capacity!),
                        ].join(' · '),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
