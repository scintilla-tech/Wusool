import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/ui.dart';

/// A notification the server kept for the signed-in user.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String? ?? '',
    type: m['type'] as String? ?? '',
    title: m['title'] as String? ?? '',
    body: m['body'] as String?,
    isRead: m['isRead'] as bool? ?? false,
    createdAt: DateTime.tryParse(m['createdAt'] as String? ?? ''),
  );

  (HugeIconData, Tone) get look => switch (type) {
    'TRIPS_READY' => (HugeIcons.strokeRoundedBus01, Tone.primary),
    'TRIP_NEEDED' => (HugeIcons.strokeRoundedCalendarAdd01, Tone.warning),
    'COVER_ASSIGNED' ||
    'COVER_REPLACED' ||
    'COVER_ENDED' ||
    'COVER_CANCELLED' => (HugeIcons.strokeRoundedUserSwitch, Tone.info),
    'DRIVER_ABSENT' ||
    'COVER_NEEDED' => (HugeIcons.strokeRoundedCalendar03, Tone.warning),
    'ABSENCE_CANCELLED' => (HugeIcons.strokeRoundedCalendar03, Tone.success),
    'ROUTE_BY_DRIVER' => (HugeIcons.strokeRoundedRoute01, Tone.primary),
    _ => (HugeIcons.strokeRoundedNotification03, Tone.neutral),
  };
}

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final res = await ref
        .watch(apiClientProvider)
        .dio
        .get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: {'page': 1, 'limit': 50},
        );
    final items = res.data?['data']?['items'] as List? ?? const [];
    return [
      for (final item in items)
        if (item is Map) AppNotification.fromJson(item.cast<String, dynamic>()),
    ];
  },
);

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref
      .watch(apiClientProvider)
      .dio
      .get<Map<String, dynamic>>('/notifications/unread-count');
  return (res.data?['data']?['count'] as num?)?.toInt() ?? 0;
});

/// Bell with the number of unread notifications; opens the list.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return CircleIconButton(
      icon: HugeIcons.strokeRoundedNotification03,
      tooltip: unread == 0 ? 'الإشعارات' : 'الإشعارات، $unread غير مقروءة',
      badgeCount: unread,
      onPressed: () => openNotifications(context),
    );
  }
}

void openNotifications(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));

/// Checks for new notifications while the app is open (every 45 seconds and
/// when it comes back to the foreground) and announces each new one.
/// Phones get push notifications once a push provider is configured.
class NotificationWatcher extends ConsumerStatefulWidget {
  final Widget child;

  /// Called when something new arrives, e.g. to reload today's trips.
  final VoidCallback? onNew;

  const NotificationWatcher({super.key, required this.child, this.onNew});

  @override
  ConsumerState<NotificationWatcher> createState() =>
      _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => ref.invalidate(unreadCountProvider),
    );
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(unreadCountProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _announce() async {
    widget.onNew?.call();
    ref.invalidate(notificationsProvider);
    final latest = (await ref.read(notificationsProvider.future)).firstOrNull;
    if (!mounted || latest == null || latest.isRead) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          latest.body == null
              ? latest.title
              : '${latest.title}\n${latest.body}',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'عرض',
          onPressed: () => openNotifications(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(unreadCountProvider, (previous, next) {
      final before = previous?.value;
      final now = next.value;
      if (before != null && now != null && now > before) _announce();
    });
    return widget.child;
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the list counts as reading it, once it has shown what is new.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(notificationsProvider.future);
        await ref.read(apiClientProvider).dio.post('/notifications/read-all');
        ref.invalidate(unreadCountProvider);
      } catch (_) {
        // Still unread; the bell keeps its count.
      }
    });
  }

  String _when(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final date = switch (today.difference(day).inDays) {
      0 => 'اليوم',
      1 => 'أمس',
      _ =>
        '${local.year}/${local.month.toString().padLeft(2, '0')}/'
            '${local.day.toString().padLeft(2, '0')}',
    };
    return '$date ${clockLabel(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: const NdsAppBar(title: 'الإشعارات'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(notificationsProvider)),
        data: (items) => PageBody(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          children: [
            if (items.isEmpty)
              const MessageView(
                icon: HugeIcons.strokeRoundedNotification03,
                title: 'لا إشعارات',
                message: 'تصلك هنا إشعارات رحلاتك.',
              )
            else
              NdsGroup(
                children: [
                  for (final item in items)
                    NdsListItem(
                      leading: FeaturedIcon(item.look.$1, tone: item.look.$2),
                      title: item.title,
                      titleBadge: item.isRead
                          ? null
                          : const NdsTag('جديد', status: TagStatus.info),
                      meta: item.body,
                      meta2: _when(item.createdAt),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
