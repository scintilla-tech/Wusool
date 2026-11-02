import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/features/driver/driver_providers.dart';
import 'package:wasl_mobile/features/driver/driver_screen.dart';
import 'package:wasl_mobile/features/driver/driver_trip_screens.dart';

class _FakeActions implements DriverActions {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _returnTrip = DriverTrip(
  id: 'return',
  status: 'SCHEDULED',
  direction: 'RETURN',
  busPlate: 'KKU-1003',
);

Widget _startTripApp(Future<List<DriverTrip>> Function() trips) {
  return ProviderScope(
    overrides: [driverTripsProvider.overrideWith((ref) => trips())],
    child: MaterialApp(
      theme: buildTheme(),
      scrollBehavior: const AppScrollBehavior(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StartTripScreen(tripId: 'return', actions: _FakeActions()),
      ),
    ),
  );
}

bool _startEnabled(WidgetTester tester) {
  final button = find.ancestor(
    of: find.text('ابدأ الرحلة الآن'),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
  );
  return tester.widget<ElevatedButton>(button).enabled;
}

void main() {
  testWidgets('another running trip blocks starting this one', (tester) async {
    await tester.pumpWidget(
      _startTripApp(
        () async => const [
          DriverTrip(id: 'outbound', status: 'IN_PROGRESS'),
          _returnTrip,
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_startEnabled(tester), isFalse);
    expect(find.textContaining('لديك رحلة جارية'), findsOneWidget);
  });

  testWidgets('a finished trip does not block the next one', (tester) async {
    await tester.pumpWidget(
      _startTripApp(
        () async => const [
          DriverTrip(id: 'outbound', status: 'COMPLETED'),
          _returnTrip,
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_startEnabled(tester), isTrue);
    expect(find.textContaining('لديك رحلة جارية'), findsNothing);
  });

  testWidgets('a mouse pull refreshes in a Mac browser', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var fetches = 0;
    await tester.pumpWidget(
      _startTripApp(() async {
        fetches++;
        return const [_returnTrip];
      }),
    );
    await tester.pumpAndSettle();
    expect(fetches, 1);

    final mouse = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
      kind: PointerDeviceKind.mouse,
    );
    for (var moved = 0; moved < 22; moved++) {
      await mouse.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();

    expect(fetches, 2);
    debugDefaultTargetPlatformOverride = null;
  });
}
