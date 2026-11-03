import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'auth_state.dart';

/// First sign-in for an account an admin added: a one-time code sent to the
/// registered phone proves ownership, then the person chooses a password.
class ActivationScreen extends ConsumerStatefulWidget {
  final String tenantCode;
  final String phone;

  const ActivationScreen({super.key, this.tenantCode = '', this.phone = ''});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phoneForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  late final _tenant = TextEditingController(
    text: widget.tenantCode.isEmpty ? 'KKU' : widget.tenantCode,
  );
  late final _phone = TextEditingController(text: widget.phone);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  String? _devCode;

  @override
  void dispose() {
    for (final controller in [_tenant, _phone, _code, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_phoneForm.currentState?.validate() ?? true)) return;
    setState(() => _sending = true);
    try {
      final devCode = await ref
          .read(authProvider.notifier)
          .requestActivationCode(tenantCode: _tenant.text, phone: _phone.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devCode = devCode;
      });
      showMessage(context, 'أُرسل الرمز إن كان الرقم مسجّلاً');
    } catch (_) {
      if (mounted) {
        showMessage(context, 'تعذّر إرسال الرمز، حاول بعد قليل', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _activate() async {
    if (!_codeForm.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .activate(
          tenantCode: _tenant.text,
          phone: _phone.text,
          code: _digits(_code.text),
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      // The app shows the role's home under this screen once signed in.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showMessage(
        context,
        ref.read(authProvider).errorMessage ?? 'تعذر تفعيل الحساب',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authProvider).busy;
    return Scaffold(
      appBar: const NdsAppBar(title: 'تفعيل الحساب'),
      body: PageBody(
        children: [
          const PageHeading(
            'أول دخول',
            lead:
                'يصل رمز من 6 أرقام إلى رقم الجوال المسجّل لدى الجامعة '
                'لتعيين كلمة المرور.',
          ),
          Form(
            key: _phoneForm,
            child: NdsGroup(
              gap: Space.x2l,
              children: [
                NdsField(
                  label: 'رمز الجامعة',
                  controller: _tenant,
                  icon: HugeIcons.strokeRoundedUniversity,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                NdsField(
                  label: 'رقم الجوال',
                  controller: _phone,
                  icon: HugeIcons.strokeRoundedSmartPhone01,
                  hint: '05XXXXXXXX',
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (v) => (v == null || v.trim().length < 9)
                      ? 'رقم جوال غير صحيح'
                      : null,
                  onChanged: (_) {
                    if (_codeSent) setState(() => _codeSent = false);
                  },
                ),
              ],
            ),
          ),
          if (!_codeSent)
            ElevatedButton.icon(
              onPressed: _sending ? null : _sendCode,
              icon: const AppIcon(HugeIcons.strokeRoundedMessage01, size: 20),
              label: const Text('إرسال رمز التحقق'),
            )
          else
            Form(
              key: _codeForm,
              child: AutofillGroup(
                child: NdsGroup(
                  gap: Space.x2l,
                  children: [
                    const InlineNote(
                      'إن كان الرقم مسجّلاً لحساب لم يُفعّل بعد، يصل إليه '
                      'رمز صالح لمدة 5 دقائق.',
                    ),
                    if (_devCode != null)
                      NdsAlert(
                        status: TagStatus.info,
                        title: 'رمز التجربة: ${ltr(_devCode!)}',
                        description: 'يظهر في بيئة التطوير فقط لعدم ربط الرسائل النصية بعد.',
                      ),
                    NdsField(
                      label: 'رمز التحقق',
                      controller: _code,
                      icon: HugeIcons.strokeRoundedKey01,
                      hint: '000000',
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch(_digits(v ?? ''))
                          ? null
                          : 'الرمز من 6 أرقام',
                    ),
                    NdsField(
                      label: 'كلمة المرور الجديدة',
                      controller: _password,
                      icon: HugeIcons.strokeRoundedLockPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      helper: '8 أحرف على الأقل',
                      validator: (v) => (v == null || v.length < 8)
                          ? '8 أحرف على الأقل'
                          : null,
                    ),
                    NdsField(
                      label: 'تأكيد كلمة المرور',
                      controller: _confirm,
                      icon: HugeIcons.strokeRoundedLockPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => v == _password.text
                          ? null
                          : 'كلمتا المرور غير متطابقتين',
                      onFieldSubmitted: (_) {
                        if (!busy) _activate();
                      },
                    ),
                    ElevatedButton(
                      onPressed: busy ? null : _activate,
                      child: const Text('تفعيل الحساب والدخول'),
                    ),
                    TextButton(
                      onPressed: _sending ? null : _sendCode,
                      child: const Text('إعادة إرسال الرمز'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Codes typed on an Arabic keyboard arrive as Arabic-Indic digits.
  String _digits(String value) => value.trim().replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
  );
}
