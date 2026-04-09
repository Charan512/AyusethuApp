import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/batches_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/crop_timeline_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/analytics_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadDashboard();
      ref.read(notificationProvider.notifier).loadNotifications();
      ref.read(batchesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final notifications = ref.watch(notificationProvider);
    final auth = ref.watch(authProvider);
    final batchesState = ref.watch(batchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AyuSethu'),
            Text(
              'Welcome, ${auth.user?.name ?? 'Farmer'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                onPressed: () => _showNotifications(context, notifications),
                icon: const Icon(Icons.notifications_outlined, size: 28),
                tooltip: 'Notifications',
              ),
              if (notifications.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${notifications.unreadCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Profile
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (auth.user?.name ?? 'F')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: dashboard.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : dashboard.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dashboard.errorMessage!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(dashboardProvider.notifier).loadDashboard(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(dashboardProvider.notifier).loadDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Stats Grid ──────────────
                    _buildQuickStats(context, dashboard),
                    const SizedBox(height: 28),

                    // ── My Crops / Timeline ───────────
                    _buildSectionTitle(
                      context,
                      'My Crops',
                      Icons.timeline_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildBatchCards(context, batchesState),
                    const SizedBox(height: 28),
                    // ── Weather News ────────
                    _buildSectionTitle(
                      context,
                      'Local Weather',
                      Icons.cloud_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildWeatherWidget(context, dashboard),
                    const SizedBox(height: 28),

                    // ── Crop Distribution ─────────────
                    _buildSectionTitle(
                      context,
                      'Batch Status',
                      Icons.pie_chart_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildPieChart(context, dashboard),
                    const SizedBox(height: 100), // space for FAB
                  ],
                ),
              ),
            ),

      // ── Chat FAB ──────────────────────────────────
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: AppColors.accentGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/chat'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.chat_rounded, size: 24),
          label: const Text(
            'Chat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchCards(BuildContext context, BatchesState state) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (state.batches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.grass_rounded, size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              'No crop batches yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textLight),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete onboarding via the Chat to start tracking',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: state.batches.map((batch) {
        final stages = (batch['stages'] as List?) ?? [];
        final completed = stages.where((s) => s['completedAt'] != null).length;
        final progress = completed / 5.0;
        final species = batch['speciesName'] ?? 'Crop';
        final batchId = batch['batchId'] ?? '—';
        final status = batch['status'] ?? 'INITIATED';

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CropTimelineScreen(batch: Map<String, dynamic>.from(batch)),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            species,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            batchId,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.replaceAll('_', ' '),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completed / 5 stages',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Timeline',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: AppColors.primary, size: 14),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickStats(BuildContext context, DashboardState dashboard) {
    final summary = dashboard.summary;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        AnalyticsCard(
          title: 'Total Batches',
          value: '${summary['totalBatches'] ?? 0}',
          icon: Icons.inventory_2_rounded,
          gradientColors: const [Color(0xFF1B5E20), Color(0xFF43A047)],
        ),
        AnalyticsCard(
          title: 'Active Batches',
          value: '${summary['activeBatches'] ?? 0}',
          icon: Icons.eco_rounded,
          gradientColors: const [Color(0xFF00695C), Color(0xFF26A69A)],
        ),
        AnalyticsCard(
          title: 'Stages Done',
          value: '${summary['completedStages'] ?? 0}',
          icon: Icons.check_circle_rounded,
          gradientColors: const [Color(0xFFE65100), Color(0xFFFF8F00)],
        ),
        AnalyticsCard(
          title: 'Harvested',
          value: '${summary['harvestedBatches'] ?? 0}',
          icon: Icons.agriculture_rounded,
          gradientColors: const [Color(0xFF4E342E), Color(0xFF8D6E63)],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  Widget _buildWeatherWidget(BuildContext context, DashboardState dashboard) {
    final weather = dashboard.weatherNews;
    if (weather == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Weather data unavailable')),
      );
    }

    final temp = (weather['temp'] as num).round();
    final desc = (weather['description'] as String).toUpperCase();
    final location = weather['location'] as String;
    final humidity = weather['humidity'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$temp°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$desc  •  $humidity% Humidity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons
                .wb_sunny_rounded, // or load 'https://openweathermap.org/img/wn/\${weather['icon']}@2x.png'
            size: 64,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, DashboardState dashboard) {
    final statusDist = dashboard.statusDistribution;
    if (statusDist.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('No batch data yet')),
      );
    }

    final colors = [
      const Color(0xFF1B5E20),
      const Color(0xFF43A047),
      const Color(0xFF81C784),
      const Color(0xFFFF8F00),
      const Color(0xFFFFCA28),
      const Color(0xFF00695C),
      const Color(0xFF8D6E63),
      const Color(0xFFE53935),
    ];

    final entries = statusDist.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: List.generate(entries.length, (i) {
                  final value = (entries[i].value as num).toDouble();
                  return PieChartSectionData(
                    value: value,
                    color: colors[i % colors.length],
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    title: value.toInt().toString(),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entries[i].key,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, NotificationState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: state.notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 56,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.textLight),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: state.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = state.notifications[i];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? AppColors.background
                                    : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: n.isRead
                                          ? Colors.transparent
                                          : AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      n.message,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
