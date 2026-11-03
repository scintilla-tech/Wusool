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
import 'person_detail_screen.dart';
import 'pickers.dart';

/// Numbered stop, as route screens list them in order.
class StopRow extends StatelessWidget {
  final int number;
  final String name;
  final Widget? trailing;

  const StopRow({
    super.key,
    required this.number,
    required this.name,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Nds.backgroundPrimaryLight,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: NdsText.textSm.copyWith(
              fontWeight: FontWeight.w600,
              color: Nds.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Text(
            name,
            style: NdsText.textMd.copyWith(color: Nds.textDefault),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One route: its stops, the students who ride it, editing it and taking it
/// out of service.
class RouteDetailScreen extends ConsumerStatefulWidget {
  final String routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  String _search = '';
  bool _busy = false;

  AdminApi get _api => ref.read(adminApiProvider);

  PeopleQuery get _students =>
      peopleQuery(PersonRole.student, search: _search, routeId: widget.routeId);

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      refreshAdminData(ref);
      showMessage(context, done);
    } catch (error) {
      if (mounted) showMessage(context, adminFailure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addStudents(AdminRoute route) async {
    final ids = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => PickStudentsScreen(route: route)),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await _run(
      () => _api.assignStudents(route.id, ids),
      'أُضيفت ${studentCount(ids.length)} إلى ${route.name}',
    );
  }

  Future<void> _removeStudent(AdminRoute route, Person student) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'إزالة ${student.fullName} من ${route.name}؟',
      message: 'لن تظهر في قائمة الحافلة حتى تُعيَّن على مسار آخر.',
      confirmLabel: 'إزالة',
      destructive: true,
      icon: HugeIcons.strokeRoundedRemove01,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => _api.unassignStudent(student.profileId),
      'أُزيلت ${student.fullName} من المسار',
    );
  }

  Future<void> _toggleEnabled(AdminRoute route) async {
    if (route.isActive) {
      final confirmed = await showConfirmSheet(
        context,
        title: 'إخراج ${route.name} من الخدمة؟',
        message: [
          'لا تُنشأ له رحلات حتى تعيده إلى الخدمة.',
          if (route.studentCount > 0)
            'وتُزال عنه ${studentCount(route.studentCount)}، فتحتاج إلى '
                'تعيينهن على مسار آخر أو إعادتهن بعد إعادته.',
        ].join(' '),
        confirmLabel: 'إخراج من الخدمة',
        destructive: true,
        icon: HugeIcons.strokeRoundedRoute01,
        tone: Tone.error,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(
      () => _api.setRouteEnabled(route.id, !route.isActive),
      route.isActive ? 'أُخرج المسار من الخدمة' : 'أُعيد المسار إلى الخدمة',
    );
  }

  Future<void> _edit(AdminRoute route) async {
    final saved = await Navigator.of(context).push<AdminRoute>(
      MaterialPageRoute(builder: (_) => RouteFormScreen(route: route)),
    );
    if (saved != null && mounted) refreshAdminData(ref);
  }

  void _loadMore() =>
      ref.read(peopleDirectoryProvider(_students).notifier).loadMore();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(routeProvider(widget.routeId));
    final route = async.value;
    return Scaffold(
      appBar: const NdsAppBar(title: 'المسار'),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(routeProvider(widget.routeId)),
        ),
        data: (route) => PageBody(
          onRefresh: () async {
            refreshAdminData(ref);
            await ref.read(routeProvider(widget.routeId).future);
          },
          onNearEnd: _loadMore,
          children: [
            NdsGroup(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FeaturedIcon(
                  HugeIcons.strokeRoundedRoute01,
                  size: 64,
                  circle: true,
                  tone: route.isActive ? Tone.primary : Tone.neutral,
                ),
                Text(
                  route.name,
                  textAlign: TextAlign.center,
                  style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
                ),
                activeTag(route.isActive),
              ],
            ),
            if (!route.isActive)
              const NdsAlert(
                status: TagStatus.error,
                title: 'خارج الخدمة',
                description: 'لا تُنشأ له رحلات ولا يُعيَّن عليه أحد. أعده إلى الخدمة لاستخدامه.',
              ),
            TitledPanel(
              title: 'البيانات',
              child: KvList([
                KvEntry('الرمز', route.code == null ? '—' : ltr(route.code!)),
                KvEntry('المقر', route.branch?.name ?? '—'),
                KvEntry('الحافلة', route.bus?.label ?? 'بلا حافلة ثابتة'),
                KvEntry('المحطات', stopCount(route.stops.length)),
                KvEntry('الطالبات', studentsOn(route.studentCount)),
              ]),
            ),
            TitledPanel(
              title: 'المحطات بالترتيب',
              child: route.stops.isEmpty
                  ? const InlineNote(
                      'لا محطات بعد. عدّل المسار لإضافة الأحياء التي يمر بها.',
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: NdsColors.yellow600,
                    )
                  : NdsGroup(
                      children: [
                        for (final (index, stop) in route.stops.indexed)
                          StopRow(number: index + 1, name: stop.name),
                      ],
                    ),
            ),
            Section(
              title: 'الطالبات على المسار',
              trailing: route.isActive
                  ? TextButton.icon(
                      onPressed: _busy ? null : () => _addStudents(route),
                      icon: const AppIcon(
                        HugeIcons.strokeRoundedUserAdd01,
                        size: 18,
                      ),
                      label: const Text('إضافة طالبات'),
                    )
                  : null,
              children: _studentList(route),
            ),
          ],
        ),
      ),
      bottomNavigationBar: route == null
          ? null
          : NdsFooter(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _edit(route),
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedPencilEdit02,
                    size: 20,
                  ),
                  label: const Text('تعديل المسار'),
                ),
                OutlinedButton(
                  style: route.isActive ? NdsButtons.destructiveOutline : null,
                  onPressed: _busy ? null : () => _toggleEnabled(route),
                  child: Text(
                    route.isActive ? 'إخراج من الخدمة' : 'إعادة إلى الخدمة',
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _studentList(AdminRoute route) {
    final async = ref.watch(peopleDirectoryProvider(_students));
    return [
      if (route.studentCount > 10 || _search.isNotEmpty)
        SearchBox(
          hint: 'الاسم أو الرقم الجامعي أو الجوال',
          initial: _search,
          onSearch: (value) => setState(() => _search = value),
        ),
      ...async.when(
        skipLoadingOnReload: true,
        loading: () => const [LoadingView()],
        error: (_, _) => [
          ErrorView(
            onRetry: () => ref.invalidate(peopleDirectoryProvider(_students)),
          ),
        ],
        data: (paged) => [
          if (paged.items.isEmpty)
            MessageView(
              icon: HugeIcons.strokeRoundedUserGroup,
              title: _search.isEmpty ? 'لا طالبات على المسار' : 'لا توجد نتائج',
              message: _search.isEmpty && route.isActive
                  ? 'أضف الطالبات اللواتي يركبن هذا المسار.'
                  : null,
            )
          else ...[
            Text(
              shownOf(paged.items.length, paged.total, studentCount),
              style: NdsText.textSm.copyWith(color: Nds.textSecondary),
            ),
            for (final student in paged.items)
              PersonTile(
                person: student,
                showAssignment: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PersonDetailScreen(
                      personId: student.id,
                      role: PersonRole.student,
                    ),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'إزالة من المسار',
                  onPressed: _busy
                      ? null
                      : () => _removeStudent(route, student),
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedRemove01,
                    size: 20,
                    color: Nds.textError,
                  ),
                ),
              ),
          ],
          PagedFooter(paged: paged, onLoadMore: _loadMore),
        ],
      ),
    ];
  }
}

final _placeName = RegExp(r"^[\p{L}\p{M}\p{N}\s.'’()/-]+$", unicode: true);

/// Adds a route, or edits [route]; pops with the saved route.
class RouteFormScreen extends ConsumerStatefulWidget {
  final AdminRoute? route;

  const RouteFormScreen({super.key, this.route});

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.route?.name);
  late final _code = TextEditingController(text: widget.route?.code);
  late String? _branchId = widget.route?.branch?.id;
  late final List<Neighborhood> _stops = [...?widget.route?.stops];
  String? _codeError;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _changed {
    final route = widget.route;
    final before = route?.stops.map((stop) => stop.id).join(',') ?? '';
    return _name.text.trim() != (route?.name ?? '') ||
        _code.text.trim() != (route?.code ?? '') ||
        _branchId != route?.branch?.id ||
        _stops.map((stop) => stop.id).join(',') != before;
  }

  Future<void> _addStop() async {
    final hood = await Navigator.of(context).push<Neighborhood>(
      MaterialPageRoute(
        builder: (_) => PickNeighborhoodScreen(
          exclude: {for (final stop in _stops) stop.id},
        ),
      ),
    );
    if (hood != null && mounted) setState(() => _stops.add(hood));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });
    final editing = widget.route != null;
    final code = asciiDigits(_code.text.trim());
    try {
      final saved = await ref.read(adminApiProvider).saveRoute(
        widget.route?.id,
        {
          'name': _name.text.trim(),
          if (code.isNotEmpty) 'code': code else if (editing) 'code': null,
          if (_branchId != null)
            'branchId': _branchId
          else if (editing)
            'branchId': null,
          'stopIds': [for (final stop in _stops) stop.id],
        },
      );
      if (!mounted) return;
      _done = true;
      refreshAdminData(ref);
      showMessage(context, editing ? 'حُفظت التعديلات' : 'أُضيف المسار');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      if (apiErrorCode(error) == 'CODE_TAKEN') {
        setState(() => _codeError = 'مستخدم لمسار آخر');
      } else {
        showMessage(context, adminFailure(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLeave() async {
    final discard = await showConfirmSheet(
      context,
      title: 'تجاهل التغييرات؟',
      message: 'لن يُحفظ ما أدخلته.',
      confirmLabel: 'تجاهل التغييرات',
      cancelLabel: 'متابعة التعديل',
      destructive: true,
    );
    if (discard && mounted) {
      _done = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.route != null;
    final branches = ref.watch(branchesProvider).value ?? const [];
    return PopScope(
      canPop: _done || !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(title: editing ? 'تعديل المسار' : 'إضافة مسار'),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              NdsField(
                label: 'اسم المسار',
                controller: _name,
                hint: 'مثل: مسار الشمال 3',
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'مطلوب';
                  if (text.length > 100) return 'أطول من المسموح';
                  if (!_placeName.hasMatch(text)) {
                    return 'يُكتب بالحروف والأرقام فقط';
                  }
                  return null;
                },
              ),
              NdsField(
                label: 'الرمز (اختياري)',
                controller: _code,
                hint: 'مثل: R3',
                textDirection: TextDirection.ltr,
                errorText: _codeError,
                onChanged: (_) => setState(() => _codeError = null),
                validator: (value) =>
                    (value?.trim().length ?? 0) > 64 ? 'أطول من المسموح' : null,
              ),
              if (branches.isNotEmpty)
                NdsGroup(
                  children: [
                    Text(
                      'المقر',
                      style: NdsText.textSm.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Nds.textDefault,
                      ),
                    ),
                    NdsChoiceChips<String?>(
                      options: [
                        (null, 'بدون'),
                        for (final branch in branches) (branch.id, branch.name),
                      ],
                      selected: _branchId,
                      onSelected: (value) => setState(() => _branchId = value),
                    ),
                  ],
                ),
              StopsEditor(
                stops: _stops,
                onAdd: _addStop,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: [
            ElevatedButton(
              onPressed: _busy || (editing && !_changed) ? null : _save,
              child: Text(editing ? 'حفظ التعديلات' : 'إضافة المسار'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A route's stops in visiting order: add, move up or down, remove. Changes
/// [stops] in place and calls [onChanged].
class StopsEditor extends StatelessWidget {
  final List<Neighborhood> stops;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  const StopsEditor({
    super.key,
    required this.stops,
    required this.onAdd,
    required this.onChanged,
  });

  void _move(int index, int by) {
    final stop = stops.removeAt(index);
    stops.insert(index + by, stop);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'المحطات بالترتيب',
      trailing: TextButton.icon(
        onPressed: onAdd,
        icon: const AppIcon(HugeIcons.strokeRoundedAdd01, size: 18),
        label: const Text('إضافة محطة'),
      ),
      children: [
        if (stops.isEmpty)
          const InlineNote('أضف الأحياء التي يمر بها المسار بترتيب المرور.')
        else
          NdsPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: NdsGroup(
              gap: Space.sm,
              children: [
                for (final (index, stop) in stops.indexed)
                  StopRow(
                    number: index + 1,
                    name: stop.name,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تقديم',
                          onPressed: index == 0 ? null : () => _move(index, -1),
                          icon: const AppIcon(
                            HugeIcons.strokeRoundedArrowUp01,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: 'تأخير',
                          onPressed: index == stops.length - 1
                              ? null
                              : () => _move(index, 1),
                          icon: const AppIcon(
                            HugeIcons.strokeRoundedArrowDown01,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف المحطة',
                          onPressed: () {
                            stops.removeAt(index);
                            onChanged();
                          },
                          icon: const AppIcon(
                            HugeIcons.strokeRoundedCancel01,
                            size: 20,
                            color: Nds.textError,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
