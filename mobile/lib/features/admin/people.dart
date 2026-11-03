/// People a university admin adds: the roles, the fields each role fills in,
/// and the problems the server reports for a row. Mirrors
/// `backend/src/modules/imports/imports.fields.ts`.
library;

import 'package:flutter/services.dart';

import '../../core/labels.dart';

enum PersonRole {
  student('STUDENT', 'students'),
  driver('DRIVER', 'drivers'),
  supervisor('SUPERVISOR', 'supervisors'),
  fieldSupervisor('FIELD_SUPERVISOR', 'field-supervisors');

  /// The role as the API names it.
  final String api;

  /// The name of the role's blank template file.
  final String templateSlug;

  const PersonRole(this.api, this.templateSlug);

  static PersonRole fromApi(String? value) =>
      values.firstWhere((role) => role.api == value, orElse: () => student);

  bool get isStudent => this == student;

  /// Students and supervisors are women, drivers men; labels agree with it.
  bool get feminine => this != driver;

  String get activeLabel => feminine ? 'نشطة' : 'نشط';
  String get disabledLabel => feminine ? 'معطّلة' : 'معطّل';

  /// "طالبة", "سائق"...
  String get singular => switch (this) {
    student => 'طالبة',
    driver => 'سائق',
    supervisor => 'مشرفة',
    fieldSupervisor => 'مشرفة ميدانية',
  };

  /// "الطالبات", "السائقون"...
  String get plural => switch (this) {
    student => 'الطالبات',
    driver => 'السائقون',
    supervisor => 'المشرفات',
    fieldSupervisor => 'المشرفات الميدانيات',
  };

  /// Counted noun with Arabic number agreement.
  String count(int n) => switch (this) {
    student => studentCount(n),
    driver => countOf(
      n,
      one: 'سائق واحد',
      two: 'سائقان',
      few: 'سائقين',
      many: 'سائقاً',
    ),
    supervisor => countOf(
      n,
      one: 'مشرفة واحدة',
      two: 'مشرفتان',
      few: 'مشرفات',
      many: 'مشرفة',
    ),
    fieldSupervisor => countOf(
      n,
      one: 'مشرفة ميدانية واحدة',
      two: 'مشرفتان ميدانيتان',
      few: 'مشرفات ميدانيات',
      many: 'مشرفة ميدانية',
    ),
  };

  /// "إضافة طالبة", "إضافة سائق"...
  String get addOneLabel => 'إضافة $singular';

  List<PersonField> get fields => isStudent ? _studentFields : _employeeFields;

  PersonField get idField => fields.firstWhere(
    (field) => field.key == (isStudent ? 'studentId' : 'employeeId'),
  );
}

class PersonField {
  final String key;
  final String label;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;

  /// Numbers, emails and dates read left to right inside Arabic text.
  final bool ltr;

  const PersonField(
    this.key,
    this.label, {
    this.required = false,
    this.hint,
    this.keyboardType,
    this.ltr = false,
  });
}

const _firstName = PersonField('firstName', 'الاسم الأول', required: true);
const _lastName = PersonField('lastName', 'اسم العائلة', required: true);
const _phone = PersonField(
  'phone',
  'رقم الجوال',
  required: true,
  hint: '05XXXXXXXX',
  keyboardType: TextInputType.phone,
  ltr: true,
);
const _email = PersonField(
  'email',
  'البريد الإلكتروني',
  keyboardType: TextInputType.emailAddress,
  ltr: true,
);
const _date = 'YYYY-MM-DD';

const _studentFields = [
  _firstName,
  _lastName,
  _phone,
  PersonField('studentId', 'الرقم الجامعي', required: true, ltr: true),
  _email,
];

const _employeeFields = [
  _firstName,
  _lastName,
  _phone,
  PersonField('employeeId', 'الرقم الوظيفي', required: true, ltr: true),
  _email,
  PersonField(
    'nationalIdOrIqama',
    'رقم الهوية أو الإقامة',
    keyboardType: TextInputType.number,
    ltr: true,
  ),
  PersonField('nationality', 'الجنسية'),
  PersonField(
    'joinDate',
    'تاريخ الانضمام',
    hint: _date,
    keyboardType: TextInputType.datetime,
    ltr: true,
  ),
  PersonField(
    'iqamaExpiry',
    'تاريخ انتهاء الإقامة',
    hint: _date,
    keyboardType: TextInputType.datetime,
    ltr: true,
  ),
];

/// One person as typed: field key to text.
typedef PersonRow = Map<String, String>;

PersonRow rowFromJson(Object? raw) => raw is Map
    ? {
        for (final entry in raw.entries)
          if (entry.value is String && (entry.value as String).isNotEmpty)
            '${entry.key}': entry.value as String,
      }
    : {};

String rowName(PersonRow row) => [
  row['firstName'],
  row['lastName'],
].nonNulls.where((part) => part.trim().isNotEmpty).join(' ');

/// A problem the server found; [field] is null when it concerns the whole row.
class RowIssue {
  final String? field;
  final String code;

  const RowIssue(this.field, this.code);

  factory RowIssue.fromJson(Map<String, dynamic> json) =>
      RowIssue(json['field'] as String?, json['code'] as String? ?? '');

  /// The message shown under the field.
  String get message => switch (code) {
    'REQUIRED' => 'مطلوب',
    'INVALID_NAME' => 'يُكتب بالحروف فقط',
    'INVALID_PHONE' => 'رقم جوال سعودي غير صحيح',
    'INVALID_EMAIL' => 'بريد إلكتروني غير صحيح',
    'INVALID_DATE' => 'تاريخ ميلادي غير صحيح، مثل 2026-11-02',
    'INVALID_NATIONAL_ID' => 'من 10 إلى 20 رقماً',
    'TOO_LONG' => 'أطول من المسموح',
    'DUPLICATE_IN_LIST' => 'مكرر في هذه القائمة',
    'PHONE_TAKEN' => 'مسجّل لحساب آخر',
    'EMAIL_TAKEN' => 'مسجّل لحساب آخر',
    'ID_TAKEN' => 'مسجّل لحساب آخر',
    _ => 'الحساب موجود مسبقاً',
  };
}

List<List<RowIssue>> issuesFromJson(Object? raw) => [
  for (final row in raw is List ? raw : const [])
    [
      for (final issue in row is List ? row : const [])
        if (issue is Map) RowIssue.fromJson(issue.cast<String, dynamic>()),
    ],
];

/// "الاسم الأول: مطلوب" for showing a row's problems in a list.
String issueSummary(PersonRole role, List<RowIssue> issues) {
  final labels = {for (final field in role.fields) field.key: field.label};
  return issues
      .map(
        (issue) => issue.field == null
            ? issue.message
            : '${labels[issue.field] ?? issue.field}: ${issue.message}',
      )
      .join(' · ');
}

class DraftSummary {
  final String id;
  final PersonRole role;
  final String name;
  final int rowCount;
  final DateTime? updatedAt;
  final String createdBy;

  const DraftSummary({
    required this.id,
    required this.role,
    required this.name,
    required this.rowCount,
    this.updatedAt,
    this.createdBy = '',
  });

  factory DraftSummary.fromJson(Map<String, dynamic> json) {
    final by = json['createdBy'];
    return DraftSummary(
      id: json['id'] as String? ?? '',
      role: PersonRole.fromApi(json['role'] as String?),
      name: json['name'] as String? ?? '',
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      createdBy: by is Map
          ? [by['firstName'], by['lastName']].whereType<String>().join(' ')
          : '',
    );
  }
}

/// Rows with their problems, as a file read, a draft, or a submit returns them.
class PeopleList {
  final List<PersonRow> rows;
  final List<List<RowIssue>> issues;

  const PeopleList(this.rows, this.issues);

  factory PeopleList.fromJson(Map<String, dynamic> json) => PeopleList([
    for (final row in json['rows'] as List? ?? const []) rowFromJson(row),
  ], issuesFromJson(json['issues']));
}
