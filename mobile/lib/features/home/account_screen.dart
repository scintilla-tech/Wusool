import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../auth/auth_state.dart';

/// Account tab for staff roles: who is signed in, a few details, sign out.
class AccountScreen extends ConsumerWidget {
  final String roleLabel;
  final List<KvEntry> details;

  const AccountScreen({
    super.key,
    required this.roleLabel,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: const NdsAppBar(title: 'حسابي'),
      body: PageBody(
        children: [
          ProfileHeader(
            name: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
            meta: roleLabel,
          ),
          if (details.isNotEmpty) NdsPanel(child: KvList(details)),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const AppIcon(HugeIcons.strokeRoundedLogout01, size: 20),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
