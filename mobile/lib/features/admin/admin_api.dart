/// The university admin's directory of people, buses and routes, and who is
/// assigned where. Mirrors `backend/src/modules/people`, `structure` and
/// `assignments`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/ui.dart';
import 'admin_providers.dart';
import 'people.dart';

typedef Json = Map<String, dynamic>;

Json _map(Object? raw) => raw is Map ? raw.cast<String, dynamic>() : const {};

List<Json> _list(Object? raw) => [
  for (final item in raw is List ? raw : const []) _map(item),
];

int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;

class RouteRef {
  final String id;
  final String name;
  final String? code;
  final bool isActive;

  const RouteRef({
    required this.id,
    required this.name,
    this.code,
    this.isActive = true,
  });

  static RouteRef? fromJson(Object? raw) {
    final m = _map(raw);
    if (m['id'] == null) return null;
    return RouteRef(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      code: m['code'] as String?,
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}

class BusRef {
  final String id;
  final String plateNumber;
  final String? name;
  final bool isActive;

  const BusRef({
    required this.id,
    required this.plateNumber,
    this.name,
    this.isActive = true,
  });

  /// The bus's name, or its plate when it has none.
  String get label => name ?? ltr(plateNumber);

  static BusRef? fromJson(Object? raw) {
    final m = _map(raw);
    if (m['id'] == null) return null;
    return BusRef(
      id: m['id'] as String,
      plateNumber: m['plateNumber'] as String? ?? '',
      name: m['name'] as String?,
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}

/// A driver or supervisor as a bus shows them.
class StaffRef {
  final String id;
  final String profileId;
  final String firstName;
  final String lastName;
  final String phone;
  final bool isActive;

  const StaffRef({
    required this.id,
    required this.profileId,
    required this.firstName,
    required this.lastName,
    this.phone = '',
    this.isActive = true,
  });

  String get fullName => '$firstName $lastName';

  static StaffRef? fromJson(Object? raw) {
    final m = _map(raw);
    if (m['id'] == null) return null;
    return StaffRef(
      id: m['id'] as String,
      profileId: m['profileId'] as String? ?? '',
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}

/// A student or staff member in the admin's lists.
class Person {
  final String id;

  /// The role profile's id, which assignments refer to.
  final String profileId;
  final PersonRole role;
  final String firstName;
  final String lastName;
  final String phone;

  /// University number for students, employee number for staff.
  final String? number;
  final bool isActive;

  /// False until the person signs in for the first time and sets a password.
  final bool isActivated;
  final RouteRef? route;
  final BusRef? bus;

  const Person({
    required this.id,
    required this.profileId,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.number,
    this.isActive = true,
    this.isActivated = true,
    this.route,
    this.bus,
  });

  String get fullName => '$firstName $lastName';

  /// Students ride routes; drivers and supervisors work on buses.
  bool get isAssigned => role.isStudent ? route != null : bus != null;

  factory Person.fromJson(Json m) => Person(
    id: m['id'] as String? ?? '',
    profileId: m['profileId'] as String? ?? '',
    role: PersonRole.fromApi(m['role'] as String?),
    firstName: m['firstName'] as String? ?? '',
    lastName: m['lastName'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    number: m['number'] as String?,
    isActive: m['isActive'] as bool? ?? true,
    isActivated: m['isActivated'] as bool? ?? true,
    route: RouteRef.fromJson(m['route']),
    bus: BusRef.fromJson(m['bus']),
  );
}

class PersonDetail extends Person {
  /// The editable values, as the forms show them.
  final PersonRow row;

  PersonDetail.fromJson(Json m)
    : row = rowFromJson(m['row']),
      super(
        id: m['id'] as String? ?? '',
        profileId: m['profileId'] as String? ?? '',
        role: PersonRole.fromApi(m['role'] as String?),
        firstName: m['firstName'] as String? ?? '',
        lastName: m['lastName'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        number: m['number'] as String?,
        isActive: m['isActive'] as bool? ?? true,
        isActivated: m['isActivated'] as bool? ?? true,
        route: RouteRef.fromJson(m['route']),
        bus: BusRef.fromJson(m['bus']),
      );
}

enum PersonStatus {
  all('all'),
  active('active'),
  pending('pending'),
  disabled('disabled'),
  unassigned('unassigned');

  final String api;

  const PersonStatus(this.api);
}

class Neighborhood {
  final String id;
  final String name;

  /// Routes in service that stop here.
  final int routeCount;

  const Neighborhood(this.id, this.name, {this.routeCount = 0});

  factory Neighborhood.fromJson(Json m) => Neighborhood(
    m['id'] as String? ?? '',
    m['name'] as String? ?? '',
    routeCount: _int(m['routeCount']),
  );

  @override
  bool operator ==(Object other) => other is Neighborhood && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A campus. Its location and radius let a trip end on its own when the bus
/// arrives.
class Branch {
  final String id;
  final String name;
  final String? code;
  final double? latitude;
  final double? longitude;

  /// Metres around the location that count as arrived.
  final double? radius;

  /// Routes in service that go to this campus.
  final int routeCount;

  const Branch(
    this.id,
    this.name, {
    this.code,
    this.latitude,
    this.longitude,
    this.radius,
    this.routeCount = 0,
  });

  bool get hasArrivalArea =>
      latitude != null && longitude != null && radius != null;

  factory Branch.fromJson(Json m) => Branch(
    m['id'] as String? ?? '',
    m['name'] as String? ?? '',
    code: m['code'] as String?,
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    radius: (m['radius'] as num?)?.toDouble(),
    routeCount: _int(m['routeCount']),
  );
}

class AdminBus {
  final String id;
  final String plateNumber;
  final String? name;
  final int? capacity;
  final bool isActive;
  final StaffRef? driver;
  final StaffRef? supervisor;

  /// The route the bus runs every school day.
  final RouteRef? route;

  const AdminBus({
    required this.id,
    required this.plateNumber,
    this.name,
    this.capacity,
    this.isActive = true,
    this.driver,
    this.supervisor,
    this.route,
  });

  String get label => name ?? ltr(plateNumber);

  factory AdminBus.fromJson(Json m) => AdminBus(
    id: m['id'] as String? ?? '',
    plateNumber: m['plateNumber'] as String? ?? '',
    name: m['name'] as String?,
    capacity: (m['capacity'] as num?)?.toInt(),
    isActive: m['isActive'] as bool? ?? true,
    driver: StaffRef.fromJson(m['driver']),
    supervisor: StaffRef.fromJson(m['supervisor']),
    route: RouteRef.fromJson(m['route']),
  );
}

class AdminRoute {
  final String id;
  final String name;
  final String? code;
  final bool isActive;
  final Branch? branch;

  /// In the order the route visits them.
  final List<Neighborhood> stops;
  final int studentCount;

  /// The bus that runs the route every school day.
  final BusRef? bus;

  const AdminRoute({
    required this.id,
    required this.name,
    this.code,
    this.isActive = true,
    this.branch,
    this.stops = const [],
    this.studentCount = 0,
    this.bus,
  });

  /// "النرجس ← الملقا ← الياسمين". Each name is isolated so that Arabic and
  /// Latin names still read in visiting order.
  String get stopsLine =>
      stops.map((stop) => '\u2068${stop.name}\u2069').join(' ← ');

  factory AdminRoute.fromJson(Json m) {
    final branch = _map(m['branch']);
    return AdminRoute(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      code: m['code'] as String?,
      isActive: m['isActive'] as bool? ?? true,
      branch: branch['id'] == null ? null : Branch.fromJson(branch),
      stops: [
        for (final stop in _list(m['routeNeighborhoods']))
          Neighborhood.fromJson(_map(stop['neighborhood'])),
      ],
      studentCount: _int(m['studentCount']),
      bus: BusRef.fromJson(m['bus']),
    );
  }
}

/// One page of a list, and how many there are in all.
class PageOf<T> {
  final List<T> items;
  final int total;
  final int page;

  /// People per status (`PersonStatus.api`), for the filter chips.
  final Map<String, int> counts;

  const PageOf(this.items, this.total, this.page, {this.counts = const {}});
}

/// The search and filters of a people list.
typedef PeopleQuery = ({
  PersonRole role,
  String search,
  PersonStatus status,

  /// Students of this route, or "none" for those without one.
  String? routeId,

  /// Drivers or supervisors of this bus, or "none" for those without one.
  String? busId,
});

PeopleQuery peopleQuery(
  PersonRole role, {
  String search = '',
  PersonStatus status = PersonStatus.all,
  String? routeId,
  String? busId,
}) => (
  role: role,
  search: search,
  status: status,
  routeId: routeId,
  busId: busId,
);

/// The search of a bus or route list.
typedef StructureQuery = ({String search, bool activeOnly});

/// What happened when the admin saved a person's details.
class SaveOutcome {
  final PersonDetail? person;
  final List<RowIssue> issues;

  const SaveOutcome(this.person, this.issues);

  bool get saved => person != null;
}

class AdminApi {
  static const pageSize = 30;

  final ApiClient _api;

  AdminApi(this._api);

  Dio get _dio => _api.dio;

  Future<Json> _get(String path, [Map<String, Object?>? query]) async {
    final res = await _dio.get<Json>(
      path,
      queryParameters: {
        for (final MapEntry(:key, :value) in (query ?? const {}).entries)
          if (value != null && value != '') key: value,
      },
    );
    return _map(res.data?['data']);
  }

  Future<Json> _send(String method, String path, [Object? body]) async {
    final res = await _dio.request<Json>(
      path,
      data: body,
      options: Options(method: method),
    );
    return _map(res.data?['data']);
  }

  PageOf<T> _page<T>(Json data, T Function(Json) parse) {
    final counts = _map(data['counts']);
    return PageOf(
      [for (final item in _list(data['items'])) parse(item)],
      _int(data['total']),
      _int(data['page']),
      counts: {for (final e in counts.entries) e.key: _int(e.value)},
    );
  }

  // ----- People -----

  Future<PageOf<Person>> people(PeopleQuery query, {int page = 1}) async =>
      _page(
        await _get('/people', {
          'role': query.role.api,
          'q': query.search.trim(),
          'status': query.status.api,
          'routeId': query.routeId,
          'busId': query.busId,
          'page': page,
          'limit': pageSize,
        }),
        Person.fromJson,
      );

  Future<PersonDetail> person(String id) async =>
      PersonDetail.fromJson(await _get('/people/$id'));

  Future<SaveOutcome> updatePerson(String id, PersonRow row) async {
    final data = await _send('PUT', '/people/$id', {'row': row});
    if (data['saved'] == true) {
      return SaveOutcome(PersonDetail.fromJson(_map(data['person'])), const []);
    }
    return SaveOutcome(null, [
      for (final issue in _list(data['issues'])) RowIssue.fromJson(issue),
    ]);
  }

  Future<PersonDetail> setPersonEnabled(String id, bool enabled) async =>
      PersonDetail.fromJson(
        await _send('POST', '/people/$id/${enabled ? 'enable' : 'disable'}'),
      );

  // ----- Buses -----

  Future<PageOf<AdminBus>> buses(StructureQuery query, {int page = 1}) async =>
      _page(
        await _get('/structure/buses', {
          'q': query.search.trim(),
          'active': query.activeOnly ? 'true' : null,
          'page': page,
          'limit': pageSize,
        }),
        AdminBus.fromJson,
      );

  Future<AdminBus> bus(String id) async =>
      AdminBus.fromJson(await _get('/structure/buses/$id'));

  /// Creates the bus when [id] is null.
  Future<AdminBus> saveBus(String? id, Json values) async => AdminBus.fromJson(
    id == null
        ? await _send('POST', '/structure/buses', values)
        : await _send('PATCH', '/structure/buses/$id', values),
  );

  Future<AdminBus> setBusEnabled(String id, bool enabled) async =>
      AdminBus.fromJson(
        enabled
            ? await _send('PATCH', '/structure/buses/$id', {'isActive': true})
            : await _send('DELETE', '/structure/buses/$id'),
      );

  // ----- Routes -----

  Future<PageOf<AdminRoute>> routes(
    StructureQuery query, {
    int page = 1,
  }) async => _page(
    await _get('/structure/routes', {
      'q': query.search.trim(),
      'active': query.activeOnly ? 'true' : null,
      'page': page,
      'limit': pageSize,
    }),
    AdminRoute.fromJson,
  );

  Future<AdminRoute> route(String id) async =>
      AdminRoute.fromJson(await _get('/structure/routes/$id'));

  /// Creates the route when [id] is null.
  Future<AdminRoute> saveRoute(String? id, Json values) async =>
      AdminRoute.fromJson(
        id == null
            ? await _send('POST', '/structure/routes', values)
            : await _send('PATCH', '/structure/routes/$id', values),
      );

  Future<AdminRoute> setRouteEnabled(String id, bool enabled) async =>
      AdminRoute.fromJson(
        enabled
            ? await _send('PATCH', '/structure/routes/$id', {'isActive': true})
            : await _send('DELETE', '/structure/routes/$id'),
      );

  Future<PageOf<Branch>> branchPage(
    StructureQuery query, {
    int page = 1,
  }) async => _page(
    await _get('/structure/branches', {
      'q': query.search.trim(),
      'active': query.activeOnly ? 'true' : null,
      'page': page,
      'limit': pageSize,
    }),
    Branch.fromJson,
  );

  /// Creates the campus when [id] is null.
  Future<Branch> saveBranch(String? id, Json values) async => Branch.fromJson(
    id == null
        ? await _send('POST', '/structure/branches', values)
        : await _send('PATCH', '/structure/branches/$id', values),
  );

  Future<PageOf<Neighborhood>> neighborhoodPage(
    StructureQuery query, {
    int page = 1,
  }) async => _page(
    await _get('/structure/neighborhoods', {
      'q': query.search.trim(),
      'active': 'true',
      'page': page,
      'limit': pageSize,
    }),
    Neighborhood.fromJson,
  );

  Future<Neighborhood> renameNeighborhood(String id, String name) async =>
      Neighborhood.fromJson(
        await _send('PATCH', '/structure/neighborhoods/$id', {'name': name}),
      );

  Future<List<Neighborhood>> neighborhoods(String search) async => [
    for (final item in _list(
      (await _get('/structure/neighborhoods', {
        'q': search.trim(),
        'active': 'true',
        'limit': 100,
      }))['items'],
    ))
      Neighborhood.fromJson(item),
  ];

  Future<Neighborhood> createNeighborhood(String name) async =>
      Neighborhood.fromJson(
        await _send('POST', '/structure/neighborhoods', {'name': name}),
      );

  Future<List<Branch>> branches() async => [
    for (final item in _list(
      (await _get('/structure/branches', {
        'active': 'true',
        'limit': 100,
      }))['items'],
    ))
      Branch.fromJson(item),
  ];

  // ----- Assignments -----

  /// Students on another route move to this one.
  Future<int> assignStudents(String routeId, List<String> profileIds) async =>
      _int(
        (await _send('POST', '/assignments/students/batch', {
          'routeId': routeId,
          'studentProfileIds': profileIds,
        }))['assigned'],
      );

  Future<void> unassignStudent(String profileId) =>
      _send('DELETE', '/assignments/students/$profileId');

  /// Puts a driver or supervisor on [busId], replacing whoever was there and
  /// taking them off any other bus.
  Future<void> assignToBus(PersonRole role, String profileId, String busId) =>
      _send(
        'POST',
        role == PersonRole.driver
            ? '/assignments/drivers'
            : '/assignments/supervisors',
        {
          role == PersonRole.driver ? 'driverProfileId' : 'supervisorProfileId':
              profileId,
          'busId': busId,
        },
      );

  Future<void> unassignFromBus(PersonRole role, String busId) => _send(
    'DELETE',
    role == PersonRole.driver
        ? '/assignments/drivers/$busId'
        : '/assignments/supervisors/$busId',
  );
}

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(apiClientProvider)),
);

/// A list loaded page by page as the admin scrolls.
class Paged<T> {
  final List<T> items;
  final int total;
  final int page;
  final Map<String, int> counts;
  final bool loadingMore;

  /// Set when the last attempt to load more failed.
  final Object? moreError;

  const Paged({
    required this.items,
    required this.total,
    required this.page,
    this.counts = const {},
    this.loadingMore = false,
    this.moreError,
  });

  bool get hasMore => items.length < total;

  int count(PersonStatus status) => counts[status.api] ?? 0;
}

abstract class PagedNotifier<T> extends AsyncNotifier<Paged<T>> {
  Future<PageOf<T>> fetch(int page);

  /// Identifies an item, so one shifted to the next page by a newly added
  /// item is not shown twice.
  String idOf(T item);

  @override
  Future<Paged<T>> build() async {
    final first = await fetch(1);
    return Paged(
      items: first.items,
      total: first.total,
      page: 1,
      counts: first.counts,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (state.isLoading) return;
    state = AsyncData(_with(current, loadingMore: true));
    try {
      final next = await fetch(current.page + 1);
      if (!ref.mounted) return;
      final seen = {for (final item in current.items) idOf(item)};
      final items = [
        ...current.items,
        for (final item in next.items)
          if (!seen.contains(idOf(item))) item,
      ];
      state = AsyncData(
        Paged(
          items: items,
          // A short page means the list ended, whatever the total said.
          total: next.items.length < AdminApi.pageSize
              ? items.length
              : next.total,
          page: current.page + 1,
          counts: next.counts.isEmpty ? current.counts : next.counts,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(_with(current, moreError: error));
    }
  }

  Paged<T> _with(Paged<T> p, {bool loadingMore = false, Object? moreError}) =>
      Paged(
        items: p.items,
        total: p.total,
        page: p.page,
        counts: p.counts,
        loadingMore: loadingMore,
        moreError: moreError,
      );
}

class PeopleDirectory extends PagedNotifier<Person> {
  final PeopleQuery query;

  PeopleDirectory(this.query);

  @override
  Future<PageOf<Person>> fetch(int page) =>
      ref.read(adminApiProvider).people(query, page: page);

  @override
  String idOf(Person item) => item.id;
}

final peopleDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<PeopleDirectory, Paged<Person>, PeopleQuery>(PeopleDirectory.new);

class BusDirectory extends PagedNotifier<AdminBus> {
  final StructureQuery query;

  BusDirectory(this.query);

  @override
  Future<PageOf<AdminBus>> fetch(int page) =>
      ref.read(adminApiProvider).buses(query, page: page);

  @override
  String idOf(AdminBus item) => item.id;
}

final busDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<BusDirectory, Paged<AdminBus>, StructureQuery>(BusDirectory.new);

class RouteDirectory extends PagedNotifier<AdminRoute> {
  final StructureQuery query;

  RouteDirectory(this.query);

  @override
  Future<PageOf<AdminRoute>> fetch(int page) =>
      ref.read(adminApiProvider).routes(query, page: page);

  @override
  String idOf(AdminRoute item) => item.id;
}

final routeDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<RouteDirectory, Paged<AdminRoute>, StructureQuery>(
      RouteDirectory.new,
    );

final personProvider = FutureProvider.autoDispose.family<PersonDetail, String>(
  (ref, id) => ref.watch(adminApiProvider).person(id),
);

final busProvider = FutureProvider.autoDispose.family<AdminBus, String>(
  (ref, id) => ref.watch(adminApiProvider).bus(id),
);

final routeProvider = FutureProvider.autoDispose.family<AdminRoute, String>(
  (ref, id) => ref.watch(adminApiProvider).route(id),
);

class BranchDirectory extends PagedNotifier<Branch> {
  final StructureQuery query;

  BranchDirectory(this.query);

  @override
  Future<PageOf<Branch>> fetch(int page) =>
      ref.read(adminApiProvider).branchPage(query, page: page);

  @override
  String idOf(Branch item) => item.id;
}

final branchDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<BranchDirectory, Paged<Branch>, StructureQuery>(
      BranchDirectory.new,
    );

class NeighborhoodDirectory extends PagedNotifier<Neighborhood> {
  final StructureQuery query;

  NeighborhoodDirectory(this.query);

  @override
  Future<PageOf<Neighborhood>> fetch(int page) =>
      ref.read(adminApiProvider).neighborhoodPage(query, page: page);

  @override
  String idOf(Neighborhood item) => item.id;
}

final neighborhoodDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<NeighborhoodDirectory, Paged<Neighborhood>, StructureQuery>(
      NeighborhoodDirectory.new,
    );

final branchesProvider = FutureProvider.autoDispose<List<Branch>>(
  (ref) => ref.watch(adminApiProvider).branches(),
);

/// After a change to people, buses or routes: every list and screen showing
/// them loads again, as does the dashboard's figures.
void refreshAdminData(WidgetRef ref) {
  ref.invalidate(peopleDirectoryProvider);
  ref.invalidate(busDirectoryProvider);
  ref.invalidate(routeDirectoryProvider);
  ref.invalidate(personProvider);
  ref.invalidate(busProvider);
  ref.invalidate(routeProvider);
  ref.invalidate(branchDirectoryProvider);
  ref.invalidate(neighborhoodDirectoryProvider);
  ref.invalidate(branchesProvider);
  ref.invalidate(adminDashboardProvider);
}

/// A failed admin request in words.
String adminFailure(Object error) => switch (apiErrorCode(error)) {
  'PLATE_TAKEN' => 'رقم اللوحة مسجّل لحافلة أخرى',
  'CODE_TAKEN' => 'هذا الرمز مستخدم لمسار آخر',
  'INVALID_STUDENTS' => 'بعض الطالبات معطّلات أو لم يعدن موجودات',
  'NOT_FOUND' => 'لم يعد موجوداً، حدّث الصفحة',
  'DUPLICATE_STOP' => 'لا يتكرر الحي في المسار نفسه',
  'ROUTE_TAKEN' => 'تشغّل هذا المسارَ حافلةٌ أخرى',
  'NAME_TAKEN' => 'يوجد حي بهذا الاسم',
  'RATE_LIMITED' => 'محاولات كثيرة، حاول بعد قليل',
  'VALIDATION_ERROR' => 'بعض القيم غير صحيحة',
  _ => 'تعذّر الاتصال بالخادم، حاول مرة أخرى',
};
