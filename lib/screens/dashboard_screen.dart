import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/empty_state.dart';
import 'event_detail_screen.dart';
import '../config/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context.read<EventProvider>().loadUpcoming();
    context.read<AttendanceProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user        = context.watch<AuthProvider>().user;
    final eventProv   = context.watch<EventProvider>();
    final attendProv  = context.watch<AttendanceProvider>();
    final theme       = Theme.of(context);

    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.t('nav.home')),
        actions: [
          IconButton(
            tooltip: lang.t('auth.logout'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(lang.t('auth.logout')),
                  content: Text(lang.t('auth.logout_confirm')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(lang.t('common.cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(lang.t('auth.logout'))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<AuthProvider>().logout();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              12, 8, 12,
              MediaQuery.of(context).padding.bottom + 80),
          children: [
            // user greeting
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0] : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? '',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(user?.teamLabel ?? '',
                        style: theme.textTheme.bodySmall),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // attendance rate
            if (!attendProv.loading) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang.t('dash.attendance_rate'),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${(attendProv.rate * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _rateColor(attendProv.rate),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: attendProv.rate,
                          minHeight: 8,
                          color: _rateColor(attendProv.rate),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatBadge(lang.t('status.present'),
                              attendProv.presentCount,
                              context.appColors.presentFg),
                          _StatBadge(lang.t('status.partial'),
                              attendProv.partialCount,
                              context.appColors.partialFg),
                          _StatBadge(lang.t('status.absent'),
                              attendProv.absentCount,
                              context.appColors.absentFg),
                          _StatBadge(lang.t('dash.total'), attendProv.total,
                              theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 今日の活動 (1タップ出欠登録)
            Builder(builder: (_) {
              final todayEvents = eventProv.upcoming.where((e) => e.isToday).toList();
              if (todayEvents.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Row(children: [
                        Icon(Icons.bolt, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(lang.t('dash.today_events'),
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary)),
                      ]),
                    ),
                    ...todayEvents.map((e) => EventCard(
                          event: e,
                          showQuickActions: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: e)),
                          ).then((_) => _load()),
                        )),
                  ],
                ),
              );
            }),

            // 直近の活動
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Text(lang.t('dash.recent_events'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (eventProv.loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (eventProv.upcoming.isEmpty)
              EmptyState(
                icon: Icons.event_busy_outlined,
                title: lang.t('dash.no_events'),
              )
            else
              ...eventProv.upcoming.where((e) => !e.isToday).map((e) => EventCard(
                    event: e,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: e)),
                    ).then((_) => _load()),
                  )),
          ],
        ),
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$count',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
    ]);
  }
}
