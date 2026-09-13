import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController(text: 'KSU');
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
    final ok = await ref.read(authProvider.notifier).login(
          tenantCode: _tenantController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).errorMessage ?? 'تعذر تسجيل الدخول'),
          backgroundColor: WaslColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.directions_bus, size: 56, color: WaslColors.emerald),
                  const SizedBox(height: 12),
                  const Text(
                    'وصــل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: WaslColors.navy,
                    ),
                  ),
                  const Text(
                    'النقل الجامعي للطالبات',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: WaslColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _tenantController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رمز الجامعة',
                      hintText: 'اتركه فارغاً لحساب المنصة',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    // Optional: university accounts require it; platform accounts leave it blank.
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجوال',
                      hintText: '05XXXXXXXX',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) => (v == null || v.trim().length < 9) ? 'رقم جوال غير صحيح' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: auth.busy ? null : _submit,
                    child: auth.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
