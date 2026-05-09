// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pocketbase/report_service.dart';
import '../../../widgets/status_donut_chart.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/product_seeder.dart'; // ← NEW
import '../../providers/auth_provider.dart';
import '../../services/pocketbase/auth_service.dart'; // ← NEW
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

// ─── Admin Dashboard Screen ────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ReportService _reportService;
  bool _seeded = false; // guard — runs only once per session

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _reportService = ReportService(auth.ownerId);

    // ── ONE-TIME SEED ──────────────────────────────────────────────────────
    // Reads assets/products.json and inserts into PocketBase.
    // Skips automatically if products already exist for this owner.
    // Remove this block once you've seeded successfully.
    if (!_seeded && auth.ownerId.isNotEmpty) {
      _seeded = true;
      final seeder = ProductSeeder(
        authService: AuthService(), // ✅ uses initPb() internally — safe
        ownerId: auth.ownerId,
      );
      seeder.seed().then((count) {
        if (count > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $count products added to your menu!'),
              backgroundColor: NovaColors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
    }
    // ── END SEED ───────────────────────────────────────────────────────────
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            backgroundColor: NovaColors.bgSecondary,
            body: Center(
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            backgroundColor: NovaColors.bgSecondary,
            body: Center(
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;
        final isDesktop = AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: isDesktop
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/admin'),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              decoration: const BoxDecoration(
                gradient: CafeColors.headerGradient,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33FF4D1C),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Row(
                    children: [
                      Icon(Icons.analytics_rounded,
                          color: Colors.white70, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppDrawerAvatarButton(
                        photoUrl: photoUrl,
                        userName: userName,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/admin',
            child: ResponsiveCenter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
                child: _DashboardContent(
                  auth: auth,
                  reportService: _reportService,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED DASHBOARD CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
class _DashboardContent extends StatelessWidget {
  final AuthProvider auth;
  final ReportService reportService;
  final bool isDesktop;

  const _DashboardContent({
    required this.auth,
    required this.reportService,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Revenue Stat Cards Row ────────────────────────────────────
        StreamBuilder<double>(
          stream: reportService.getTodayRevenue(),
          builder: (context, snapshot) {
            final revenue = snapshot.data ?? 0.0;
            final revenueLoading = !snapshot.hasData;

            return StreamBuilder<int>(
              stream: reportService.getTodayOrderCount(),
              builder: (context, ordersSnapshot) {
                final ordersToday = ordersSnapshot.data ?? 0;
                final ordersLoading = !ordersSnapshot.hasData;

                return StreamBuilder<int>(
                  stream: reportService.getKitchenQueueCount(),
                  builder: (context, queueSnapshot) {
                    final queueCount = queueSnapshot.data ?? 0;
                    final queueLoading = !queueSnapshot.hasData;

                    final cards = [
                      _StatCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: NovaColors.violet,
                        label: "Today's Revenue",
                        value: revenueLoading
                            ? '—'
                            : 'Rs ${revenue.toStringAsFixed(0)}',
                        delta: 'Live total',
                        deltaUp: true,
                        isLoading: revenueLoading,
                        fullWidth: !isDesktop,
                      ),
                      _StatCard(
                        icon: Icons.receipt_long_rounded,
                        iconColor: NovaColors.teal,
                        label: 'Orders Today',
                        value: ordersLoading ? '—' : '$ordersToday',
                        delta: 'Updated live',
                        deltaUp: true,
                        isLoading: ordersLoading,
                        fullWidth: !isDesktop,
                      ),
                      _StatCard(
                        icon: Icons.kitchen_rounded,
                        iconColor: NovaColors.amber,
                        label: 'Kitchen Queue',
                        value: queueLoading ? '—' : '$queueCount',
                        delta: 'Active items',
                        deltaUp: null,
                        isLoading: queueLoading,
                        fullWidth: !isDesktop,
                      ),
                      _StatCard(
                        icon: Icons.star_rounded,
                        iconColor: NovaColors.rose,
                        label: 'Satisfaction',
                        value: '94.6%',
                        delta: '↑ 1.8% vs last month',
                        deltaUp: true,
                        fullWidth: !isDesktop,
                      ),
                    ];

                    if (isDesktop) {
                      return Row(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    }

                    return Column(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          cards[i],
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),

        SizedBox(height: isDesktop ? 16 : 16),

        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Order Status',
                    ),
                    const SizedBox(height: 12),
                    _OrderStatusCards(reportService: reportService),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      icon: Icons.flash_on_rounded,
                      title: 'Quick Actions',
                    ),
                    const SizedBox(height: 12),
                    _QuickActionsRow(isDesktop: true),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Order Breakdown',
                    ),
                    const SizedBox(height: 12),
                    _OrderBreakdownCard(auth: auth, isDesktop: true),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Order Status',
          ),
          const SizedBox(height: 12),
          _OrderStatusCards(reportService: reportService),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Order Breakdown',
          ),
          const SizedBox(height: 12),
          _OrderBreakdownCard(auth: auth, isDesktop: false),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.flash_on_rounded,
            title: 'Quick Actions',
          ),
          const SizedBox(height: 12),
          _QuickActionsRow(isDesktop: false),
        ],
      ],
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;
  final bool? deltaUp;
  final bool isLoading;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
    this.deltaUp,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Color deltaColor = NovaColors.textTertiary;
    if (deltaUp == true) deltaColor = NovaColors.teal;
    if (deltaUp == false) deltaColor = NovaColors.danger;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: NovaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: NovaColors.violet,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: NovaColors.textPrimary,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: TextStyle(fontSize: 12, color: deltaColor),
          ),
        ],
      ),
    );
  }
}

// ─── Order Status Cards ────────────────────────────────────────────────────────
class _OrderStatusCards extends StatelessWidget {
  final ReportService reportService;

  const _OrderStatusCards({required this.reportService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: reportService.getOrderStatusStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }
        final stats = snapshot.data!;
        final cards = [
          _StatusCardData(
            key: 'pending',
            value: stats['pending'] ?? 0,
            label: 'Pending',
            icon: Icons.hourglass_top_rounded,
            color: NovaColors.danger,
            bgColor: NovaColors.dangerLight,
          ),
          _StatusCardData(
            key: 'ready',
            value: stats['ready'] ?? 0,
            label: 'Ready',
            icon: Icons.check_circle_outline_rounded,
            color: NovaColors.teal,
            bgColor: NovaColors.tealLight,
          ),
          _StatusCardData(
            key: 'completed',
            value: stats['completed'] ?? 0,
            label: 'Done',
            icon: Icons.task_alt_rounded,
            color: NovaColors.textSecondary,
            bgColor: NovaColors.bgSecondary,
          ),
        ];
        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: c.key == 'pending' ? 0 : 6,
                      right: c.key == 'completed' ? 0 : 6,
                    ),
                    child: _StatusCard(data: c),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ─── Order Breakdown Card ──────────────────────────────────────────────────────
class _OrderBreakdownCard extends StatelessWidget {
  final AuthProvider auth;
  final bool isDesktop;

  const _OrderBreakdownCard({required this.auth, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return StatusDonutChart(
      ownerId: auth.ownerId,
      cardHeight: isDesktop ? 224 : null,
      chartSize: isDesktop ? 116 : 160,
      showSegmentBar: !isDesktop,
    );
  }
}

// ─── Quick Actions Row ─────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final bool isDesktop;

  const _QuickActionsRow({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.storefront_rounded,
            label: 'POS',
            subtitle: 'Order Station',
            color: NovaColors.violet,
            bgColor: NovaColors.violetLight,
            onTap: () => Navigator.pushNamed(context, '/pos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.kitchen_rounded,
            label: 'Kitchen',
            subtitle: 'Live Orders',
            color: NovaColors.teal,
            bgColor: NovaColors.tealLight,
            onTap: () => Navigator.pushNamed(context, '/kitchen'),
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: NovaColors.violet),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: NovaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Status Card Data ──────────────────────────────────────────────────────────
class _StatusCardData {
  final String key;
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatusCardData({
    required this.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

// ─── Status Card ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final _StatusCardData data;

  const _StatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.value}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: data.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: NovaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Card ─────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NovaColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
