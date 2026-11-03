import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'bus_screens.dart';
import 'place_screens.dart';
import 'route_screens.dart';

enum TransportView {
  buses('الحافلات', 'إضافة حافلة', 'رقم اللوحة أو اسم الحافلة'),
  routes('المسارات', 'إضافة مسار', 'اسم المسار أو رمزه'),
  campuses('المقرات', 'إضافة مقر', 'اسم المقر'),
  neighborhoods('الأحياء', 'إضافة حي', 'اسم الحي');

  final String label;
  final String addLabel;
  final String searchHint;

  const TransportView(this.label, this.addLabel, this.searchHint);
}

/// Buses, routes, campuses and neighborhoods: search, page through, open or
/// add one.
class AdminTransportScreen extends ConsumerStatefulWidget {
  final TransportView view;
  final ValueChanged<TransportView> onViewChanged;

  const AdminTransportScreen({
    super.key,
    required this.view,
    required this.onViewChanged,
  });

  @override
  ConsumerState<AdminTransportScreen> createState() =>
      _AdminTransportScreenState();
}

class _AdminTransportScreenState extends ConsumerState<AdminTransportScreen> {
  final _search = {for (final view in TransportView.values) view: ''};

  TransportView get _view => widget.view;

  StructureQuery get _query => (search: _search[_view]!, activeOnly: false);

  void _loadMore() => switch (_view) {
    TransportView.buses =>
      ref.read(busDirectoryProvider(_query).notifier).loadMore(),
    TransportView.routes =>
      ref.read(routeDirectoryProvider(_query).notifier).loadMore(),
    TransportView.campuses =>
      ref.read(branchDirectoryProvider(_query).notifier).loadMore(),
    TransportView.neighborhoods =>
      ref.read(neighborhoodDirectoryProvider(_query).notifier).loadMore(),
  };

  Future<void> _refresh() async {
    refreshAdminData(ref);
    await switch (_view) {
      TransportView.buses => ref.read(busDirectoryProvider(_query).future),
      TransportView.routes => ref.read(routeDirectoryProvider(_query).future),
      TransportView.campuses => ref.read(
        branchDirectoryProvider(_query).future,
      ),
      TransportView.neighborhoods => ref.read(
        neighborhoodDirectoryProvider(_query).future,
      ),
    };
  }

  Future<T?> _push<T>(Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  Future<void> _add() async {
    switch (_view) {
      case TransportView.buses:
        final bus = await _push<AdminBus>(const BusFormScreen());
        if (bus != null && mounted) _push<void>(BusDetailScreen(busId: bus.id));
      case TransportView.routes:
        final route = await _push<AdminRoute>(const RouteFormScreen());
        if (route != null && mounted) {
          _push<void>(RouteDetailScreen(routeId: route.id));
        }
      case TransportView.campuses:
        await _push<Branch>(const CampusFormScreen());
      case TransportView.neighborhoods:
        await _push<Neighborhood>(const NeighborhoodFormScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NdsAppBar(
        title: 'النقل',
        trailing: CircleIconButton(
          icon: HugeIcons.strokeRoundedAdd01,
          tooltip: _view.addLabel,
          onPressed: _add,
        ),
      ),
      body: PageBody(
        onRefresh: _refresh,
        onNearEnd: _loadMore,
        children: [
          NdsChoiceChips<TransportView>(
            options: [
              for (final view in TransportView.values) (view, view.label),
            ],
            selected: _view,
            onSelected: widget.onViewChanged,
          ),
          SearchBox(
            key: ValueKey(_view),
            initial: _search[_view]!,
            hint: _view.searchHint,
            onSearch: (value) => setState(() => _search[_view] = value),
          ),
          ...switch (_view) {
            TransportView.buses => _list(
              ref.watch(busDirectoryProvider(_query)),
              () => ref.invalidate(busDirectoryProvider(_query)),
              count: busCount,
              empty: (
                HugeIcons.strokeRoundedBus01,
                'لا توجد حافلات',
                'أضف الحافلات ثم عيّن على كل منها سائقاً ومشرفة ومساراً ثابتاً.',
              ),
              tile: (bus) => BusTile(
                bus: bus,
                onTap: () => _push<void>(BusDetailScreen(busId: bus.id)),
              ),
            ),
            TransportView.routes => _list(
              ref.watch(routeDirectoryProvider(_query)),
              () => ref.invalidate(routeDirectoryProvider(_query)),
              count: routeCount,
              empty: (
                HugeIcons.strokeRoundedRoute01,
                'لا توجد مسارات',
                'أضف مساراً بمحطاته ثم عيّن عليه الطالبات.',
              ),
              tile: (route) => RouteTile(
                route: route,
                onTap: () => _push<void>(RouteDetailScreen(routeId: route.id)),
              ),
            ),
            TransportView.campuses => _list(
              ref.watch(branchDirectoryProvider(_query)),
              () => ref.invalidate(branchDirectoryProvider(_query)),
              count: campusCount,
              empty: (
                HugeIcons.strokeRoundedUniversity,
                'لا توجد مقرات',
                'أضف مقرات الجامعة التي تصل إليها المسارات.',
              ),
              tile: (campus) => CampusTile(
                campus: campus,
                onTap: () => _push<Branch>(CampusFormScreen(campus: campus)),
              ),
            ),
            TransportView.neighborhoods => _list(
              ref.watch(neighborhoodDirectoryProvider(_query)),
              () => ref.invalidate(neighborhoodDirectoryProvider(_query)),
              count: neighborhoodCount,
              empty: (
                HugeIcons.strokeRoundedLocation01,
                'لا توجد أحياء',
                'أضف الأحياء التي تمر بها المسارات.',
              ),
              tile: (hood) => NeighborhoodTile(
                hood: hood,
                onTap: () =>
                    _push<Neighborhood>(NeighborhoodFormScreen(hood: hood)),
              ),
            ),
          },
        ],
      ),
    );
  }

  List<Widget> _list<T>(
    AsyncValue<Paged<T>> async,
    VoidCallback retry, {
    required String Function(int) count,
    required (HugeIconData, String, String) empty,
    required Widget Function(T) tile,
  }) {
    final searching = _search[_view]!.isNotEmpty;
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const [LoadingView()],
      error: (_, _) => [ErrorView(onRetry: retry)],
      data: (paged) => [
        if (paged.items.isEmpty)
          MessageView(
            icon: searching ? HugeIcons.strokeRoundedSearch01 : empty.$1,
            title: searching ? 'لا توجد نتائج' : empty.$2,
            message: searching ? 'جرّب كلمة بحث أخرى.' : empty.$3,
            action: searching
                ? null
                : ElevatedButton(onPressed: _add, child: Text(_view.addLabel)),
          )
        else ...[
          Text(
            shownOf(paged.items.length, paged.total, count),
            style: NdsText.textSm.copyWith(color: Nds.textSecondary),
          ),
          NdsGroup(children: [for (final item in paged.items) tile(item)]),
        ],
        PagedFooter(paged: paged, onLoadMore: _loadMore),
      ],
    );
  }
}
