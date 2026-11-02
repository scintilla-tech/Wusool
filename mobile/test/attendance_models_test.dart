import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/features/driver/driver_providers.dart';
import 'package:wasl_mobile/features/student/student_providers.dart';
import 'package:wasl_mobile/features/supervisor/supervisor_providers.dart';

void main() {
  test(
    'student attendance parses independent outbound and return sessions',
    () {
      final outbound = AttendanceSessionView.fromJson({
        'id': 's-out',
        'direction': 'OUTBOUND',
        'status': 'CLOSED',
        'operationalDate': '2026-10-13T00:00:00.000Z',
        'opensAt': '2026-10-12T15:00:00.000Z',
        'isOpen': false,
        'intent': 'ATTENDING',
        'expectedFinishTime': '15:30',
      });
      final returning = AttendanceSessionView.fromJson({
        'id': 's-return',
        'direction': 'RETURN',
        'status': 'OPEN',
        'operationalDate': '2026-10-13T00:00:00.000Z',
        'opensAt': '2026-10-13T08:00:00.000Z',
        'isOpen': true,
        'intent': null,
        'expectedFinishTime': null,
      });

      expect(outbound.expectedFinishTime, '15:30');
      expect(outbound.status, 'CLOSED');
      expect(returning.intent, isNull);
      expect(returning.isOpen, isTrue);
    },
  );

  test(
    'driver roster joins attendance by student without copying directions',
    () {
      final trip = DriverTrip.fromJson({
        'id': 'trip-out',
        'direction': 'OUTBOUND',
        'status': 'SCHEDULED',
        'tripStudents': [
          {
            'studentProfileId': 'student-1',
            'status': 'WAITING',
            'studentProfile': {
              'user': {'firstName': 'سارة', 'lastName': 'محمد'},
            },
          },
          {
            'studentProfileId': 'student-2',
            'status': 'WAITING',
            'studentProfile': {
              'user': {'firstName': 'نورة', 'lastName': 'علي'},
            },
          },
        ],
        'attendanceSession': {
          'status': 'OPEN',
          'attendanceIntents': [
            {
              'studentProfileId': 'student-1',
              'intent': 'ATTENDING',
              'source': 'DRIVER_ASSISTED_REGISTRATION',
              'expectedFinishMinutes': 930,
            },
          ],
        },
      });

      expect(trip.attending, 1);
      expect(trip.absent, 0);
      expect(trip.unregistered, 1);
      expect(trip.students.first.expectedFinishTime, '15:30');
      expect(trip.students.last.attendanceIntent, isNull);
    },
  );

  test('supervisor bus card knows which direction its trip runs', () {
    final bus = SupervisorBusView.fromJson({
      'bus': {'id': 'b1', 'plateNumber': 'KKU-1003'},
      'trip': {'id': 't1', 'status': 'IN_PROGRESS', 'direction': 'RETURN'},
      'counts': {'total': 5},
    });

    expect(bus.tripDirection, 'RETURN');
  });
}
