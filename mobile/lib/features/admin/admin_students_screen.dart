import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_providers.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  final _search = TextEditingController();
  String _filter = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AdminStudentRow student) {
    if (_filter == 'ACTIVE' && !student.isActive) return false;
    if (_filter == 'INACTIVE' && student.isActive) return false;
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      '${student.firstName} ${student.lastName}',
      student.studentId,
      student.phone,
    ].nonNulls.any((value) => value.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminStudentsProvider);

    return Scaffold(
      appBar: const NdsAppBar(title: 'دليل الطالبات'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(adminStudentsProvider)),
        data: (students) {
          final shown = students.where(_matches).toList();
          return PageBody(
            onRefresh: () async {
              ref.invalidate(adminStudentsProvider);
              await ref.read(adminStudentsProvider.future);
            },
            children: [
              NdsField(
                label: 'البحث عن طالبة',
                controller: _search,
                icon: HugeIcons.strokeRoundedSearch01,
                hint: 'الاسم أو الرقم الجامعي أو الجوال',
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
              NdsChoiceChips<String>(
                options: const [
                  ('ALL', 'الكل'),
                  ('ACTIVE', 'نشطة'),
                  ('INACTIVE', 'معطّلة'),
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              Text(
                studentCount(shown.length),
                style: NdsText.textSm.copyWith(color: Nds.textSecondary),
              ),
              if (shown.isEmpty)
                const MessageView(
                  icon: HugeIcons.strokeRoundedSearch01,
                  title: 'لا توجد نتائج',
                  message: 'جرّب كلمة بحث أخرى أو غيّر التصفية.',
                )
              else
                NdsGroup(
                  children: [
                    for (final student in shown)
                      NdsListItem(
                        leading: InitialsAvatar(
                          '${student.firstName} ${student.lastName}',
                        ),
                        title: '${student.firstName} ${student.lastName}',
                        titleBadge: NdsTag(
                          student.isActive ? 'نشطة' : 'معطّلة',
                          status: student.isActive
                              ? TagStatus.success
                              : TagStatus.error,
                        ),
                        meta: student.studentId == null
                            ? null
                            : 'الرقم الجامعي: ${ltr(student.studentId!)}',
                        meta2: ltr(student.phone),
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
