import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/features/admin/people.dart';
import 'package:wasl_mobile/features/admin/people_api.dart';
import 'package:wasl_mobile/features/admin/people_list_screen.dart';
import 'package:wasl_mobile/features/admin/person_form_screen.dart';

const _sara = {
  'firstName': 'سارة',
  'lastName': 'العتيبي',
  'phone': '0500000201',
  'studentId': '441000001',
};
const _noura = {
  'firstName': 'نورة',
  'phone': '0500000202',
  'studentId': '441000002',
};

class _FakeApi implements PeopleApi {
  final submitted = <List<PersonRow>>[];
  final drafted = <List<PersonRow>>[];
  SubmitOutcome Function(List<PersonRow> rows) onSubmit = (rows) =>
      SubmitOutcome(rows.length, const PeopleList([], []), null);

  @override
  Future<(DraftSummary, PeopleList)> draft(String id) async => (
    DraftSummary(
      id: id,
      role: PersonRole.student,
      name: 'دفعة الخريف',
      rowCount: 2,
    ),
    const PeopleList(
      [_sara, _noura],
      [
        [],
        [RowIssue('lastName', 'REQUIRED')],
      ],
    ),
  );

  @override
  Future<FileContents> readFile(
    PersonRole role,
    Uint8List bytes,
    String fileName,
  ) async => const FileContents('الدفعة', PeopleList([_sara], [[]]), []);

  @override
  Future<SubmitOutcome> submit(
    PersonRole role,
    List<PersonRow> rows, {
    String? draftId,
  }) async {
    submitted.add(rows);
    return onSubmit(rows);
  }

  @override
  Future<DraftSummary> createDraft(
    PersonRole role,
    String name,
    List<PersonRow> rows,
  ) async {
    drafted.add(rows);
    return DraftSummary(
      id: 'd1',
      role: role,
      name: name,
      rowCount: rows.length,
    );
  }

  @override
  Future<List<List<RowIssue>>> check(
    PersonRole role,
    List<PersonRow> rows,
  ) async => [for (final _ in rows) const []];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(_FakeApi api, Widget home) => ProviderScope(
  overrides: [peopleApiProvider.overrideWithValue(api)],
  child: MaterialApp(
    theme: buildTheme(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => home)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, _FakeApi api, Widget screen) async {
  tester.view.physicalSize = const Size(402, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(api, screen));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('row problems read as Arabic messages next to their field', () {
    final summary = issueSummary(PersonRole.student, const [
      RowIssue('lastName', 'REQUIRED'),
      RowIssue('phone', 'PHONE_TAKEN'),
    ]);

    expect(summary, 'اسم العائلة: مطلوب · رقم الجوال: مسجّل لحساب آخر');
  });

  test('counts agree with Arabic number rules for each role', () {
    expect(PersonRole.driver.count(1), 'سائق واحد');
    expect(PersonRole.driver.count(5), '5 سائقين');
    expect(PersonRole.supervisor.count(2), 'مشرفتان');
    expect(PersonRole.student.count(12), '12 طالبة');
  });

  testWidgets('a draft adds its ready rows and keeps the one to fix', (
    tester,
  ) async {
    final api = _FakeApi()
      ..onSubmit = (rows) => SubmitOutcome(
        1,
        const PeopleList(
          [_noura],
          [
            [RowIssue('lastName', 'REQUIRED')],
          ],
        ),
        const DraftSummary(
          id: 'd1',
          role: PersonRole.student,
          name: 'دفعة الخريف',
          rowCount: 1,
        ),
      );
    await _open(
      tester,
      api,
      const PeopleListScreen.draft(PersonRole.student, draftId: 'd1'),
    );

    expect(find.text('دفعة الخريف'), findsOneWidget);
    expect(find.text('اسم العائلة: مطلوب'), findsOneWidget);

    await tester.tap(find.text('إضافة طالبة واحدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(api.submitted.single, [_sara, _noura]);
    expect(find.text('سارة العتيبي'), findsNothing);
    expect(find.text('نورة'), findsOneWidget);
    expect(find.text('المسودة محفوظة'), findsOneWidget);
  });

  testWidgets('leaving an unsaved file list offers to save it as a draft', (
    tester,
  ) async {
    final api = _FakeApi();
    await _open(
      tester,
      api,
      PeopleListScreen.fromFile(
        PersonRole.student,
        bytes: Uint8List(0),
        fileName: 'الدفعة.xlsx',
      ),
    );

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ ما أدخلته كمسودة؟'), findsOneWidget);

    await tester.tap(find.text('حفظ كمسودة').last);
    await tester.pumpAndSettle();

    expect(api.drafted.single, [_sara]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the add form shows what the server rejected under the field', (
    tester,
  ) async {
    final api = _FakeApi()
      ..onSubmit = (rows) => SubmitOutcome(
        0,
        PeopleList(rows, const [
          [RowIssue('phone', 'PHONE_TAKEN')],
        ]),
        null,
      );
    await _open(tester, api, const PersonFormScreen.add(PersonRole.student));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'سارة');
    await tester.enterText(fields.at(1), 'العتيبي');
    await tester.enterText(fields.at(2), '0500000201');
    await tester.enterText(fields.at(3), '441000001');
    await tester.tap(find.widgetWithText(ElevatedButton, 'إضافة طالبة'));
    await tester.pumpAndSettle();

    expect(api.submitted.single, [_sara]);
    expect(find.text('مسجّل لحساب آخر'), findsOneWidget);
  });
}
