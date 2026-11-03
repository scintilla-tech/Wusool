import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_mobile/core/api_client.dart';

DioException _failure(int? status, {String? code}) {
  final request = RequestOptions(path: '/attendance/today');
  return DioException(
    requestOptions: request,
    response: status == null
        ? null
        : Response(
            requestOptions: request,
            statusCode: status,
            data: {
              'success': false,
              'error': {'code': code},
            },
          ),
  );
}

void main() {
  test('answers the server gave on purpose are not retried', () {
    expect(retryUnlessClientError(0, _failure(404)), isNull);
    expect(retryUnlessClientError(0, _failure(403)), isNull);
  });

  test('lost connections and server errors are still retried', () {
    expect(retryUnlessClientError(0, _failure(null)), isNotNull);
    expect(retryUnlessClientError(0, _failure(503)), isNotNull);
  });

  test('reads the API error code from a failed request', () {
    expect(
      apiErrorCode(_failure(404, code: 'NO_ACTIVE_ROUTE')),
      'NO_ACTIVE_ROUTE',
    );
    expect(apiErrorCode(StateError('other')), isNull);
  });
}
