import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/core/api_client.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/core/token_store.dart';
import 'package:wasl_mobile/features/driver/absence_screen.dart';
import 'package:wasl_mobile/features/driver/create_trip_screen.dart';
import 'package:wasl_mobile/features/driver/driver_providers.dart' show isoDay;
import 'package:wasl_mobile/features/admin/trip_settings_screen.dart';
import 'package:wasl_mobile/features/auth/auth_state.dart';
import 'package:wasl_mobile/features/home/notifications.dart';
import 'package:wasl_mobile/features/supervisor/bus_detail_screen.dart';
import 'package:wasl_mobile/features/supervisor/cover_driver_screen.dart';
import 'package:wasl_mobile/features/supervisor/supervisor_providers.dart';

typedef Handler = Object Function(RequestOptions options);

/// Answers requests from [routes] ("GET /driver/bus") and records them.
class _Server implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final requests = <RequestOptions>[];

  _Server(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final body = handler == null
        ? {
            'success': false,
            'error': {'code': 'NOT_FOUND'},
          }
        : handler(options);
    final status = body is Map && body['success'] == false ? 409 : 200;
    return ResponseBody.fromString(
      jsonEncode(body),
      handler == null ? 404 : status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Memory implements TokenStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Map<String, Object> ok(Object data) => {'success': true, 'data': data};

Future<void> _open(WidgetTester tester, _Server server, Widget screen) async {
  tester.view.physicalSize = const Size(402, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tokens = TokenStore(_Memory());
  await tokens.initialize();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = server;
          return ApiClient(dio, tokens, 'http://test.local/api/v1');
        }),
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
  testWidgets('a driver adds the missing trip on the fixed route', (
    tester,
  ) async {
    final server = _Server({
      'GET /driver/bus': (_) => ok({
        'bus': {'id': 'bus1', 'plateNumber': 'KKU-1001', 'name': null},
        'route': {
          'id': 'r1',
          'name': 'North Loop',
          'stops': [
            {'id': 'n1', 'name': 'النرجس'},
          ],
        },
        'today': [
          {'direction': 'OUTBOUND', 'status': 'COMPLETED'},
        ],
      }),
      'POST /driver/trips': (_) => ok({'id': 'trip2'}),
    });
    await _open(tester, server, const CreateTripScreen());

    expect(find.text('North Loop'), findsOneWidget);
    expect(find.text('رحلة الذهاب موجودة اليوم.'), findsOneWidget);
    // The going trip exists, so only the return can be chosen.
    await tester.tap(find.text('رحلة الذهاب'));
    await tester.pump();
    expect(find.text('اختر الرحلة'), findsOneWidget);

    await tester.tap(find.text('رحلة العودة'));
    await tester.pump();
    await tester.tap(find.text('إنشاء رحلة العودة'));
    await tester.pumpAndSettle();

    final post = server.requests.last;
    expect(post.method, 'POST');
    expect(post.data, {'direction': 'RETURN'});
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a driver whose bus has no route builds it once', (tester) async {
    var built = false;
    final server = _Server({
      'GET /driver/bus': (_) => ok({
        'bus': {'id': 'bus2', 'plateNumber': 'KKU-1002', 'name': null},
        'route': built
            ? {
                'id': 'r9',
                'name': 'مسار عمر',
                'stops': [
                  {'id': 'n2', 'name': 'الملقا'},
                ],
              }
            : null,
        'today': [],
      }),
      'GET /driver/route-options': (_) => ok({
        'campuses': [
          {'id': 'c1', 'name': 'المقر الرئيسي'},
        ],
        'neighborhoods': [
          {'id': 'n1', 'name': 'النرجس'},
          {'id': 'n2', 'name': 'الملقا'},
        ],
      }),
      'POST /driver/route': (_) {
        built = true;
        return ok({'id': 'r9'});
      },
    });
    await _open(tester, server, const CreateTripScreen());

    expect(find.text('أنشئ مسار حافلتك أولاً'), findsOneWidget);
    await tester.tap(find.text('إنشاء مسار الحافلة'));
    await tester.pumpAndSettle();

    // The route's name is its only text field.
    await tester.enterText(find.byType(TextFormField), 'مسار عمر');
    await tester.tap(find.text('المقر الرئيسي'));
    await tester.tap(find.text('إضافة محطة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الملقا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء المسار'));
    await tester.pumpAndSettle();

    final post = server.requests.firstWhere((r) => r.path == '/driver/route');
    expect(post.data, {
      'name': 'مسار عمر',
      'branchId': 'c1',
      'stopIds': ['n2'],
    });
    // Back on the trip screen, now with the bus's route.
    expect(find.text('مسار عمر'), findsOneWidget);
    expect(find.text('أنشئ مسار حافلتك أولاً'), findsNothing);
  });

  testWidgets('a driver tells the supervisor they cannot drive tomorrow', (
    tester,
  ) async {
    final reported = <Map<String, dynamic>>[];
    final server = _Server({
      'GET /driver/absences': (_) => ok({
        'items': [
          for (final body in reported)
            {'id': 'a1', 'date': body['date'], 'note': body['note']},
        ],
      }),
      'POST /driver/absences': (options) {
        reported.add(options.data as Map<String, dynamic>);
        return ok({'id': 'a1'});
      },
    });
    await _open(tester, server, const AbsenceScreen());

    await tester.enterText(find.byType(TextFormField), 'موعد طبي');
    await tester.tap(find.text('إبلاغ المشرفة بغيابي غداً'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    expect(reported.single, {'date': isoDay(tomorrow), 'note': 'موعد طبي'});
    expect(find.text('بانتظار اختيار بديل'), findsOneWidget);
    expect(find.text('موعد طبي'), findsOneWidget);
  });

  testWidgets('a supervisor puts a free driver on the bus and both are told', (
    tester,
  ) async {
    final server = _Server({
      'GET /supervisor/buses/bus1/drivers': (_) => ok({
        'items': [
          {
            'profileId': 'dp-khalid',
            'firstName': 'Khalid',
            'lastName': 'Ali',
            'busy': [],
            'current': true,
            'regular': true,
          },
          {
            'profileId': 'dp-majed',
            'firstName': 'Majed',
            'lastName': 'Test',
            'bus': {'plateNumber': 'KKU-1004', 'name': null},
            'busy': ['OUTBOUND'],
          },
          {
            'profileId': 'dp-omar',
            'firstName': 'Omar',
            'lastName': 'Salem',
            'bus': null,
            'busy': [],
          },
        ],
      }),
      'POST /supervisor/buses/bus1/cover': (_) => ok({'trips': 2}),
      'GET /supervisor/buses': (_) => ok([]),
    });
    await _open(
      tester,
      server,
      const CoverDriverScreen(
        bus: SupervisorBusView(
          busId: 'bus1',
          plateNumber: 'KKU-1001',
          driverName: 'Khalid Ali',
          coverable: 2,
        ),
      ),
    );

    expect(find.text('يقود اليوم'), findsOneWidget);
    expect(find.text('مشغول: رحلة الذهاب'), findsOneWidget);

    // A busy driver cannot be chosen.
    await tester.tap(find.text('Majed Test'));
    await tester.pumpAndSettle();
    expect(find.text('تكليف Majed Test برحلات اليوم؟'), findsNothing);

    await tester.tap(find.text('Omar Salem'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('يصل إشعار إليه وإلى Khalid Ali.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'تكليف Omar Salem'));
    await tester.pumpAndSettle();

    final post = server.requests.firstWhere((r) => r.method == 'POST');
    expect(post.data, {'driverProfileId': 'dp-omar'});
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the notification list marks what is new, then reads it', (
    tester,
  ) async {
    final server = _Server({
      'GET /notifications': (_) => ok({
        'items': [
          {
            'id': 'n1',
            'type': 'COVER_ASSIGNED',
            'title': 'كُلّفت بتغطية رحلات اليوم',
            'body': 'رحلتا الذهاب والعودة على KKU-1001 بدلاً من Khalid Ali.',
            'isRead': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      }),
      'POST /notifications/read-all': (_) => ok({'updated': 1}),
      'GET /notifications/unread-count': (_) => ok({'count': 0}),
    });
    await _open(tester, server, const NotificationsScreen());

    expect(find.text('كُلّفت بتغطية رحلات اليوم'), findsOneWidget);
    expect(find.text('جديد'), findsOneWidget);
    expect(
      server.requests.map((r) => '${r.method} ${r.path}'),
      containsAllInOrder([
        'GET /notifications',
        'POST /notifications/read-all',
      ]),
    );
  });

  testWidgets('admins set the trip time and keep a holiday calendar', (
    tester,
  ) async {
    final holidays = <Map<String, dynamic>>[];
    final server = _Server({
      'GET /admin/settings': (_) =>
          ok({'autoTrips': true, 'autoTripTime': '06:15'}),
      'GET /admin/holidays': (_) => ok({'items': holidays}),
      'POST /admin/holidays': (options) {
        final body = options.data as Map<String, dynamic>;
        holidays.add({
          'id': 'h1',
          'name': body['name'],
          'startDate': body['startDate'],
          'endDate': body['endDate'],
          'days': 5,
        });
        return ok(holidays.last);
      },
    });
    await _open(tester, server, const TripSettingsScreen());

    expect(
      find.text('6:15 صباحاً بتوقيت الرياض، ويُبلَّغ السائقون حينها'),
      findsOneWidget,
    );
    expect(find.textContaining('لا إجازات قادمة'), findsOneWidget);

    await tester.tap(find.text('إضافة إجازة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'إجازة منتصف الفصل');
    // Saving without days asks for them.
    await tester.tap(find.widgetWithText(ElevatedButton, 'إضافة الإجازة'));
    await tester.pumpAndSettle();
    expect(find.text('اختر أيام الإجازة'), findsWidgets);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets("a supervisor sees the driver's days off and opens a cover", (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final server = _Server({
      'GET /supervisor/buses': (_) => ok([
        {
          'bus': {'id': 'bus1', 'plateNumber': 'KKU-1001', 'name': null},
          'trip': null,
          'counts': {},
          'regularDriverName': 'Khalid Ali',
          'coverable': 0,
          'drivers': [],
          'absences': [
            {
              'id': 'a1',
              'date': isoDay(tomorrow),
              'note': 'موعد طبي',
              'driverName': 'Khalid Ali',
              'coverName': null,
            },
          ],
        },
      ]),
      'GET /supervisor/buses/bus1/drivers': (options) => ok({
        'items': [
          {
            'profileId': 'dp-saad',
            'firstName': 'Saad',
            'lastName': 'Cover',
            'busy': [],
            'date': options.queryParameters['date'],
          },
        ],
      }),
    });
    await _open(
      tester,
      server,
      ProviderScope(
        overrides: [authProvider.overrideWith(_SignedInSupervisor.new)],
        child: const BusDetailScreen(busId: 'bus1'),
      ),
    );

    expect(find.text('غياب السائق'), findsOneWidget);
    expect(find.text('Khalid Ali · غداً'), findsOneWidget);
    expect(find.text('بلا بديل'), findsOneWidget);

    await tester.tap(find.text('Khalid Ali · غداً'));
    await tester.pumpAndSettle();
    // The plate keeps its own direction inside Arabic text.
    expect(find.text('\u2066KKU-1001\u2069 · غداً'), findsOneWidget);
    final asked = server.requests.lastWhere(
      (r) => r.path == '/supervisor/buses/bus1/drivers',
    );
    expect(asked.queryParameters['date'], isoDay(tomorrow));
  });
}

/// Signed in as a bus supervisor, without the sign-in flow.
class _SignedInSupervisor extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: AuthUser(
      id: 'u-sup',
      role: 'SUPERVISOR',
      firstName: 'Noura',
      lastName: 'Fahad',
    ),
  );
}
