import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/ui.dart';
import 'admin_api.dart';

final _placeName = RegExp(r"^[\p{L}\p{M}\p{N}\s.'’()/-]+$", unicode: true);

String? _validName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'مطلوب';
  if (text.length > 100) return 'أطول من المسموح';
  if (!_placeName.hasMatch(text)) return 'يُكتب بالحروف والأرقام فقط';
  return null;
}

class CampusTile extends StatelessWidget {
  final Branch campus;
  final VoidCallback? onTap;

  const CampusTile({super.key, required this.campus, this.onTap});

  @override
  Widget build(BuildContext context) {
    return NdsListItem(
      leading: const FeaturedIcon(HugeIcons.strokeRoundedUniversity),
      title: campus.name,
      meta: [
        if (campus.code != null) ltr(campus.code!),
        campus.routeCount == 0 ? 'بلا مسارات' : routeCount(campus.routeCount),
      ].join(' · '),
      meta2: campus.hasArrivalArea
          ? 'تنتهي الرحلة تلقائياً عند الوصول'
          : 'لم يُحدَّد موقعه',
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

class NeighborhoodTile extends StatelessWidget {
  final Neighborhood hood;
  final VoidCallback? onTap;

  const NeighborhoodTile({super.key, required this.hood, this.onTap});

  @override
  Widget build(BuildContext context) {
    return NdsListItem(
      leading: const FeaturedIcon(
        HugeIcons.strokeRoundedLocation01,
        tone: Tone.neutral,
      ),
      title: hood.name,
      meta: hood.routeCount == 0
          ? 'لا تمر به مسارات'
          : 'يمر به ${routeCount(hood.routeCount)}',
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// Adds a campus, or edits [campus]; pops with the saved campus.
class CampusFormScreen extends ConsumerStatefulWidget {
  final Branch? campus;

  const CampusFormScreen({super.key, this.campus});

  @override
  ConsumerState<CampusFormScreen> createState() => _CampusFormScreenState();
}

class _CampusFormScreenState extends ConsumerState<CampusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.campus?.name);
  late final _code = TextEditingController(text: widget.campus?.code);
  late final _latitude = TextEditingController(
    text: widget.campus?.latitude?.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.campus?.longitude?.toString(),
  );
  late final _radius = TextEditingController(
    text: widget.campus?.radius?.round().toString(),
  );
  String? _codeError;
  bool _busy = false;
  bool _locating = false;
  bool _done = false;

  @override
  void dispose() {
    for (final controller in [_name, _code, _latitude, _longitude, _radius]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(TextEditingController c) => asciiDigits(c.text.trim());

  bool get _changed {
    final campus = widget.campus;
    return _name.text.trim() != (campus?.name ?? '') ||
        _code.text.trim() != (campus?.code ?? '') ||
        _text(_latitude) != (campus?.latitude?.toString() ?? '') ||
        _text(_longitude) != (campus?.longitude?.toString() ?? '') ||
        _text(_radius) != (campus?.radius?.round().toString() ?? '');
  }

  bool get _hasLocation =>
      _text(_latitude).isNotEmpty || _text(_longitude).isNotEmpty;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showMessage(context, 'اسمح للتطبيق بالوصول إلى الموقع', error: true);
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
        if (_radius.text.trim().isEmpty) _radius.text = '300';
      });
    } catch (_) {
      if (mounted) showMessage(context, 'تعذّر تحديد الموقع', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _coordinate(String? value, double limit) {
    final text = asciiDigits(value?.trim() ?? '');
    if (text.isEmpty) return _hasLocation ? 'مطلوب مع الإحداثي الآخر' : null;
    final number = double.tryParse(text);
    if (number == null || number.abs() > limit) return 'رقم غير صحيح';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });
    final editing = widget.campus != null;
    final code = _text(_code);
    final located = _hasLocation;
    double? number(TextEditingController c) => double.tryParse(_text(c));
    try {
      final saved = await ref.read(adminApiProvider).saveBranch(
        widget.campus?.id,
        {
          'name': _name.text.trim(),
          if (code.isNotEmpty) 'code': code else if (editing) 'code': null,
          if (located) ...{
            'latitude': number(_latitude),
            'longitude': number(_longitude),
            'radius': number(_radius),
          } else if (editing) ...{
            'latitude': null,
            'longitude': null,
            'radius': null,
          },
        },
      );
      if (!mounted) return;
      _done = true;
      refreshAdminData(ref);
      showMessage(context, editing ? 'حُفظت التعديلات' : 'أُضيف المقر');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      if (apiErrorCode(error) == 'CODE_TAKEN') {
        setState(() => _codeError = 'مستخدم لمقر آخر');
      } else {
        showMessage(context, adminFailure(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLeave() async {
    final discard = await showConfirmSheet(
      context,
      title: 'تجاهل التغييرات؟',
      message: 'لن يُحفظ ما أدخلته.',
      confirmLabel: 'تجاهل التغييرات',
      cancelLabel: 'متابعة التعديل',
      destructive: true,
    );
    if (discard && mounted) {
      _done = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.campus != null;
    void changed(String _) => setState(() {});
    return PopScope(
      canPop: _done || !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        appBar: NdsAppBar(title: editing ? 'تعديل المقر' : 'إضافة مقر'),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              NdsField(
                label: 'اسم المقر',
                controller: _name,
                hint: 'مثل: المقر الرئيسي',
                textInputAction: TextInputAction.next,
                onChanged: changed,
                validator: _validName,
              ),
              NdsField(
                label: 'الرمز (اختياري)',
                controller: _code,
                hint: 'مثل: MAIN',
                textDirection: TextDirection.ltr,
                errorText: _codeError,
                onChanged: (_) => setState(() => _codeError = null),
                validator: (value) =>
                    (value?.trim().length ?? 0) > 64 ? 'أطول من المسموح' : null,
              ),
              Section(
                title: 'موقع الوصول (اختياري)',
                trailing: TextButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: const AppIcon(HugeIcons.strokeRoundedGps01, size: 18),
                  label: const Text('موقعي الحالي'),
                ),
                children: [
                  const InlineNote(
                    'عند تحديده تنتهي الرحلة تلقائياً حين تدخل الحافلة هذا '
                    'النطاق. استخدم موقعك الحالي وأنت عند بوابة المقر، أو '
                    'انسخ الإحداثيات من الخريطة.',
                  ),
                  NdsField(
                    label: 'خط العرض',
                    controller: _latitude,
                    hint: '18.2465',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: changed,
                    validator: (value) => _coordinate(value, 90),
                  ),
                  NdsField(
                    label: 'خط الطول',
                    controller: _longitude,
                    hint: '42.5117',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: changed,
                    validator: (value) => _coordinate(value, 180),
                  ),
                  NdsField(
                    label: 'نطاق الوصول بالمتر',
                    controller: _radius,
                    hint: '300',
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    onChanged: changed,
                    validator: (value) {
                      final text = asciiDigits(value?.trim() ?? '');
                      if (text.isEmpty) {
                        return _hasLocation ? 'مطلوب مع الموقع' : null;
                      }
                      final metres = double.tryParse(text);
                      return metres == null || metres <= 0 || metres > 5000
                          ? 'من 1 إلى 5000 متر'
                          : null;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: [
            ElevatedButton(
              onPressed: _busy || (editing && !_changed) ? null : _save,
              child: Text(editing ? 'حفظ التعديلات' : 'إضافة المقر'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds a neighborhood, or renames [hood]; pops with the saved one.
class NeighborhoodFormScreen extends ConsumerStatefulWidget {
  final Neighborhood? hood;

  const NeighborhoodFormScreen({super.key, this.hood});

  @override
  ConsumerState<NeighborhoodFormScreen> createState() =>
      _NeighborhoodFormScreenState();
}

class _NeighborhoodFormScreenState
    extends ConsumerState<NeighborhoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.hood?.name);
  String? _nameError;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim() != (widget.hood?.name ?? '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _nameError = null;
    });
    final api = ref.read(adminApiProvider);
    final name = _name.text.trim();
    try {
      final saved = widget.hood == null
          ? await api.createNeighborhood(name)
          : await api.renameNeighborhood(widget.hood!.id, name);
      if (!mounted) return;
      _done = true;
      refreshAdminData(ref);
      showMessage(
        context,
        widget.hood == null ? 'أُضيف الحي' : 'غُيّر اسم الحي',
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      if (apiErrorCode(error) == 'NAME_TAKEN') {
        setState(() => _nameError = 'يوجد حي بهذا الاسم');
      } else {
        showMessage(context, adminFailure(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hood = widget.hood;
    return PopScope(
      canPop: _done || !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showConfirmSheet(
          context,
          title: 'تجاهل التغييرات؟',
          message: 'لن يُحفظ ما أدخلته.',
          confirmLabel: 'تجاهل التغييرات',
          cancelLabel: 'متابعة التعديل',
          destructive: true,
        );
        if (discard && context.mounted) {
          _done = true;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: NdsAppBar(title: hood == null ? 'إضافة حي' : 'تعديل الحي'),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              NdsField(
                label: 'اسم الحي',
                controller: _name,
                hint: 'مثل: المنسك',
                errorText: _nameError,
                onChanged: (_) => setState(() => _nameError = null),
                validator: _validName,
              ),
              if (hood != null && hood.routeCount > 0)
                InlineNote(
                  'يظهر الاسم الجديد في كل مسار يمر بهذا الحي '
                  '(${routeCount(hood.routeCount)}).',
                ),
            ],
          ),
        ),
        bottomNavigationBar: NdsFooter(
          children: [
            ElevatedButton(
              onPressed: _busy || !_changed ? null : _save,
              child: Text(hood == null ? 'إضافة الحي' : 'حفظ الاسم'),
            ),
          ],
        ),
      ),
    );
  }
}
