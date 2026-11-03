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
import 'route_screens.dart';

/// One bus: its details, its driver and supervisor, editing it and taking it
/// out of service.
class BusDetailScreen extends ConsumerStatefulWidget {
  final String busId;

  const BusDetailScreen({super.key, required this.busId});

  @override
  ConsumerState<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends ConsumerState<BusDetailScreen> {
  bool _busy = false;

  AdminApi get _api => ref.read(adminApiProvider);

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

  Future<void> _pick(AdminBus bus, PersonRole role) async {
    final person = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PickPersonScreen(role: role, busId: bus.id),
      ),
    );
    if (person == null || !mounted) return;
    if (person.bus != null) {
      final confirmed = await showConfirmSheet(
        context,
        title: 'نقل ${person.fullName}؟',
        message:
            '${person.fullName} على ${person.bus!.label} الآن، '
            '${role.feminine ? 'وتُنقل' : 'ويُنقل'} إلى ${bus.label}.',
        confirmLabel: role.feminine ? 'نقلها' : 'نقله',
        icon: HugeIcons.strokeRoundedUserSwitch,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(
      () => _api.assignToBus(role, person.profileId, bus.id),
      '${role.feminine ? 'عُيّنت' : 'عُيّن'} ${person.fullName} على ${bus.label}',
    );
  }

  Future<void> _remove(AdminBus bus, PersonRole role, StaffRef staff) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'إزالة ${staff.fullName} من ${bus.label}؟',
      message:
          'تبقى الحافلة بلا ${role.singular} حتى تعيّن '
          '${role.feminine ? 'غيرها' : 'غيره'}.',
      confirmLabel: 'إزالة',
      destructive: true,
      icon: HugeIcons.strokeRoundedRemove01,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => _api.unassignFromBus(role, bus.id),
      '${role.feminine ? 'أُزيلت' : 'أُزيل'} ${staff.fullName}',
    );
  }

  Future<void> _toggleEnabled(AdminBus bus) async {
    if (bus.isActive) {
      final staff = [
        if (bus.driver != null) bus.driver!.fullName,
        if (bus.supervisor != null) bus.supervisor!.fullName,
      ];
      final confirmed = await showConfirmSheet(
        context,
        title: 'إخراج ${bus.label} من الخدمة؟',
        message: [
          'لا تُختار للرحلات ولا للتعيين حتى تعيدها إلى الخدمة.',
          if (staff.isNotEmpty) 'ويُزال عنها ${staff.join(' و')}.',
        ].join(' '),
        confirmLabel: 'إخراج من الخدمة',
        destructive: true,
        icon: HugeIcons.strokeRoundedBus01,
        tone: Tone.error,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(
      () => _api.setBusEnabled(bus.id, !bus.isActive),
      bus.isActive ? 'أُخرجت الحافلة من الخدمة' : 'أُعيدت الحافلة إلى الخدمة',
    );
  }

  Future<void> _pickRoute(AdminBus bus) async {
    final route = await Navigator.of(context).push<AdminRoute>(
      MaterialPageRoute(
        builder: (_) =>
            PickRouteScreen(currentId: bus.route?.id, forBusId: bus.id),
      ),
    );
    if (route == null || !mounted) return;
    await _run(
      () => _api.saveBus(bus.id, {'routeId': route.id}),
      'أصبح ${route.name} المسار الثابت لـ${bus.label}',
    );
  }

  Future<void> _clearRoute(AdminBus bus) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'إلغاء المسار الثابت؟',
      message:
          'لن تُنشأ رحلات ${bus.label} تلقائياً، ويُذكَّر سائقها بإنشائها كل '
          'صباح.',
      confirmLabel: 'إلغاء المسار الثابت',
      destructive: true,
      icon: HugeIcons.strokeRoundedRoute01,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => _api.saveBus(bus.id, {'routeId': null}),
      'أُلغي المسار الثابت',
    );
  }

  Widget _routePanel(AdminBus bus) {
    final route = bus.route;
    if (!bus.isActive) {
      return const TitledPanel(
        title: 'المسار الثابت',
        child: InlineNote('أعد الحافلة إلى الخدمة لتحديد مسارها.'),
      );
    }
    return TitledPanel(
      title: 'المسار الثابت',
      child: NdsGroup(
        children: [
          if (route == null)
            const InlineNote(
              'بلا مسار ثابت، فلا تُنشأ رحلاتها تلقائياً؛ يُنشئها سائقها.',
              icon: HugeIcons.strokeRoundedAlert02,
              color: NdsColors.yellow600,
            )
          else
            NdsListItem(
              leading: const FeaturedIcon(HugeIcons.strokeRoundedRoute01),
              title: route.name,
              meta: 'تُنشأ رحلتا الذهاب والعودة عليه كل يوم دراسي',
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RouteDetailScreen(routeId: route.id),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: NdsButtons.compact,
                  onPressed: _busy ? null : () => _pickRoute(bus),
                  icon: AppIcon(
                    route == null
                        ? HugeIcons.strokeRoundedAdd01
                        : HugeIcons.strokeRoundedExchange01,
                    size: 18,
                  ),
                  label: Text(route == null ? 'تحديد المسار' : 'تغيير'),
                ),
              ),
              if (route != null) ...[
                const SizedBox(width: Space.md),
                Expanded(
                  child: OutlinedButton(
                    style: NdsButtons.compact.merge(
                      NdsButtons.destructiveOutline,
                    ),
                    onPressed: _busy ? null : () => _clearRoute(bus),
                    child: const Text('إلغاء'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(AdminBus bus) async {
    final saved = await Navigator.of(context).push<AdminBus>(
      MaterialPageRoute(builder: (_) => BusFormScreen(bus: bus)),
    );
    if (saved != null && mounted) refreshAdminData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(busProvider(widget.busId));
    final bus = async.value;
    return Scaffold(
      appBar: const NdsAppBar(title: 'الحافلة'),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(busProvider(widget.busId))),
        data: (bus) => PageBody(
          onRefresh: () async {
            ref.invalidate(busProvider(widget.busId));
            await ref.read(busProvider(widget.busId).future);
          },
          children: [
            NdsGroup(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FeaturedIcon(
                  HugeIcons.strokeRoundedBus01,
                  size: 64,
                  circle: true,
                  tone: bus.isActive ? Tone.primary : Tone.neutral,
                ),
                Text(
                  bus.label,
                  textAlign: TextAlign.center,
                  style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
                ),
                activeTag(bus.isActive),
              ],
            ),
            if (!bus.isActive)
              const NdsAlert(
                status: TagStatus.error,
                title: 'خارج الخدمة',
                description: 'لا تُختار للرحلات ولا للتعيين. أعدها إلى الخدمة لاستخدامها.',
              ),
            TitledPanel(
              title: 'البيانات',
              child: KvList([
                KvEntry('رقم اللوحة', ltr(bus.plateNumber)),
                if (bus.name != null) KvEntry('الاسم', bus.name!),
                KvEntry(
                  'السعة',
                  bus.capacity == null ? 'غير محددة' : seatCount(bus.capacity!),
                ),
              ]),
            ),
            _routePanel(bus),
            _staffPanel(bus, PersonRole.driver, bus.driver),
            _staffPanel(bus, PersonRole.supervisor, bus.supervisor),
          ],
        ),
      ),
      bottomNavigationBar: bus == null
          ? null
          : NdsFooter(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _edit(bus),
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedPencilEdit02,
                    size: 20,
                  ),
                  label: const Text('تعديل البيانات'),
                ),
                OutlinedButton(
                  style: bus.isActive ? NdsButtons.destructiveOutline : null,
                  onPressed: _busy ? null : () => _toggleEnabled(bus),
                  child: Text(
                    bus.isActive ? 'إخراج من الخدمة' : 'إعادة إلى الخدمة',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _staffPanel(AdminBus bus, PersonRole role, StaffRef? staff) {
    final title = role == PersonRole.driver ? 'السائق' : 'المشرفة';
    if (!bus.isActive) {
      return TitledPanel(
        title: title,
        child: const InlineNote('أعد الحافلة إلى الخدمة للتعيين عليها.'),
      );
    }
    return TitledPanel(
      title: title,
      child: NdsGroup(
        children: [
          if (staff == null)
            InlineNote(
              role == PersonRole.driver
                  ? 'لا سائق لهذه الحافلة، فلا تُنشأ لها رحلات.'
                  : 'لا مشرفة لهذه الحافلة.',
              icon: HugeIcons.strokeRoundedAlert02,
              color: NdsColors.yellow600,
            )
          else
            NdsListItem(
              leading: InitialsAvatar(staff.fullName),
              title: staff.fullName,
              titleBadge: staff.isActive
                  ? null
                  : NdsTag(role.disabledLabel, status: TagStatus.error),
              meta: staff.phone.isEmpty ? null : ltr(localPhone(staff.phone)),
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PersonDetailScreen(personId: staff.id, role: role),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: NdsButtons.compact,
                  onPressed: _busy ? null : () => _pick(bus, role),
                  icon: AppIcon(
                    staff == null
                        ? HugeIcons.strokeRoundedAdd01
                        : HugeIcons.strokeRoundedExchange01,
                    size: 18,
                  ),
                  label: Text(
                    staff == null ? 'تعيين ${role.singular}' : 'تغيير',
                  ),
                ),
              ),
              if (staff != null) ...[
                const SizedBox(width: Space.md),
                Expanded(
                  child: OutlinedButton(
                    style: NdsButtons.compact.merge(
                      NdsButtons.destructiveOutline,
                    ),
                    onPressed: _busy ? null : () => _remove(bus, role, staff),
                    child: const Text('إزالة'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds a bus, or edits [bus]; pops with the saved bus.
class BusFormScreen extends ConsumerStatefulWidget {
  final AdminBus? bus;

  const BusFormScreen({super.key, this.bus});

  @override
  ConsumerState<BusFormScreen> createState() => _BusFormScreenState();
}

class _BusFormScreenState extends ConsumerState<BusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _plate = TextEditingController(text: widget.bus?.plateNumber);
  late final _name = TextEditingController(text: widget.bus?.name);
  late final _capacity = TextEditingController(
    text: widget.bus?.capacity?.toString(),
  );
  String? _plateError;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _plate.dispose();
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  bool get _changed {
    final bus = widget.bus;
    return _plate.text.trim() != (bus?.plateNumber ?? '') ||
        _name.text.trim() != (bus?.name ?? '') ||
        asciiDigits(_capacity.text.trim()) != (bus?.capacity?.toString() ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _plateError = null;
    });
    final name = _name.text.trim();
    final capacity = asciiDigits(_capacity.text.trim());
    final editing = widget.bus != null;
    try {
      final saved = await ref.read(adminApiProvider).saveBus(widget.bus?.id, {
        'plateNumber': asciiDigits(_plate.text.trim()),
        if (name.isNotEmpty) 'name': name else if (editing) 'name': null,
        if (capacity.isNotEmpty)
          'capacity': int.parse(capacity)
        else if (editing)
          'capacity': null,
      });
      if (!mounted) return;
      _done = true;
      refreshAdminData(ref);
      showMessage(context, editing ? 'حُفظت التعديلات' : 'أُضيفت الحافلة');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      if (apiErrorCode(error) == 'PLATE_TAKEN') {
        setState(() => _plateError = 'مسجّل لحافلة أخرى');
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
    final editing = widget.bus != null;
    return PopScope(
      canPop: _done || !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(title: editing ? 'تعديل الحافلة' : 'إضافة حافلة'),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              NdsField(
                label: 'رقم اللوحة',
                controller: _plate,
                hint: 'ABC 1234',
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                errorText: _plateError,
                onChanged: (_) => setState(() => _plateError = null),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'مطلوب';
                  if (text.length > 32) return 'أطول من المسموح';
                  return null;
                },
              ),
              NdsField(
                label: 'اسم الحافلة (اختياري)',
                controller: _name,
                hint: 'مثل: حافلة 12',
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    (value?.trim().length ?? 0) > 64 ? 'أطول من المسموح' : null,
              ),
              NdsField(
                label: 'عدد المقاعد (اختياري)',
                controller: _capacity,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = asciiDigits(value?.trim() ?? '');
                  if (text.isEmpty) return null;
                  final seats = int.tryParse(text);
                  return seats == null || seats < 1 || seats > 200
                      ? 'رقم من 1 إلى 200'
                      : null;
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: [
            ElevatedButton(
              onPressed: _busy || (editing && !_changed) ? null : _save,
              child: Text(editing ? 'حفظ التعديلات' : 'إضافة الحافلة'),
            ),
          ],
        ),
      ),
    );
  }
}
