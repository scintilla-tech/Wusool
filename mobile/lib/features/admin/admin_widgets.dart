import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_api.dart';
import 'people.dart';

/// Search field that reports what was typed once the admin pauses typing.
class SearchBox extends StatefulWidget {
  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> onSearch;

  const SearchBox({
    super.key,
    this.label = 'البحث',
    required this.hint,
    this.initial = '',
    required this.onSearch,
  });

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final _controller = TextEditingController(text: widget.initial);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 350),
      () => widget.onSearch(asciiDigits(value.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NdsField(
      label: widget.label,
      controller: _controller,
      icon: HugeIcons.strokeRoundedSearch01,
      hint: widget.hint,
      textInputAction: TextInputAction.search,
      onChanged: _changed,
      onFieldSubmitted: (value) {
        _timer?.cancel();
        widget.onSearch(asciiDigits(value.trim()));
      },
    );
  }
}

/// The end of a paged list: loading, a retry after a failure, or a button to
/// load more when scrolling did not.
class PagedFooter extends StatelessWidget {
  final Paged<Object?> paged;
  final VoidCallback onLoadMore;

  const PagedFooter({super.key, required this.paged, required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    if (paged.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (paged.moreError != null) {
      return NdsGroup(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'تعذّر تحميل المزيد',
            style: NdsText.textSm.copyWith(color: Nds.textError),
          ),
          OutlinedButton.icon(
            style: NdsButtons.compact,
            onPressed: onLoadMore,
            icon: const AppIcon(HugeIcons.strokeRoundedRefresh, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }
    if (!paged.hasMore) return const SizedBox.shrink();
    return Center(
      child: OutlinedButton(
        style: NdsButtons.compact,
        onPressed: onLoadMore,
        child: const Text('عرض المزيد'),
      ),
    );
  }
}

/// "يعرض 30 من أصل 120 طالبة", or the count alone when all are shown.
String shownOf(int shown, int total, String Function(int) count) =>
    shown < total ? 'يعرض $shown من أصل ${count(total)}' : count(total);

NdsTag personStatusTag(Person person) {
  final role = person.role;
  if (!person.isActive) {
    return NdsTag(role.disabledLabel, status: TagStatus.error);
  }
  if (!person.isActivated) {
    return const NdsTag('بانتظار التفعيل', status: TagStatus.warning);
  }
  return NdsTag(role.activeLabel, status: TagStatus.success);
}

/// "المسار: North Loop", "بدون حافلة"... or null for field supervisors.
String? assignmentLine(Person person) {
  switch (person.role) {
    case PersonRole.student:
      return person.route == null
          ? 'بدون مسار'
          : 'المسار: ${person.route!.name}';
    case PersonRole.driver:
    case PersonRole.supervisor:
      return person.bus == null
          ? 'بدون حافلة'
          : 'الحافلة: ${person.bus!.label}';
    case PersonRole.fieldSupervisor:
      return null;
  }
}

class PersonTile extends StatelessWidget {
  final Person person;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAssignment;

  const PersonTile({
    super.key,
    required this.person,
    this.onTap,
    this.trailing,
    this.showAssignment = true,
  });

  @override
  Widget build(BuildContext context) {
    final number = person.number;
    final assignment = showAssignment ? assignmentLine(person) : null;
    return NdsListItem(
      leading: InitialsAvatar(person.fullName),
      title: person.fullName,
      titleBadge: personStatusTag(person),
      meta: number == null
          ? null
          : '${person.role.idField.label}: ${ltr(number)}',
      meta2: [ltr(localPhone(person.phone)), ?assignment].join(' · '),
      trailing: trailing,
      chevron: onTap != null && trailing == null,
      onTap: onTap,
    );
  }
}

NdsTag activeTag(bool isActive) => NdsTag(
  isActive ? 'في الخدمة' : 'معطّلة',
  status: isActive ? TagStatus.success : TagStatus.error,
);

class BusTile extends StatelessWidget {
  final AdminBus bus;
  final VoidCallback? onTap;
  final Widget? trailing;

  const BusTile({super.key, required this.bus, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return NdsListItem(
      leading: FeaturedIcon(
        HugeIcons.strokeRoundedBus01,
        tone: bus.isActive ? Tone.primary : Tone.neutral,
      ),
      title: bus.label,
      titleBadge: activeTag(bus.isActive),
      meta: [
        if (bus.name != null) ltr(bus.plateNumber),
        if (bus.capacity != null) seatCount(bus.capacity!),
        bus.route == null ? 'بلا مسار ثابت' : bus.route!.name,
      ].join(' · '),
      meta2: [
        bus.driver == null ? 'بدون سائق' : 'السائق: ${bus.driver!.fullName}',
        bus.supervisor == null
            ? 'بدون مشرفة'
            : 'المشرفة: ${bus.supervisor!.fullName}',
      ].join(' · '),
      trailing: trailing,
      chevron: onTap != null && trailing == null,
      onTap: onTap,
    );
  }
}

class RouteTile extends StatelessWidget {
  final AdminRoute route;
  final VoidCallback? onTap;
  final Widget? trailing;

  const RouteTile({super.key, required this.route, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return NdsListItem(
      leading: FeaturedIcon(
        HugeIcons.strokeRoundedRoute01,
        tone: route.isActive ? Tone.primary : Tone.neutral,
      ),
      title: route.name,
      titleBadge: route.isActive ? null : activeTag(false),
      meta: [
        if (route.code != null) ltr(route.code!),
        if (route.stops.isNotEmpty) stopCount(route.stops.length),
        studentsOn(route.studentCount),
      ].join(' · '),
      meta2: route.stops.isEmpty ? 'لا محطات بعد' : route.stopsLine,
      trailing: trailing,
      chevron: onTap != null && trailing == null,
      onTap: onTap,
    );
  }
}

/// Bottom sheet framing a short list of choices, with a title.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext sheetContext) children,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Nds.backgroundDefault,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
  ),
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.x2l,
        Space.xl,
        Space.x3l,
      ),
      child: NdsGroup(
        gap: Space.lg,
        children: [
          Text(
            title,
            style: NdsText.textXl.copyWith(
              fontWeight: FontWeight.w600,
              color: Nds.textDisplay,
            ),
          ),
          ...children(sheetContext),
        ],
      ),
    ),
  ),
);
