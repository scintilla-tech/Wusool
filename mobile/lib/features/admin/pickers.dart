import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'people.dart';
import 'route_screens.dart';

/// Picks a route in service; pops with the [AdminRoute].
class PickRouteScreen extends ConsumerStatefulWidget {
  final String? currentId;

  /// When picking a bus's fixed route: routes another bus runs are shown
  /// but cannot be picked.
  final String? forBusId;

  const PickRouteScreen({super.key, this.currentId, this.forBusId});

  @override
  ConsumerState<PickRouteScreen> createState() => _PickRouteScreenState();
}

class _PickRouteScreenState extends ConsumerState<PickRouteScreen> {
  String _search = '';

  StructureQuery get _query => (search: _search, activeOnly: true);

  Future<void> _create() async {
    final route = await Navigator.of(context).push<AdminRoute>(
      MaterialPageRoute(builder: (_) => const RouteFormScreen()),
    );
    if (route != null && mounted) Navigator.of(context).pop(route);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(routeDirectoryProvider(_query));
    void loadMore() =>
        ref.read(routeDirectoryProvider(_query).notifier).loadMore();
    return Scaffold(
      appBar: NdsAppBar(
        title: 'اختيار مسار',
        trailing: CircleIconButton(
          icon: HugeIcons.strokeRoundedAdd01,
          tooltip: 'إضافة مسار',
          onPressed: _create,
        ),
      ),
      body: PageBody(
        onNearEnd: loadMore,
        children: [
          SearchBox(
            hint: 'اسم المسار أو رمزه',
            onSearch: (value) => setState(() => _search = value),
          ),
          ...async.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(
                onRetry: () => ref.invalidate(routeDirectoryProvider(_query)),
              ),
            ],
            data: (paged) => [
              if (paged.items.isEmpty)
                MessageView(
                  icon: HugeIcons.strokeRoundedRoute01,
                  title: _search.isEmpty ? 'لا توجد مسارات' : 'لا توجد نتائج',
                  message: _search.isEmpty
                      ? 'أضف مساراً بمحطاته ثم عيّن عليه الطالبات.'
                      : null,
                  action: _search.isEmpty
                      ? ElevatedButton(
                          onPressed: _create,
                          child: const Text('إضافة مسار'),
                        )
                      : null,
                )
              else
                NdsGroup(
                  children: [
                    for (final route in paged.items) _routeTile(route),
                  ],
                ),
              PagedFooter(paged: paged, onLoadMore: loadMore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeTile(AdminRoute route) {
    final current = route.id == widget.currentId;
    final runBy = widget.forBusId != null && route.bus != null
        ? route.bus!.id == widget.forBusId
              ? null
              : route.bus!
        : null;
    return RouteTile(
      route: route,
      trailing: current
          ? const NdsTag('الحالي', status: TagStatus.info)
          : runBy != null
          ? NdsTag('تشغّله ${runBy.label}')
          : null,
      onTap: current || runBy != null
          ? null
          : () => Navigator.of(context).pop(route),
    );
  }
}

/// Picks a bus in service for a driver or supervisor; pops with the bus.
class PickBusScreen extends ConsumerStatefulWidget {
  final PersonRole role;
  final String? currentId;

  const PickBusScreen({super.key, required this.role, this.currentId});

  @override
  ConsumerState<PickBusScreen> createState() => _PickBusScreenState();
}

class _PickBusScreenState extends ConsumerState<PickBusScreen> {
  String _search = '';

  StructureQuery get _query => (search: _search, activeOnly: true);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(busDirectoryProvider(_query));
    void loadMore() =>
        ref.read(busDirectoryProvider(_query).notifier).loadMore();
    return Scaffold(
      appBar: const NdsAppBar(title: 'اختيار حافلة'),
      body: PageBody(
        onNearEnd: loadMore,
        children: [
          SearchBox(
            hint: 'رقم اللوحة أو اسم الحافلة',
            onSearch: (value) => setState(() => _search = value),
          ),
          ...async.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(
                onRetry: () => ref.invalidate(busDirectoryProvider(_query)),
              ),
            ],
            data: (paged) => [
              if (paged.items.isEmpty)
                MessageView(
                  icon: HugeIcons.strokeRoundedBus01,
                  title: _search.isEmpty
                      ? 'لا توجد حافلات في الخدمة'
                      : 'لا توجد نتائج',
                )
              else
                NdsGroup(
                  children: [
                    for (final bus in paged.items)
                      BusTile(
                        bus: bus,
                        trailing: bus.id == widget.currentId
                            ? const NdsTag('الحالية', status: TagStatus.info)
                            : null,
                        onTap: bus.id == widget.currentId
                            ? null
                            : () => Navigator.of(context).pop(bus),
                      ),
                  ],
                ),
              PagedFooter(paged: paged, onLoadMore: loadMore),
            ],
          ),
        ],
      ),
    );
  }
}

/// Picks a driver or supervisor for a bus; pops with the [Person].
class PickPersonScreen extends ConsumerStatefulWidget {
  final PersonRole role;

  /// The bus being staffed; whoever is on it already is marked.
  final String busId;

  const PickPersonScreen({super.key, required this.role, required this.busId});

  @override
  ConsumerState<PickPersonScreen> createState() => _PickPersonScreenState();
}

class _PickPersonScreenState extends ConsumerState<PickPersonScreen> {
  String _search = '';
  PersonStatus _status = PersonStatus.unassigned;

  PeopleQuery get _query =>
      peopleQuery(widget.role, search: _search, status: _status);

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final async = ref.watch(peopleDirectoryProvider(_query));
    void loadMore() =>
        ref.read(peopleDirectoryProvider(_query).notifier).loadMore();
    return Scaffold(
      appBar: NdsAppBar(
        title: role == PersonRole.driver ? 'اختيار سائق' : 'اختيار مشرفة',
      ),
      body: PageBody(
        onNearEnd: loadMore,
        children: [
          SearchBox(
            hint: 'الاسم أو الرقم الوظيفي أو الجوال',
            onSearch: (value) => setState(() => _search = value),
          ),
          NdsChoiceChips<PersonStatus>(
            options: const [
              (PersonStatus.unassigned, 'بدون حافلة'),
              (PersonStatus.all, 'الكل'),
            ],
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
          ),
          ...async.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(
                onRetry: () => ref.invalidate(peopleDirectoryProvider(_query)),
              ),
            ],
            data: (paged) => [
              if (paged.items.isEmpty)
                MessageView(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  title: 'لا توجد نتائج',
                  message: _status == PersonStatus.unassigned
                      ? 'كل ${role.plural} على حافلات. اختر «الكل» للنقل من حافلة أخرى.'
                      : null,
                )
              else
                NdsGroup(
                  children: [
                    for (final person in paged.items)
                      PersonTile(
                        person: person,
                        trailing: person.bus?.id == widget.busId
                            ? const NdsTag('على هذه الحافلة')
                            : null,
                        onTap:
                            !person.isActive || person.bus?.id == widget.busId
                            ? null
                            : () => Navigator.of(context).pop(person),
                      ),
                  ],
                ),
              PagedFooter(paged: paged, onLoadMore: loadMore),
            ],
          ),
        ],
      ),
    );
  }
}

/// Picks students to put on [route]; pops with their profile ids.
class PickStudentsScreen extends ConsumerStatefulWidget {
  final AdminRoute route;

  const PickStudentsScreen({super.key, required this.route});

  @override
  ConsumerState<PickStudentsScreen> createState() => _PickStudentsScreenState();
}

class _PickStudentsScreenState extends ConsumerState<PickStudentsScreen> {
  String _search = '';
  PersonStatus _status = PersonStatus.unassigned;

  /// Profile id to the student, so the count survives changing the filter.
  final Map<String, Person> _picked = {};

  PeopleQuery get _query =>
      peopleQuery(PersonRole.student, search: _search, status: _status);

  void _toggle(Person person) => setState(() {
    if (_picked.remove(person.profileId) == null) {
      _picked[person.profileId] = person;
    }
  });

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peopleDirectoryProvider(_query));
    void loadMore() =>
        ref.read(peopleDirectoryProvider(_query).notifier).loadMore();
    final moving = _picked.values.where((p) => p.route != null).length;
    return Scaffold(
      appBar: NdsAppBar(title: 'إضافة طالبات', subtitle: widget.route.name),
      body: PageBody(
        onNearEnd: loadMore,
        children: [
          SearchBox(
            hint: 'الاسم أو الرقم الجامعي أو الجوال',
            onSearch: (value) => setState(() => _search = value),
          ),
          NdsChoiceChips<PersonStatus>(
            options: const [
              (PersonStatus.unassigned, 'بدون مسار'),
              (PersonStatus.all, 'الكل'),
            ],
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
          ),
          ...async.when(
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(
                onRetry: () => ref.invalidate(peopleDirectoryProvider(_query)),
              ),
            ],
            data: (paged) => [
              if (paged.items.isEmpty)
                MessageView(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  title: 'لا توجد نتائج',
                  message: _status == PersonStatus.unassigned && _search.isEmpty
                      ? 'كل الطالبات على مسارات. اختر «الكل» للنقل من مسار آخر.'
                      : null,
                )
              else
                NdsGroup(
                  children: [for (final person in paged.items) _tile(person)],
                ),
              PagedFooter(paged: paged, onLoadMore: loadMore),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NdsFooter(
        children: [
          if (moving > 0)
            InlineNote(
              '${studentCount(moving)} على مسارات أخرى، وتُنقل إلى ${widget.route.name}.',
            ),
          ElevatedButton(
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(_picked.keys.toList()),
            child: Text(
              _picked.isEmpty
                  ? 'اختر الطالبات'
                  : 'إضافة ${studentCount(_picked.length)} إلى المسار',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Person person) {
    final onThisRoute = person.route?.id == widget.route.id;
    final selectable = person.isActive && !onThisRoute;
    final picked = _picked.containsKey(person.profileId);
    return Semantics(
      checked: selectable ? picked : null,
      child: PersonTile(
        person: person,
        trailing: onThisRoute
            ? const NdsTag('على هذا المسار')
            : !person.isActive
            ? null
            : AppIcon(
                picked
                    ? HugeIcons.strokeRoundedCheckmarkSquare02
                    : HugeIcons.strokeRoundedSquare,
                color: picked ? Nds.textPrimary : Nds.iconNeutral,
              ),
        onTap: selectable ? () => _toggle(person) : null,
      ),
    );
  }
}

/// Picks a neighborhood as a route stop, or adds a new one; pops with it.
/// Admins search and add through the structure endpoints; drivers pass
/// [search] and [create] for theirs.
class PickNeighborhoodScreen extends ConsumerStatefulWidget {
  /// Stops the route already has.
  final Set<String> exclude;
  final Future<List<Neighborhood>> Function(String search)? search;
  final Future<Neighborhood> Function(String name)? create;

  const PickNeighborhoodScreen({
    super.key,
    this.exclude = const {},
    this.search,
    this.create,
  });

  @override
  ConsumerState<PickNeighborhoodScreen> createState() =>
      _PickNeighborhoodScreenState();
}

class _PickNeighborhoodScreenState
    extends ConsumerState<PickNeighborhoodScreen> {
  String _search = '';
  bool _busy = false;
  late Future<List<Neighborhood>> _found = _load();

  Future<List<Neighborhood>> _load() =>
      widget.search?.call(_search) ??
      ref.read(adminApiProvider).neighborhoods(_search);

  Future<void> _add(String name) async {
    setState(() => _busy = true);
    try {
      final created =
          await (widget.create?.call(name) ??
              ref.read(adminApiProvider).createNeighborhood(name));
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          apiErrorCode(error) == 'VALIDATION_ERROR'
              ? 'يُكتب اسم الحي بالحروف والأرقام فقط'
              : adminFailure(error),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _search.trim();
    return Scaffold(
      appBar: const NdsAppBar(title: 'إضافة محطة'),
      body: PageBody(
        children: [
          SearchBox(
            label: 'الحي',
            hint: 'ابحث عن حي أو اكتب اسم حي جديد',
            onSearch: (value) => setState(() {
              _search = value;
              _found = _load();
            }),
          ),
          FutureBuilder<List<Neighborhood>>(
            future: _found,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(
                  onRetry: () => setState(() => _found = _load()),
                );
              }
              final hoods = snapshot.data;
              if (hoods == null) return const LoadingView();
              final exact = hoods.any(
                (hood) => hood.name.toLowerCase() == typed.toLowerCase(),
              );
              final shown = [
                for (final hood in hoods)
                  if (!widget.exclude.contains(hood.id)) hood,
              ];
              return NdsGroup(
                gap: Space.xl,
                children: [
                  if (typed.isNotEmpty && !exact)
                    NdsListItem(
                      leading: const FeaturedIcon(HugeIcons.strokeRoundedAdd01),
                      title: 'إضافة «$typed» حياً جديداً',
                      meta: 'يُضاف إلى قائمة الأحياء ويصبح محطة',
                      onTap: _busy ? null : () => _add(typed),
                    ),
                  if (shown.isEmpty && typed.isEmpty)
                    const MessageView(
                      icon: HugeIcons.strokeRoundedLocation01,
                      title: 'لا توجد أحياء بعد',
                      message: 'اكتب اسم الحي في البحث لإضافته.',
                    )
                  else
                    NdsGroup(
                      children: [
                        for (final hood in shown)
                          NdsListItem(
                            leading: const FeaturedIcon(
                              HugeIcons.strokeRoundedLocation01,
                              tone: Tone.neutral,
                            ),
                            title: hood.name,
                            chevron: true,
                            onTap: () => Navigator.of(context).pop(hood),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
