import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'people.dart';
import 'people_api.dart';
import 'people_list_screen.dart';
import 'person_form_screen.dart';

const _maxFileBytes = 2 * 1024 * 1024;

/// How to add people of [role]: one by one, from a spreadsheet, or by first
/// downloading the blank template.
Future<void> showAddPeopleSheet(
  BuildContext context,
  WidgetRef ref,
  PersonRole role,
) async {
  final choice = await showModalBottomSheet<_AddChoice>(
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
              'إضافة ${role.plural}',
              style: NdsText.textXl.copyWith(
                fontWeight: FontWeight.w600,
                color: Nds.textDisplay,
              ),
            ),
            NdsListItem(
              leading: const FeaturedIcon(HugeIcons.strokeRoundedUserAdd01),
              title: role.addOneLabel,
              meta: 'إدخال البيانات في نموذج',
              chevron: true,
              onTap: () => Navigator.pop(sheetContext, _AddChoice.one),
            ),
            NdsListItem(
              leading: const FeaturedIcon(HugeIcons.strokeRoundedFileImport),
              title: 'استيراد من ملف Excel أو CSV',
              meta: 'لإضافة عدد كبير دفعة واحدة، حتى 1000 في الملف',
              chevron: true,
              onTap: () => Navigator.pop(sheetContext, _AddChoice.file),
            ),
            NdsListItem(
              leading: const FeaturedIcon(
                HugeIcons.strokeRoundedFileDownload,
                tone: Tone.neutral,
              ),
              title: 'تنزيل النموذج',
              meta: 'ملف بالأعمدة المطلوبة يُفتح في Excel',
              chevron: true,
              onTap: () => Navigator.pop(sheetContext, _AddChoice.template),
            ),
            const InlineNote(
              'لا حاجة لكلمات مرور: عند أول دخول يصل رمز تحقق إلى رقم الجوال '
              'المسجّل لتعيين كلمة المرور.',
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _AddChoice.one:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PersonFormScreen.add(role)),
      );
    case _AddChoice.file:
      await _importFile(context, role);
    case _AddChoice.template:
      final opened = await launchUrl(
        ref.read(peopleApiProvider).templateUri(role),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        showMessage(context, 'تعذّر فتح النموذج', error: true);
      }
  }
}

enum _AddChoice { one, file, template }

Future<void> _importFile(BuildContext context, PersonRole role) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'تعذّر فتح اختيار الملفات', error: true);
    }
    return;
  }
  if (file == null || !context.mounted) return;

  final size = file.lengthSync() ?? await file.length();
  if (!context.mounted) return;
  if (size != null && size > _maxFileBytes) {
    showMessage(context, 'حجم الملف أكبر من 2 ميجابايت', error: true);
    return;
  }
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PeopleListScreen.fromFile(role, bytes: bytes, fileName: file!.name),
    ),
  );
}

/// Saved drafts of [role], shown above the list of people.
class DraftsSection extends ConsumerWidget {
  final PersonRole role;

  const DraftsSection({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(peopleDraftsProvider(role)).value ?? const [];
    if (drafts.isEmpty) return const SizedBox.shrink();
    return Section(
      title: 'المسودات',
      children: [
        for (final draft in drafts)
          NdsListItem(
            leading: const FeaturedIcon(
              HugeIcons.strokeRoundedFileEdit,
              tone: Tone.warning,
            ),
            title: draft.name,
            meta: [
              role.count(draft.rowCount),
              if (draft.updatedAt != null) _savedLabel(draft.updatedAt!),
            ].join(' · '),
            meta2: draft.createdBy.isEmpty ? null : 'بواسطة ${draft.createdBy}',
            chevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PeopleListScreen.draft(role, draftId: draft.id),
              ),
            ),
          ),
      ],
    );
  }

  String _savedLabel(DateTime when) {
    final local = when.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final date = sameDay
        ? 'اليوم'
        : '${local.year}/${local.month.toString().padLeft(2, '0')}/'
              '${local.day.toString().padLeft(2, '0')}';
    return 'حُفظت $date ${clockLabel(local)}';
  }
}

enum LeaveChoice { save, discard, stay }

/// Asked when leaving with changes that are not in a draft yet.
Future<LeaveChoice> showLeaveSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<LeaveChoice>(
    context: context,
    useSafeArea: true,
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
          gap: Space.x2l,
          children: [
            NdsGroup(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FeaturedIcon(
                  HugeIcons.strokeRoundedFileEdit,
                  size: 48,
                  tone: Tone.warning,
                  circle: true,
                ),
                Text(
                  'حفظ ما أدخلته كمسودة؟',
                  textAlign: TextAlign.center,
                  style: NdsText.textXl.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Nds.textDisplay,
                  ),
                ),
                Text(
                  'تجد المسودة في القائمة لتكملها لاحقاً.',
                  textAlign: TextAlign.center,
                  style: NdsText.textMd.copyWith(color: Nds.textSecondary),
                ),
              ],
            ),
            NdsGroup(
              children: [
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, LeaveChoice.save),
                  child: const Text('حفظ كمسودة'),
                ),
                OutlinedButton(
                  style: NdsButtons.destructiveOutline,
                  onPressed: () =>
                      Navigator.pop(sheetContext, LeaveChoice.discard),
                  child: const Text('تجاهل التغييرات'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, LeaveChoice.stay),
                  child: const Text('متابعة التعديل'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return choice ?? LeaveChoice.stay;
}
