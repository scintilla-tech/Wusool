import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../auth/auth_state.dart';
import 'student_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentProfileProvider);
    final trip = ref.watch(studentTripProvider).value;

    return Scaffold(
      appBar: const NdsAppBar(title: 'حسابي'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(studentProfileProvider)),
        data: (profile) {
          final name = '${profile.firstName} ${profile.lastName}';
          final hasHome =
              profile.homeLatitude != null && profile.homeLongitude != null;
          return PageBody(
            onRefresh: () async {
              ref.invalidate(studentTripProvider);
              ref.invalidate(studentProfileProvider);
              await ref.read(studentProfileProvider.future);
            },
            children: [
              ProfileHeader(
                name: name,
                meta: profile.studentId == null
                    ? 'طالبة'
                    : 'طالبة · الرقم الجامعي ${ltr(profile.studentId!)}',
              ),
              TitledPanel(
                title: 'بيانات النقل',
                child: KvList([
                  KvEntry(
                    'حافلة اليوم',
                    trip?.busPlate == null
                        ? 'لا توجد رحلة'
                        : ltr(trip!.busPlate!),
                  ),
                  KvEntry('المسار', trip?.routeName ?? 'غير محدد'),
                  KvEntry(
                    'الموقع المنزلي',
                    hasHome
                        ? ltr(
                            '${profile.homeLatitude!.toStringAsFixed(4)}, ${profile.homeLongitude!.toStringAsFixed(4)}',
                          )
                        : 'غير محدد',
                  ),
                ]),
              ),
              TitledPanel(
                title: 'بيانات التواصل',
                child: KvList([
                  KvEntry('رقم الجوال', ltr(profile.phone)),
                  KvEntry(
                    'البريد الجامعي',
                    profile.email == null ? 'غير مسجل' : ltr(profile.email!),
                  ),
                ]),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const AppIcon(HugeIcons.strokeRoundedLogout01, size: 20),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          );
        },
      ),
    );
  }
}
