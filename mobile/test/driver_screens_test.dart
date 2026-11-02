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
}
