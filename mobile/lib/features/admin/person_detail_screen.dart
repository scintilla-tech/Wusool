import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'bus_screens.dart';
import 'people.dart';
import 'person_form_screen.dart';
import 'pickers.dart';
import 'route_screens.dart';

/// One student or staff member: details, their route or bus, and editing or
/// disabling the account.
class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;
  final PersonRole role;

  const PersonDetailScreen({
    super.key,
    required this.personId,
    required this.role,
  });

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  bool _busy = false;

  AdminApi get _api => ref.read(adminApiProvider);

  /// Runs [action], then reloads everything that shows people.
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

  Future<void> _edit(PersonDetail person) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen.edit(
          person.role,
          personId: person.id,
          initial: person.row,
        ),
      ),
    );
    if (saved == true && mounted) refreshAdminData(ref);
  }

  Future<void> _toggleEnabled(PersonDetail person) async {
    final role = person.role;
    if (person.isActive) {
      final verb = role.feminine ? 'تتمكن' : 'يتمكن';
      final off = switch ((role, person.route, person.bus)) {
        (PersonRole.student, final RouteRef route?, _) =>
          ' وتُزال من مسار ${route.name}',
        (_, _, final BusRef bus?) =>
          ' ${role.feminine ? 'وتُزال' : 'ويُزال'} من الحافلة ${bus.label}',
        _ => '',
      };
      final confirmed = await showConfirmSheet(
        context,
        title: 'تعطيل حساب ${person.fullName}؟',
        message: 'لن $verb من تسجيل الدخول$off. يمكنك إلغاء التعطيل في أي وقت.',
        confirmLabel: 'تعطيل الحساب',
        destructive: true,
        icon: HugeIcons.strokeRoundedUserBlock01,
        tone: Tone.error,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(
      () => _api.setPersonEnabled(person.id, !person.isActive),
      person.isActive ? 'عُطِّل الحساب' : 'أُلغي تعطيل الحساب',
    );
  }

  Future<void> _assign(PersonDetail person) async {
    if (person.role.isStudent) {
      final route = await Navigator.of(context).push<AdminRoute>(
        MaterialPageRoute(
          builder: (_) => PickRouteScreen(currentId: person.route?.id),
        ),
      );
      if (route == null || !mounted) return;
      await _run(
        () => _api.assignStudents(route.id, [person.profileId]),
        person.route == null
            ? 'عُيّنت ${person.fullName} على ${route.name}'
            : 'نُقلت ${person.fullName} إلى ${route.name}',
      );
      return;
    }
    final bus = await Navigator.of(context).push<AdminBus>(
      MaterialPageRoute(
        builder: (_) =>
            PickBusScreen(role: person.role, currentId: person.bus?.id),
      ),
    );
    if (bus == null || !mounted) return;
    final current = person.role == PersonRole.driver
        ? bus.driver
        : bus.supervisor;
    if (current != null && current.id != person.id) {
      final confirmed = await showConfirmSheet(
        context,
        title: 'استبدال ${current.fullName}؟',
        message:
            '${current.fullName} على ${bus.label} الآن، '
            '${person.role.feminine ? 'وتُزال' : 'ويُزال'} منها عند تعيين '
            '${person.fullName}.',
        confirmLabel: 'تعيين ${person.fullName}',
        icon: HugeIcons.strokeRoundedUserSwitch,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(
      () => _api.assignToBus(person.role, person.profileId, bus.id),
      '${person.role.feminine ? 'عُيّنت' : 'عُيّن'} ${person.fullName} على ${bus.label}',
    );
  }

  Future<void> _unassign(PersonDetail person) async {
    final place = person.role.isStudent
        ? 'مسار ${person.route!.name}'
        : 'الحافلة ${person.bus!.label}';
    final confirmed = await showConfirmSheet(
      context,
      title: 'إزالة ${person.fullName} من $place؟',
      message: person.role.isStudent
          ? 'لن تظهر في قائمة الحافلة حتى تُعيَّن على مسار آخر.'
          : 'تبقى الحافلة بلا ${person.role.singular} حتى تعيّن '
                '${person.role.feminine ? 'غيرها' : 'غيره'}.',
      confirmLabel: 'إزالة',
      destructive: true,
      icon: HugeIcons.strokeRoundedRemove01,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => person.role.isStudent
          ? _api.unassignStudent(person.profileId)
          : _api.unassignFromBus(person.role, person.bus!.id),
      '${person.role.feminine ? 'أُزيلت' : 'أُزيل'} ${person.fullName} من $place',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(personProvider(widget.personId));
    return Scaffold(
      appBar: NdsAppBar(title: widget.role.singular),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(personProvider(widget.personId)),
        ),
        data: (person) => PageBody(
          onRefresh: () async {
            ref.invalidate(personProvider(widget.personId));
            await ref.read(personProvider(widget.personId).future);
          },
          children: _content(person),
        ),
      ),
      bottomNavigationBar: async.value == null ? null : _footer(async.value!),
    );
  }

  List<Widget> _content(PersonDetail person) {
    final role = person.role;
    final labels = {for (final f in role.fields) f.key: f};
    return [
      ProfileHeader(
        name: person.fullName,
        meta: person.number == null
            ? role.singular
            : '${role.singular} · ${role.idField.label} ${ltr(person.number!)}',
      ),
      Center(child: personStatusTag(person)),
      if (!person.isActive)
        NdsAlert(
          status: TagStatus.error,
          title: 'الحساب معطّل',
          description:
              'لا ${role.feminine ? 'تستطيع' : 'يستطيع'} تسجيل الدخول. '
              'ألغِ التعطيل لإعادة الوصول.',
        )
      else if (!person.isActivated)
        NdsAlert(
          status: TagStatus.warning,
          title: 'بانتظار التفعيل',
          description:
              'لم ${role.feminine ? 'تسجّل' : 'يسجّل'} الدخول بعد. يصل رمز '
              'تحقق إلى ${ltr(localPhone(person.phone))} عند أول دخول لتعيين '
              'كلمة المرور.',
        ),
      TitledPanel(
        title: 'البيانات',
        child: KvList([
          for (final MapEntry(:key, :value) in person.row.entries)
            if (labels[key] != null)
              KvEntry(
                labels[key]!.label,
                labels[key]!.ltr ? ltr(value) : value,
              ),
        ]),
      ),
      if (role != PersonRole.fieldSupervisor) _assignment(person),
    ];
  }

  Widget _assignment(PersonDetail person) {
    final student = person.role.isStudent;
    final title = student ? 'المسار' : 'الحافلة';
    final Widget? current = switch ((person.route, person.bus)) {
      (final RouteRef route?, _) => NdsListItem(
        leading: const FeaturedIcon(HugeIcons.strokeRoundedRoute01),
        title: route.name,
        titleBadge: route.isActive ? null : activeTag(false),
        meta: route.code == null ? null : ltr(route.code!),
        chevron: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RouteDetailScreen(routeId: route.id),
          ),
        ),
      ),
      (_, final BusRef bus?) => NdsListItem(
        leading: const FeaturedIcon(HugeIcons.strokeRoundedBus01),
        title: bus.label,
        meta: bus.name == null ? null : ltr(bus.plateNumber),
        chevron: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BusDetailScreen(busId: bus.id),
          ),
        ),
      ),
      _ => null,
    };

    if (!person.isActive) {
      return TitledPanel(
        title: title,
        child: InlineNote(
          student
              ? 'ألغِ تعطيل الحساب لتعيينها على مسار.'
              : 'ألغِ تعطيل الحساب لتعيين ${person.role.feminine ? 'ها' : 'ه'} على حافلة.',
        ),
      );
    }

    return TitledPanel(
      title: title,
      child: NdsGroup(
        children: [
          current ??
              InlineNote(
                student
                    ? 'لم تُعيَّن على مسار بعد، فلا تظهر في أي رحلة.'
                    : 'لم ${person.role.feminine ? 'تُعيَّن' : 'يُعيَّن'} على حافلة بعد.',
                icon: HugeIcons.strokeRoundedAlert02,
                color: NdsColors.yellow600,
              ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: NdsButtons.compact,
                  onPressed: _busy ? null : () => _assign(person),
                  icon: AppIcon(
                    current == null
                        ? HugeIcons.strokeRoundedAdd01
                        : HugeIcons.strokeRoundedExchange01,
                    size: 18,
                  ),
                  label: Text(
                    current == null
                        ? (student ? 'تعيين مسار' : 'تعيين حافلة')
                        : (student ? 'تغيير المسار' : 'تغيير الحافلة'),
                  ),
                ),
              ),
              if (current != null) ...[
                const SizedBox(width: Space.md),
                Expanded(
                  child: OutlinedButton(
                    style: NdsButtons.compact.merge(
                      NdsButtons.destructiveOutline,
                    ),
                    onPressed: _busy ? null : () => _unassign(person),
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

  Widget _footer(PersonDetail person) {
    return NdsFooter(
      children: [
        ElevatedButton.icon(
          onPressed: _busy ? null : () => _edit(person),
          icon: const AppIcon(HugeIcons.strokeRoundedPencilEdit02, size: 20),
          label: const Text('تعديل البيانات'),
        ),
        person.isActive
            ? OutlinedButton.icon(
                style: NdsButtons.destructiveOutline,
                onPressed: _busy ? null : () => _toggleEnabled(person),
                icon: const AppIcon(
                  HugeIcons.strokeRoundedUserBlock01,
                  size: 20,
                ),
                label: const Text('تعطيل الحساب'),
              )
            : OutlinedButton.icon(
                onPressed: _busy ? null : () => _toggleEnabled(person),
                icon: const AppIcon(
                  HugeIcons.strokeRoundedUserCheck01,
                  size: 20,
                ),
                label: const Text('إلغاء التعطيل'),
              ),
      ],
    );
  }
}
