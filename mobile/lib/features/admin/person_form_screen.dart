import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/ui.dart';
import 'add_people.dart';
import 'admin_api.dart';
import 'people.dart';
import 'people_api.dart';

/// The outcome of editing a row of a list: the new values, or its removal.
typedef RowEdit = ({PersonRow? row, bool deleted});

enum _Mode { add, editRow, edit }

/// One person's details. Adds the person directly ([PersonFormScreen.add]),
/// edits a row of an imported list or draft ([PersonFormScreen.editRow]), or
/// edits an existing account ([PersonFormScreen.edit], popping true once
/// saved).
class PersonFormScreen extends ConsumerStatefulWidget {
  final PersonRole role;
  final PersonRow initial;
  final List<RowIssue> issues;
  final String? personId;
  final _Mode _mode;

  const PersonFormScreen.add(this.role, {super.key})
    : initial = const {},
      issues = const [],
      personId = null,
      _mode = _Mode.add;

  const PersonFormScreen.editRow(
    this.role, {
    super.key,
    required this.initial,
    this.issues = const [],
  }) : personId = null,
       _mode = _Mode.editRow;

  const PersonFormScreen.edit(
    this.role, {
    super.key,
    required String this.personId,
    required this.initial,
  }) : issues = const [],
       _mode = _Mode.edit;

  bool get editingRow => _mode == _Mode.editRow;
  bool get editingAccount => _mode == _Mode.edit;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.role.fields)
      field.key: TextEditingController(text: widget.initial[field.key] ?? ''),
  };
  late List<RowIssue> _issues = widget.issues;
  bool _busy = false;

  /// Set once the person is added or drafted, so leaving does not ask again.
  bool _done = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PersonRow get _row => {
    for (final MapEntry(:key, :value) in _controllers.entries)
      if (value.text.trim().isNotEmpty) key: value.text.trim(),
  };

  bool get _hasInput => _row.isNotEmpty;

  bool get _changed {
    final row = _row;
    final before = widget.initial;
    return row.length != before.length ||
        row.entries.any((entry) => before[entry.key] != entry.value);
  }

  String? _serverError(String key) {
    final messages = [
      for (final issue in _issues)
        if (issue.field == key) issue.message,
    ];
    return messages.isEmpty ? null : messages.join('، ');
  }

  void _clearIssue(String key) {
    if (_issues.any((issue) => issue.field == key)) {
      setState(
        () => _issues = [
          for (final issue in _issues)
            if (issue.field != key) issue,
        ],
      );
    }
  }

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = ref.read(peopleApiProvider);
    try {
      final outcome = await api.submit(widget.role, [_row]);
      if (!mounted) return;
      if (outcome.created == 1) {
        _done = true;
        refreshAdminData(ref);
        showMessage(context, 'تمت إضافة ${rowName(_row)}');
        Navigator.of(context).pop();
        return;
      }
      final issues = outcome.remaining.issues.firstOrNull ?? const [];
      setState(() => _issues = issues);
      final general = issues.where((issue) => issue.field == null);
      showMessage(
        context,
        general.isEmpty ? 'صحّح الحقول المحددة' : general.first.message,
        error: true,
      );
    } catch (error) {
      if (mounted) showMessage(context, _failure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(adminApiProvider)
          .updatePerson(widget.personId!, _row);
      if (!mounted) return;
      if (outcome.saved) {
        _done = true;
        showMessage(context, 'حُفظت التعديلات');
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _issues = outcome.issues);
      showMessage(context, 'صحّح الحقول المحددة', error: true);
    } catch (error) {
      if (mounted) showMessage(context, adminFailure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLeaveEdit() async {
    final discard = await showConfirmSheet(
      context,
      title: 'تجاهل التعديلات؟',
      message: 'لن تُحفظ التغييرات التي أدخلتها.',
      confirmLabel: 'تجاهل التعديلات',
      cancelLabel: 'متابعة التعديل',
      destructive: true,
    );
    if (discard && mounted) {
      _done = true;
      Navigator.of(context).pop(false);
    }
  }

  Future<bool> _saveDraft() async {
    if (!_hasInput) {
      showMessage(context, 'أدخل بيانات قبل الحفظ', error: true);
      return false;
    }
    setState(() => _busy = true);
    try {
      final name = rowName(_row);
      await ref.read(peopleApiProvider).createDraft(
        widget.role,
        name.isEmpty ? widget.role.addOneLabel : name,
        [_row],
      );
      if (!mounted) return false;
      _done = true;
      ref.invalidate(peopleDraftsProvider(widget.role));
      showMessage(context, 'حُفظت المسودة');
      return true;
    } catch (error) {
      if (mounted) showMessage(context, _failure(error), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraftAndLeave() async {
    if (await _saveDraft() && mounted) Navigator.of(context).pop();
  }

  void _saveRow() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop<RowEdit>((row: _row, deleted: false));
  }

  Future<void> _deleteRow() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'حذف هذا الصف؟',
      message:
          'لن يُضاف ${rowName(_row).isEmpty ? 'هذا الشخص' : rowName(_row)}.',
      confirmLabel: 'حذف الصف',
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
      tone: Tone.error,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop<RowEdit>((row: null, deleted: true));
    }
  }

  Future<void> _onLeave() async {
    final choice = await showLeaveSheet(context);
    if (!mounted) return;
    switch (choice) {
      case LeaveChoice.save:
        await _saveDraftAndLeave();
      case LeaveChoice.discard:
        _done = true;
        Navigator.of(context).pop();
      case LeaveChoice.stay:
        break;
    }
  }

  String _failure(Object error) => switch (apiErrorCode(error)) {
    'RATE_LIMITED' => 'محاولات كثيرة، حاول بعد قليل',
    _ => 'تعذّر الاتصال بالخادم، حاول مرة أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final asksBeforeLeaving = switch (widget._mode) {
      _Mode.add => !_done && _hasInput,
      _Mode.edit => !_done && _changed,
      _Mode.editRow => false,
    };

    return PopScope(
      canPop: !asksBeforeLeaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.editingAccount ? _onLeaveEdit() : _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(
          title: widget._mode == _Mode.add
              ? role.addOneLabel
              : 'تعديل البيانات',
        ),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              if (widget._mode == _Mode.add)
                const InlineNote(
                  'يصل رمز تحقق إلى رقم الجوال عند أول دخول لتعيين كلمة المرور.',
                ),
              if (widget.editingAccount)
                const InlineNote(
                  'يكون الدخول برقم الجوال؛ إن غيّرته فالدخول بالرقم الجديد.',
                ),
              for (final field in role.fields)
                NdsField(
                  label: field.required
                      ? field.label
                      : '${field.label} (اختياري)',
                  controller: _controllers[field.key]!,
                  hint: field.hint,
                  keyboardType: field.keyboardType,
                  textDirection: field.ltr ? TextDirection.ltr : null,
                  textInputAction: TextInputAction.next,
                  errorText: _serverError(field.key),
                  onChanged: (_) {
                    _clearIssue(field.key);
                    setState(() {});
                  },
                  validator: field.required
                      ? (value) => (value == null || value.trim().isEmpty)
                            ? 'مطلوب'
                            : null
                      : null,
                ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: widget.editingAccount
              ? [
                  ElevatedButton(
                    onPressed: _busy || !_changed ? null : _saveChanges,
                    child: const Text('حفظ التعديلات'),
                  ),
                ]
              : widget.editingRow
              ? [
                  ElevatedButton(
                    onPressed: _saveRow,
                    child: const Text('حفظ التعديل'),
                  ),
                  OutlinedButton.icon(
                    style: NdsButtons.destructiveOutline,
                    onPressed: _deleteRow,
                    icon: const AppIcon(
                      HugeIcons.strokeRoundedDelete02,
                      size: 20,
                    ),
                    label: const Text('حذف الصف'),
                  ),
                ]
              : [
                  ElevatedButton(
                    onPressed: _busy ? null : _add,
                    child: Text(role.addOneLabel),
                  ),
                  OutlinedButton(
                    onPressed: _busy || !_hasInput ? null : _saveDraftAndLeave,
                    child: const Text('حفظ كمسودة'),
                  ),
                ],
        ),
      ),
    );
  }
}
