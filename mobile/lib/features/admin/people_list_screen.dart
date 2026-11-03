import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/ui.dart';
import 'add_people.dart';
import 'admin_api.dart';
import 'people.dart';
import 'people_api.dart';
import 'person_form_screen.dart';

/// Reviews a list of people before adding them: rows read from a spreadsheet
/// or kept in a draft. Rows with problems can be fixed, removed, or left in
/// the draft while the valid ones are added.
class PeopleListScreen extends ConsumerStatefulWidget {
  final PersonRole role;
  final Uint8List? fileBytes;
  final String? fileName;
  final String? draftId;

  const PeopleListScreen.fromFile(
    this.role, {
    super.key,
    required Uint8List bytes,
    required this.fileName,
  }) : fileBytes = bytes,
       draftId = null;

  const PeopleListScreen.draft(this.role, {super.key, required this.draftId})
    : fileBytes = null,
      fileName = null;

  @override
  ConsumerState<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends ConsumerState<PeopleListScreen> {
  String _name = '';
  List<PersonRow> _rows = [];
  List<List<RowIssue>> _issues = [];
  String? _draftId;
  bool _onlyProblems = false;

  /// Rows changed since the draft was saved, or not saved at all.
  bool _dirty = false;
  bool _busy = false;
  bool _loading = true;
  String? _loadError;

  PersonRole get _role => widget.role;

  int get _problemCount => _issues.where((issues) => issues.isNotEmpty).length;
  int get _readyCount => _rows.length - _problemCount;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final api = ref.read(peopleApiProvider);
    try {
      if (widget.fileBytes != null) {
        final contents = await api.readFile(
          _role,
          widget.fileBytes!,
          widget.fileName ?? 'file',
        );
        if (contents.missingColumns.isNotEmpty) {
          final labels = {for (final f in _role.fields) f.key: f.label};
          final missing = contents.missingColumns.map((k) => labels[k] ?? k);
          _fail('الملف لا يحتوي على الأعمدة المطلوبة: ${missing.join('، ')}.');
          return;
        }
        if (contents.people.rows.isEmpty) {
          _fail('لم يُعثر على بيانات تحت صف العناوين في الملف.');
          return;
        }
        setState(() {
          _name = contents.name;
          _rows = contents.people.rows;
          _issues = contents.people.issues;
          _dirty = true;
          _loading = false;
        });
      } else {
        final (draft, people) = await api.draft(widget.draftId!);
        setState(() {
          _name = draft.name;
          _rows = people.rows;
          _issues = people.issues;
          _loading = false;
        });
      }
    } catch (error) {
      _fail(switch (apiErrorCode(error)) {
        'UNSUPPORTED_FILE' =>
          'نوع الملف غير مدعوم. احفظه من Excel بصيغة xlsx أو CSV.',
        'UNREADABLE_FILE' => 'تعذّرت قراءة الملف. تأكد أنه غير تالف.',
        'FILE_TOO_LARGE' => 'حجم الملف أكبر من 2 ميجابايت.',
        'TOO_MANY_ROWS' =>
          'الملف يحتوي على أكثر من 1000 صف. قسّمه إلى ملفات أصغر.',
        'NOT_FOUND' => 'لم تعد هذه المسودة موجودة.',
        _ => 'تعذّر الاتصال بالخادم، حاول مرة أخرى.',
      });
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadError = message;
    });
  }

  Future<void> _recheck() async {
    try {
      final issues = await ref.read(peopleApiProvider).check(_role, _rows);
      if (mounted && issues.length == _rows.length) {
        setState(() => _issues = issues);
      }
    } catch (_) {
      // The next save or submit checks the rows again.
    }
  }

  Future<void> _editRow(int index) async {
    final edit = await Navigator.of(context).push<RowEdit>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen.editRow(
          _role,
          initial: _rows[index],
          issues: _issues[index],
        ),
      ),
    );
    if (edit == null || !mounted) return;
    setState(() {
      if (edit.deleted) {
        _rows = [..._rows]..removeAt(index);
        _issues = [..._issues]..removeAt(index);
      } else {
        _rows = [..._rows]..[index] = edit.row!;
      }
      _dirty = true;
    });
    if (_rows.isNotEmpty) await _recheck();
  }

  Future<void> _addRow() async {
    final edit = await Navigator.of(context).push<RowEdit>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen.editRow(_role, initial: const {}),
      ),
    );
    if (edit?.row == null || !mounted) return;
    setState(() {
      _rows = [..._rows, edit!.row!];
      _issues = [..._issues, const []];
      _dirty = true;
    });
    await _recheck();
  }

  Future<bool> _saveDraft() async {
    if (_rows.isEmpty) return false;
    setState(() => _busy = true);
    final api = ref.read(peopleApiProvider);
    try {
      final id = _draftId;
      final draft = id == null
          ? await api.createDraft(_role, _name, _rows)
          : await api.updateDraft(id, _rows);
      if (!mounted) return false;
      setState(() {
        _draftId = draft.id;
        _dirty = false;
      });
      ref.invalidate(peopleDraftsProvider(_role));
      showMessage(context, 'حُفظت المسودة');
      return true;
    } catch (_) {
      if (mounted) {
        showMessage(context, 'تعذّر حفظ المسودة، حاول مرة أخرى', error: true);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final ready = _readyCount;
    final confirmed = await showConfirmSheet(
      context,
      title: 'إضافة ${_role.count(ready)}؟',
      message: [
        'يُنشأ حساب لكل شخص دون كلمة مرور، وتُعيَّن كلمة المرور عند أول دخول '
            'برمز يصل إلى رقم الجوال.',
        if (_problemCount > 0)
          'الصفوف التي تحتاج تصحيحاً (${_problemCount.toString()}) تبقى في المسودة.',
      ].join('\n'),
      confirmLabel: 'إضافة',
      icon: HugeIcons.strokeRoundedUserAdd01,
      tone: Tone.primary,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(peopleApiProvider)
          .submit(_role, _rows, draftId: _draftId);
      if (!mounted) return;
      refreshAdminData(ref);
      ref.invalidate(peopleDraftsProvider(_role));

      final remaining = outcome.remaining.rows;
      if (remaining.isEmpty) {
        showMessage(context, 'تمت إضافة ${_role.count(outcome.created)}');
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _rows = remaining;
        _issues = outcome.remaining.issues;
        _draftId = outcome.draft?.id ?? _draftId;
        // Rows left over from a file exist only here until saved.
        _dirty = outcome.draft == null;
        _onlyProblems = false;
      });
      showMessage(
        context,
        outcome.created > 0
            ? 'تمت إضافة ${_role.count(outcome.created)}، '
                  'وبقي ${remaining.length.toString()} للتصحيح'
            : 'لم يُضف أحد. صحّح الصفوف المحددة.',
        error: outcome.created == 0,
      );
    } catch (_) {
      if (mounted) {
        showMessage(context, 'تعذّرت الإضافة، حاول مرة أخرى', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDraft() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'حذف المسودة؟',
      message:
          'تُحذف القائمة كلها (${_role.count(_rows.length)}) ولا يُضاف أحد.',
      confirmLabel: 'حذف المسودة',
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
      tone: Tone.error,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(peopleApiProvider).deleteDraft(_draftId!);
      if (!mounted) return;
      ref.invalidate(peopleDraftsProvider(_role));
      showMessage(context, 'حُذفت المسودة');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'تعذّر حذف المسودة', error: true);
      }
    }
  }

  Future<void> _onLeave() async {
    final choice = await showLeaveSheet(context);
    if (!mounted) return;
    switch (choice) {
      case LeaveChoice.save:
        if (await _saveDraft() && mounted) Navigator.of(context).pop();
      case LeaveChoice.discard:
        Navigator.of(context).pop();
      case LeaveChoice.stay:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asksBeforeLeaving = _dirty && _rows.isNotEmpty && !_busy;
    return PopScope(
      canPop: !asksBeforeLeaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(
          title: _loading ? 'قائمة الإضافة' : _name,
          subtitle: _draftId == null ? 'من ملف · لم تُحفظ' : 'مسودة',
          trailing: _draftId == null
              ? null
              : CircleIconButton(
                  icon: HugeIcons.strokeRoundedDelete02,
                  tooltip: 'حذف المسودة',
                  onPressed: _busy ? null : _deleteDraft,
                ),
        ),
        body: _buildBody(),
        bottomNavigationBar: _loading || _loadError != null || _rows.isEmpty
            ? null
            : NdsFooter(
                children: [
                  ElevatedButton(
                    onPressed: _busy || _readyCount == 0 ? null : _submit,
                    child: Text(
                      _readyCount == 0
                          ? 'لا توجد صفوف جاهزة'
                          : 'إضافة ${_role.count(_readyCount)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busy || (!_dirty && _draftId != null)
                        ? null
                        : _saveDraft,
                    child: Text(
                      !_dirty && _draftId != null
                          ? 'المسودة محفوظة'
                          : 'حفظ كمسودة',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_loadError != null) {
      return MessageView(
        icon: HugeIcons.strokeRoundedFileImport,
        tone: Tone.error,
        title: 'تعذّر فتح القائمة',
        message: _loadError,
        action: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('رجوع'),
        ),
      );
    }

    final shown = [
      for (var i = 0; i < _rows.length; i++)
        if (!_onlyProblems || _issues[i].isNotEmpty) i,
    ];
    return PageBody(
      children: [
        NdsPanel(
          child: MiniStats(
            items: [
              ('${_rows.length}', 'في القائمة', null),
              ('$_readyCount', 'جاهزة للإضافة', Nds.textSuccess),
              (
                '$_problemCount',
                'تحتاج تصحيحاً',
                _problemCount > 0 ? Nds.textError : null,
              ),
            ],
          ),
        ),
        if (_problemCount > 0) ...[
          const NdsAlert(
            status: TagStatus.warning,
            title: 'بعض الصفوف تحتاج تصحيحاً',
            description:
                'اضغط على الصف لتصحيحه أو حذفه. يمكنك إضافة الصفوف الجاهزة الآن، '
                'وتبقى البقية في المسودة.',
          ),
          NdsChoiceChips<bool>(
            options: const [(false, 'كل الصفوف'), (true, 'تحتاج تصحيحاً')],
            selected: _onlyProblems,
            onSelected: (value) => setState(() => _onlyProblems = value),
          ),
        ],
        if (_rows.isEmpty)
          const MessageView(
            icon: HugeIcons.strokeRoundedUserGroup,
            title: 'القائمة فارغة',
            message: 'أضف صفاً، أو احذف المسودة.',
          )
        else
          NdsGroup(
            gap: Space.md,
            children: [for (final i in shown) _rowItem(i)],
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addRow,
          icon: const AppIcon(HugeIcons.strokeRoundedAdd01, size: 20),
          label: const Text('إضافة صف'),
        ),
      ],
    );
  }

  Widget _rowItem(int index) {
    final row = _rows[index];
    final issues = _issues[index];
    final name = rowName(row);
    return NdsListItem(
      leading: InitialsAvatar(name.isEmpty ? '؟' : name),
      title: name.isEmpty ? 'بدون اسم' : name,
      titleBadge: issues.isEmpty
          ? const NdsTag('جاهز', status: TagStatus.success, small: true)
          : const NdsTag('يحتاج تصحيحاً', status: TagStatus.error, small: true),
      meta: [
        if (row['phone'] != null) ltr(row['phone']!),
        if (row[_role.idField.key] != null) ltr(row[_role.idField.key]!),
      ].join(' · '),
      bottom: issues.isEmpty
          ? null
          : Text(
              issueSummary(_role, issues),
              style: NdsText.textSm.copyWith(color: Nds.textError),
            ),
      chevron: true,
      onTap: _busy ? null : () => _editRow(index),
    );
  }
}
