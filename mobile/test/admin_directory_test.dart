import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/features/admin/admin_api.dart';
import 'package:wasl_mobile/features/admin/admin_people_screen.dart';
import 'package:wasl_mobile/features/admin/people.dart';
import 'package:wasl_mobile/features/admin/people_api.dart';
import 'package:wasl_mobile/features/admin/person_detail_screen.dart';
import 'package:wasl_mobile/features/admin/person_form_screen.dart';

Person _student(int n, {RouteRef? route}) => Person(
  id: 'u$n',
  profileId: 'sp$n',
  role: PersonRole.student,
  firstName: 'طالبة',
  lastName: '$n',
  phone: '+9665000002${n.toString().padLeft(2, '0')}',
  number: '4410000$n',
  route: route,
);

class _FakeAdminApi implements AdminApi {
  /// Students the server has, newest first.
  List<Person> students = [for (var n = 1; n <= 35; n++) _student(n)];
  final pagesAsked = <int>[];
  final enabledCalls = <(String, bool)>[];
  final updates = <PersonRow>[];
  SaveOutcome Function(PersonRow row) onUpdate = (row) =>
      const SaveOutcome(null, []);

  PersonDetail detail = PersonDetail.fromJson({
    'id': 'u1',
    'profileId': 'sp1',
    'role': 'STUDENT',
    'firstName': 'سارة',
    'lastName': 'العتيبي',
    'phone': '+966500000201',
    'number': '441000001',
    'isActive': true,
    'isActivated': true,
    'route': {'id': 'r1', 'name': 'North Loop', 'code': 'R1', 'isActive': true},
    'row': {
      'firstName': 'سارة',
      'lastName': 'العتيبي',
      'phone': '0500000201',
      'studentId': '441000001',
    },
  });

  @override
  Future<PageOf<Person>> people(PeopleQuery query, {int page = 1}) async {
    pagesAsked.add(page);
    final start = (page - 1) * AdminApi.pageSize;
    return PageOf(
      students.skip(start).take(AdminApi.pageSize).toList(),
      students.length,
      page,
      counts: {
        'all': students.length,
        'active': students.length,
        'pending': 0,
        'disabled': 0,
        'unassigned': students.where((s) => s.route == null).length,
      },
    );
  }

  @override
  Future<PersonDetail> person(String id) async => detail;

  @override
  Future<PersonDetail> setPersonEnabled(String id, bool enabled) async {
    enabledCalls.add((id, enabled));
    return detail;
  }

  @override
  Future<SaveOutcome> updatePerson(String id, PersonRow row) async {
    updates.add(row);
    return onUpdate(row);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(
  WidgetTester tester,
  _FakeAdminApi api,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(402, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminApiProvider.overrideWithValue(api),
        peopleDraftsProvider.overrideWith((ref, role) async => const []),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => screen)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'a later page adds only people not shown yet, and ends the list',
    () async {
      final api = _FakeAdminApi();
      final container = ProviderContainer(
        overrides: [adminApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final query = peopleQuery(PersonRole.student);
      final sub = container.listen(peopleDirectoryProvider(query), (_, _) {});
      addTearDown(sub.close);

      final first = await container.read(peopleDirectoryProvider(query).future);
      expect(first.items, hasLength(30));
      expect(first.hasMore, isTrue);

      // A student added meanwhile pushes the last one of page 1 onto page 2;
      // she shows at the top on the next refresh.
      api.students = [_student(99), ...api.students];
      await container.read(peopleDirectoryProvider(query).notifier).loadMore();

      final both = container.read(peopleDirectoryProvider(query)).value!;
      expect(both.items.map((p) => p.id).toSet(), hasLength(both.items.length));
      expect(both.items, hasLength(35));
      expect(both.hasMore, isFalse);
      expect(api.pagesAsked, [1, 2]);
    },
  );

  test('a person reads their route, or the lack of one', () {
    final person = Person.fromJson({
      'id': 'u2',
      'profileId': 'dp1',
      'role': 'DRIVER',
      'firstName': 'Khalid',
      'lastName': 'Saleh',
      'phone': '+966500000301',
      'bus': null,
    });
    expect(person.role, PersonRole.driver);
    expect(person.isAssigned, isFalse);
    expect(
      _student(
        1,
        route: const RouteRef(id: 'r1', name: 'R'),
      ).isAssigned,
      isTrue,
    );
  });

  testWidgets('the directory shows counts per filter and loads the next page', (
    tester,
  ) async {
    final api = _FakeAdminApi();
    await _open(tester, api, const AdminPeopleScreen.students());

    expect(find.text('الكل 35'), findsOneWidget);
    expect(find.text('بدون مسار 35'), findsOneWidget);
    expect(find.text('يعرض 30 من أصل 35 طالبة'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('عرض المزيد'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('عرض المزيد'));
    await tester.pumpAndSettle();

    expect(find.text('طالبة 35'), findsOneWidget);
    expect(find.text('عرض المزيد'), findsNothing);
    expect(api.pagesAsked, [1, 2]);
  });

  testWidgets('disabling an account asks first and says what it ends', (
    tester,
  ) async {
    final api = _FakeAdminApi();
    await _open(
      tester,
      api,
      const PersonDetailScreen(personId: 'u1', role: PersonRole.student),
    );

    expect(find.text('المسار: North Loop'), findsNothing);
    expect(find.text('North Loop'), findsOneWidget);

    await tester.tap(find.text('تعطيل الحساب'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'لن تتمكن من تسجيل الدخول وتُزال من مسار North Loop. '
        'يمكنك إلغاء التعطيل في أي وقت.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'تعطيل الحساب'));
    await tester.pumpAndSettle();
    expect(api.enabledCalls, [('u1', false)]);
  });

  testWidgets('editing shows a value another account uses under its field', (
    tester,
  ) async {
    final api = _FakeAdminApi()
      ..onUpdate = (row) =>
          const SaveOutcome(null, [RowIssue('phone', 'PHONE_TAKEN')]);
    await _open(
      tester,
      api,
      PersonFormScreen.edit(
        PersonRole.student,
        personId: 'u1',
        initial: api.detail.row,
      ),
    );

    final save = find.widgetWithText(ElevatedButton, 'حفظ التعديلات');
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('رقم الجوال'), '0500000202');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(api.updates.single['phone'], '0500000202');
    expect(find.text('مسجّل لحساب آخر'), findsOneWidget);
  });
}
