import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/ui.dart';
import '../auth/auth_state.dart';
import '../home/account_screen.dart';
import '../home/notifications.dart';
import 'field_bus_list_screen.dart';
import 'supervisor_dashboard_screen.dart';
import 'supervisor_providers.dart';

/// Shell for bus supervisors and field supervisors. Field supervisors get
/// an extra tab with the searchable list of all buses.
class SupervisorScreen extends ConsumerStatefulWidget {
  const SupervisorScreen({super.key});

  @override
  ConsumerState<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends ConsumerState<SupervisorScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final field = ref.watch(authProvider).user?.role == 'FIELD_SUPERVISOR';
    final buses = ref.watch(supervisorBusesProvider).value;
    final account = AccountScreen(
      roleLabel: field
          ? 'مشرفة ميدانية · جامعة الملك خالد'
          : 'مشرفة حافلات · جامعة الملك خالد',
      details: [
        if (buses != null)
          KvEntry(
            field ? 'الحافلات المتابَعة' : 'الحافلات المسندة',
            '${buses.length}',
          ),
      ],
    );

    final screens = field
        ? [
            SupervisorDashboardScreen(
              field: true,
              onShowBuses: () => setState(() => _index = 1),
            ),
            const FieldBusListScreen(),
            account,
          ]
        : [const SupervisorDashboardScreen(field: false), account];
    final tabs = field
        ? const [
            NdsTabItem(HugeIcons.strokeRoundedDashboardSquare01, 'الرئيسية'),
            NdsTabItem(HugeIcons.strokeRoundedBus01, 'الحافلات'),
            NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'الحساب'),
          ]
        : const [
            NdsTabItem(HugeIcons.strokeRoundedHome01, 'الرئيسية'),
            NdsTabItem(HugeIcons.strokeRoundedUserCircle, 'الحساب'),
          ];
    final index = _index.clamp(0, screens.length - 1);

    final shell = Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NdsTabBar(
        currentIndex: index,
        onTap: (value) => setState(() => _index = value),
        items: tabs,
      ),
    );
    if (field) return shell;
    // Bus supervisors hear when a driver cannot drive.
    return NotificationWatcher(
      onNew: () => ref.invalidate(supervisorBusesProvider),
      child: shell,
    );
  }
}
