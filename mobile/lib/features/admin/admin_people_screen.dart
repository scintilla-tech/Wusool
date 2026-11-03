import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'add_people.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'people.dart';
import 'people_api.dart';
import 'person_detail_screen.dart';

/// A directory of one or more roles (students, or the three staff roles):
/// search, filters, saved drafts, and adding people. Loads page by page.
class AdminPeopleScreen extends ConsumerStatefulWidget {
  final String title;
  final List<PersonRole> roles;

  const AdminPeopleScreen({
    super.key,
    required this.title,
    required this.roles,
  });

  const AdminPeopleScreen.students({super.key})
    : title = 'دليل الطالبات',
      roles = const [PersonRole.student];

  const AdminPeopleScreen.staff({super.key})
    : title = 'الموظفون',
      roles = const [
        PersonRole.driver,
        PersonRole.supervisor,
        PersonRole.fieldSupervisor,
      ];

  @override
  ConsumerState<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends ConsumerState<AdminPeopleScreen> {
  late PersonRole _role = widget.roles.first;
  String _search = '';
  PersonStatus _status = PersonStatus.all;

  PeopleQuery get _query =>
      peopleQuery(_role, search: _search, status: _status);

  Future<void> _refresh() async {
    ref.invalidate(peopleDirectoryProvider(_query));
    ref.invalidate(peopleDraftsProvider(_role));
    await ref.read(peopleDirectoryProvider(_query).future);
  }

  void _loadMore() =>
      ref.read(peopleDirectoryProvider(_query).notifier).loadMore();

  @override
  Widget build(BuildContext context) {
    final role = _role;
    final async = ref.watch(peopleDirectoryProvider(_query));

    return Scaffold(
      appBar: NdsAppBar(
        title: widget.title,
        trailing: CircleIconButton(
          icon: HugeIcons.strokeRoundedUserAdd01,
          tooltip: 'إضافة ${role.plural}',
          onPressed: () => showAddPeopleSheet(context, ref, role),
        ),
      ),
      body: PageBody(
        onRefresh: _refresh,
        onNearEnd: _loadMore,
        children: [
          if (widget.roles.length > 1)
            NdsChoiceChips<PersonRole>(
              options: [for (final r in widget.roles) (r, r.plural)],
              selected: role,
              onSelected: (value) => setState(() {
                _role = value;
                if (value == PersonRole.fieldSupervisor &&
                    _status == PersonStatus.unassigned) {
                  _status = PersonStatus.all;
                }
              }),
            ),
          DraftsSection(role: role),
          SearchBox(
            key: ValueKey('search-${role.api}'),
            initial: _search,
            hint: role.isStudent
                ? 'الاسم أو الرقم الجامعي أو الجوال'
                : 'الاسم أو الرقم الوظيفي أو الجوال',
            onSearch: (value) => setState(() => _search = value),
          ),
          ...async.when(
            skipLoadingOnReload: true,
            loading: () => const [LoadingView()],
            error: (_, _) => [
              ErrorView(
                onRetry: () => ref.invalidate(peopleDirectoryProvider(_query)),
              ),
            ],
            data: (paged) => _list(role, paged),
          ),
        ],
      ),
    );
  }

  List<Widget> _list(PersonRole role, Paged<Person> paged) {
    final everyone = paged.count(PersonStatus.all);
    if (everyone == 0 && _search.isEmpty) {
      return [
        MessageView(
          icon: HugeIcons.strokeRoundedUserGroup,
          title: 'لا يوجد ${role.plural} بعد',
          message: 'أضفهم واحداً واحداً، أو دفعة واحدة من ملف Excel أو CSV.',
          action: ElevatedButton.icon(
            onPressed: () => showAddPeopleSheet(context, ref, role),
            icon: const AppIcon(HugeIcons.strokeRoundedUserAdd01, size: 20),
            label: Text('إضافة ${role.plural}'),
          ),
        ),
      ];
    }

    String chip(PersonStatus status, String label) =>
        '$label ${paged.count(status)}';
    return [
      NdsChoiceChips<PersonStatus>(
        options: [
          (PersonStatus.all, chip(PersonStatus.all, 'الكل')),
          (PersonStatus.active, chip(PersonStatus.active, role.activeLabel)),
          (PersonStatus.pending, chip(PersonStatus.pending, 'بانتظار التفعيل')),
          (
            PersonStatus.disabled,
            chip(PersonStatus.disabled, role.disabledLabel),
          ),
          if (role != PersonRole.fieldSupervisor)
            (
              PersonStatus.unassigned,
              chip(
                PersonStatus.unassigned,
                role.isStudent ? 'بدون مسار' : 'بدون حافلة',
              ),
            ),
        ],
        selected: _status,
        onSelected: (value) => setState(() => _status = value),
      ),
      Text(
        shownOf(paged.items.length, paged.total, role.count),
        style: NdsText.textSm.copyWith(color: Nds.textSecondary),
      ),
      if (paged.items.isEmpty)
        const MessageView(
          icon: HugeIcons.strokeRoundedSearch01,
          title: 'لا توجد نتائج',
          message: 'جرّب كلمة بحث أخرى أو غيّر التصفية.',
        )
      else
        NdsGroup(
          children: [
            for (final person in paged.items)
              PersonTile(
                person: person,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PersonDetailScreen(personId: person.id, role: role),
                  ),
                ),
              ),
          ],
        ),
      PagedFooter(paged: paged, onLoadMore: _loadMore),
    ];
  }
}
