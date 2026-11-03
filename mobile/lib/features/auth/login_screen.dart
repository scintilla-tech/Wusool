import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'activation_screen.dart';
import 'auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController(text: 'KKU');
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _tenantController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(
          tenantCode: _tenantController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authProvider).errorMessage ?? 'تعذر تسجيل الدخول',
          ),
          backgroundColor: NdsColors.red700,
        ),
      );
    }
  }

  void _openActivation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivationScreen(
          tenantCode: _tenantController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Nds.backgroundDefault,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xl,
              vertical: Space.x5l,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: KkuLogo(width: 176)),
                      const SizedBox(height: Space.x2l),
                      Text(
                        'نظام النقل الجامعي للطالبات',
                        textAlign: TextAlign.center,
                        style: NdsText.displayXs.copyWith(
                          color: Nds.textDisplay,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'للطالبات والسائقين والمشرفين ومسؤولي النظام',
                        textAlign: TextAlign.center,
                        style: NdsText.textSm.copyWith(
                          color: Nds.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x5l),
                      NdsField(
                        label: 'رمز الجامعة',
                        controller: _tenantController,
                        icon: HugeIcons.strokeRoundedUniversity,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        helper: 'اتركه فارغاً لحساب إدارة المنصة',
                        // Optional: university accounts require it; platform accounts leave it blank.
                      ),
                      const SizedBox(height: Space.x2l),
                      NdsField(
                        label: 'رقم الجوال',
                        controller: _phoneController,
                        icon: HugeIcons.strokeRoundedSmartPhone01,
                        hint: '05XXXXXXXX',
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        validator: (v) => (v == null || v.trim().length < 9)
                            ? 'رقم جوال غير صحيح'
                            : null,
                      ),
                      const SizedBox(height: Space.x2l),
                      NdsField(
                        label: 'كلمة المرور',
                        controller: _passwordController,
                        icon: HugeIcons.strokeRoundedLockPassword,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'مطلوب' : null,
                        onFieldSubmitted: (_) {
                          if (!auth.busy) _submit();
                        },
                      ),
                      const SizedBox(height: Space.x3l),
                      ElevatedButton.icon(
                        onPressed: auth.busy ? null : _submit,
                        icon: auth.busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Nds.textSecondary,
                                ),
                              )
                            : const AppIcon(
                                HugeIcons.strokeRoundedLogin01,
                                size: 20,
                              ),
                        label: const Text('تسجيل الدخول'),
                      ),
                      const SizedBox(height: Space.lg),
                      TextButton(
                        onPressed: auth.busy ? null : _openActivation,
                        child: const Text('أول دخول؟ تفعيل الحساب برمز تحقق'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
