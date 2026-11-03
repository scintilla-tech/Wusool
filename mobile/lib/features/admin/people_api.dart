import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'people.dart';

/// What happened when the admin sent rows to be added.
class SubmitOutcome {
  final int created;

  /// Rows not added, with their problems, in the order sent.
  final PeopleList remaining;

  /// The draft still holding [remaining], or null when none is left.
  final DraftSummary? draft;

  const SubmitOutcome(this.created, this.remaining, this.draft);
}

/// A spreadsheet read by the server.
class FileContents {
  final String name;
  final PeopleList people;

  /// Field keys of required columns the file lacks.
  final List<String> missingColumns;

  const FileContents(this.name, this.people, this.missingColumns);
}

/// Calls for adding students and staff, single or in bulk, and their drafts.
class PeopleApi {
  final ApiClient _api;
  final String _baseUrl;

  PeopleApi(this._api, this._baseUrl);

  Dio get _dio => _api.dio;

  /// A blank spreadsheet with the role's columns; public, so it opens in a browser.
  Uri templateUri(PersonRole role) =>
      Uri.parse('$_baseUrl/imports/templates/${role.templateSlug}');

  Future<FileContents> readFile(
    PersonRole role,
    Uint8List bytes,
    String fileName,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/imports/read-file',
      data: FormData.fromMap({
        'role': role.api,
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    return FileContents(
      data['name'] as String? ?? fileName,
      PeopleList.fromJson(data),
      [for (final key in data['missingColumns'] as List? ?? const []) '$key'],
    );
  }

  Future<List<List<RowIssue>>> check(
    PersonRole role,
    List<PersonRow> rows,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/imports/check',
      data: {'role': role.api, 'rows': rows},
    );
    return issuesFromJson(res.data?['data']?['issues']);
  }

  Future<SubmitOutcome> submit(
    PersonRole role,
    List<PersonRow> rows, {
    String? draftId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/imports/submit',
      data: {'role': role.api, 'rows': rows, 'draftId': ?draftId},
      // Adding many accounts can take longer than an ordinary request.
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    final draft = data['draft'];
    return SubmitOutcome(
      (data['created'] as num?)?.toInt() ?? 0,
      PeopleList.fromJson(data),
      draft is Map
          ? DraftSummary.fromJson(draft.cast<String, dynamic>())
          : null,
    );
  }

  Future<List<DraftSummary>> drafts(PersonRole role) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/imports/drafts',
      queryParameters: {'role': role.api},
    );
    return [
      for (final item in res.data?['data']?['items'] as List? ?? const [])
        if (item is Map) DraftSummary.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<(DraftSummary, PeopleList)> draft(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/imports/drafts/$id');
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    return (DraftSummary.fromJson(data), PeopleList.fromJson(data));
  }

  Future<DraftSummary> createDraft(
    PersonRole role,
    String name,
    List<PersonRow> rows,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/imports/drafts',
      data: {'role': role.api, 'name': name, 'rows': rows},
    );
    return DraftSummary.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  Future<DraftSummary> updateDraft(String id, List<PersonRow> rows) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/imports/drafts/$id',
      data: {'rows': rows},
    );
    return DraftSummary.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDraft(String id) =>
      _dio.delete<Map<String, dynamic>>('/imports/drafts/$id');
}

final peopleApiProvider = Provider<PeopleApi>(
  (ref) => PeopleApi(
    ref.watch(apiClientProvider),
    ref.watch(configProvider).apiBaseUrl,
  ),
);

final peopleDraftsProvider = FutureProvider.autoDispose
    .family<List<DraftSummary>, PersonRole>(
      (ref, role) => ref.watch(peopleApiProvider).drafts(role),
    );
