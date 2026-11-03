import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../admin/admin_api.dart' show Branch, Neighborhood;
import '../admin/pickers.dart';
import '../admin/route_screens.dart' show StopsEditor;
import 'driver_providers.dart';

/// Campuses and neighborhoods a driver builds their route from.
class RouteOptions {
  final List<Branch> campuses;
  final List<Neighborhood> neighborhoods;

  const RouteOptions(this.campuses, this.neighborhoods);
}

final driverRouteOptionsProvider = FutureProvider.autoDispose<RouteOptions>((
  ref,
) async {
  final res = await ref
      .watch(apiClientProvider)
      .dio
      .get<Map<String, dynamic>>('/driver/route-options');
  final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
  return RouteOptions(
    [
      for (final c in data['campuses'] as List? ?? const [])
        if (c is Map) Branch(c['id'] as String, c['name'] as String? ?? ''),
    ],
    [
      for (final n in data['neighborhoods'] as List? ?? const [])
        if (n is Map)
          Neighborhood(n['id'] as String, n['name'] as String? ?? ''),
    ],
  );
});

final _placeName = RegExp(r"^[\p{L}\p{M}\p{N}\s.'’()/-]+$", unicode: true);

/// A driver builds their bus's route once (name, campus, stops in order);
/// it becomes the bus's fixed route and trips are made from it every school
/// day. With [route], edits it. Pops true once saved.
class DriverRouteScreen extends ConsumerStatefulWidget {
  final DriverRoute? route;

  const DriverRouteScreen({super.key, this.route});

  @override
  ConsumerState<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends ConsumerState<DriverRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.route?.name);
  late String? _campusId = widget.route?.campusId;
  late final List<Neighborhood> _stops = [...?widget.route?.stops];
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed {
    final route = widget.route;
    final before = route?.stops.map((stop) => stop.id).join(',') ?? '';
    return _name.text.trim() != (route?.name ?? '') ||
        _campusId != route?.campusId ||
        _stops.map((stop) => stop.id).join(',') != before;
  }

  Future<void> _addStop() async {
    final dio = ref.read(apiClientProvider).dio;
    final hood = await Navigator.of(context).push<Neighborhood>(
      MaterialPageRoute(
        builder: (_) => PickNeighborhoodScreen(
          exclude: {for (final stop in _stops) stop.id},
          search: (q) async {
            final all = (await ref.read(driverRouteOptionsProvider.future))
                .neighborhoods;
            final query = q.trim().toLowerCase();
            return [
              for (final hood in all)
                if (query.isEmpty || hood.name.toLowerCase().contains(query))
                  hood,
            ];
          },
          create: (name) async {
            final res = await dio.post<Map<String, dynamic>>(
              '/driver/neighborhoods',
              data: {'name': name},
            );
            ref.invalidate(driverRouteOptionsProvider);
            return Neighborhood.fromJson(
              res.data?['data'] as Map<String, dynamic>,
            );
          },
        ),
      ),
    );
    if (hood != null && mounted) setState(() => _stops.add(hood));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stops.isEmpty) {
      showMessage(context, 'أضف محطة واحدة على الأقل', error: true);
      return;
    }
    setState(() => _busy = true);
    final creating = widget.route == null;
    final body = {
      'name': _name.text.trim(),
      'branchId': _campusId,
      'stopIds': [for (final stop in _stops) stop.id],
    };
    try {
      final dio = ref.read(apiClientProvider).dio;
      if (creating) {
        await dio.post<Map<String, dynamic>>('/driver/route', data: body);
      } else {
        await dio.patch<Map<String, dynamic>>('/driver/route', data: body);
      }
      if (!mounted) return;
      _done = true;
      ref.invalidate(driverBusProvider);
      showMessage(
        context,
        creating
            ? 'أصبح «${body['name']}» مسار حافلتك؛ تُجدول رحلاتها كل يوم دراسي'
            : 'حُفظ المسار',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, _failure(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _failure(Object error) => switch (apiErrorCode(error)) {
    'ROUTE_EXISTS' => 'لحافلتك مسار؛ حدّث الصفحة لتعديله',
    'NO_ROUTE' => 'ليس لحافلتك مسار بعد',
    'NO_BUS' => 'لست معيّناً على حافلة',
    'DUPLICATE_STOP' => 'لا يتكرر الحي في المسار نفسه',
    'VALIDATION_ERROR' => 'بعض القيم غير صحيحة',
    _ => 'تعذّر حفظ المسار، حاول مرة أخرى',
  };

  Future<void> _onLeave() async {
    final discard = await showConfirmSheet(
      context,
      title: 'تجاهل التغييرات؟',
      message: 'لن يُحفظ المسار.',
      confirmLabel: 'تجاهل التغييرات',
      cancelLabel: 'متابعة التعديل',
      destructive: true,
    );
    if (discard && mounted) {
      _done = true;
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.route == null;
    final campuses =
        ref.watch(driverRouteOptionsProvider).value?.campuses ?? const [];
    return PopScope(
      canPop: _done || !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(title: creating ? 'مسار حافلتك' : 'تعديل المسار'),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              if (creating)
                const InlineNote(
                  'أنشئه مرة واحدة: يصبح المسار الثابت لحافلتك وتُنشأ رحلاتها '
                  'تلقائياً كل يوم دراسي، ويمكنك تعديله لاحقاً. تضيف الإدارة '
                  'الطالبات إليه.',
                ),
              NdsField(
                label: 'اسم المسار',
                controller: _name,
                hint: 'مثل: مسار حي النرجس',
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'مطلوب';
                  if (text.length > 100) return 'أطول من المسموح';
                  if (!_placeName.hasMatch(text)) {
                    return 'يُكتب بالحروف والأرقام فقط';
                  }
                  return null;
                },
              ),
              if (campuses.isNotEmpty)
                NdsGroup(
                  children: [
                    Text(
                      'المقر',
                      style: NdsText.textSm.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Nds.textDefault,
                      ),
                    ),
                    NdsChoiceChips<String?>(
                      options: [
                        (null, 'بدون'),
                        for (final campus in campuses) (campus.id, campus.name),
                      ],
                      selected: _campusId,
                      onSelected: (value) => setState(() => _campusId = value),
                    ),
                  ],
                ),
              StopsEditor(
                stops: _stops,
                onAdd: _addStop,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: [
            ElevatedButton.icon(
              onPressed: _busy || (!creating && !_changed) ? null : _save,
              icon: const AppIcon(HugeIcons.strokeRoundedRoute01, size: 20),
              label: Text(creating ? 'إنشاء المسار' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }
}
