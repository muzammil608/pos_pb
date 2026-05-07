// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pocketbase/report_service.dart';
import '../../../widgets/status_donut_chart.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation.dart';

// ─── Vibrant Café Color Palette ───────────────────────────────────────────────
class CafeColors {
  static const Color flame = Color(0xFFFF4D1C);
  static const Color amber = Color(0xFFFFA724);
  static const Color espresso = Color(0xFF1E0F00);
  static const Color latte = Color(0xFFFFF3E8);
  static const Color steam = Color(0xFFFFFAF5);
  static const Color creme = Color(0xFFFFE4C4);
  static const Color olive = Color(0xFF2D6A4F);
  static const Color oliveLight = Color(0xFFD8F3DC);
  static const Color charcoal = Color(0xFF2C2C2C);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFFF4D1C), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bottomBarGradient = LinearGradient(
    colors: [Color(0xFFFF4D1C), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ReportService _reportService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _reportService = ReportService(auth.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: CafeColors.flame)),
          );
        }

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: CafeColors.flame)),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;

        return Scaffold(
          backgroundColor: CafeColors.latte,
          drawer: AppNavigationDrawer(auth: auth, currentRoute: '/admin'),

          // ─── AppBar ──────────────────────────────────────────────────────
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
                      Icon(Icons.admin_panel_settings_rounded,
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

          // ─── Body ────────────────────────────────────────────────────────
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Revenue Card ───────────────────────────────────────────
                StreamBuilder<double>(
                  stream: _reportService.getTodayRevenue(),
                  builder: (context, snapshot) {
                    final revenue = snapshot.data ?? 0.0;
                    final isLoading = !snapshot.hasData;

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: CafeColors.headerGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: CafeColors.flame.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today\'s Revenue',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                isLoading
                                    ? const SizedBox(
                                        height: 36,
                                        width: 36,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Rs ${revenue.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.trending_up_rounded,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Live total',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ─── Order Status Stats ─────────────────────────────────────
                _SectionHeader(
                  icon: Icons.bar_chart_rounded,
                  title: 'Order Status',
                ),
                const SizedBox(height: 12),
                StreamBuilder<Map<String, int>>(
                  stream: _reportService.getOrderStatusStats(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: CafeColors.flame),
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
                        color: CafeColors.flame,
                        bgColor: const Color(0xFFFFEDE8),
                      ),
                      _StatusCardData(
                        key: 'ready',
                        value: stats['ready'] ?? 0,
                        label: 'Ready',
                        icon: Icons.check_circle_outline_rounded,
                        color: CafeColors.olive,
                        bgColor: CafeColors.oliveLight,
                      ),
                      _StatusCardData(
                        key: 'completed',
                        value: stats['completed'] ?? 0,
                        label: 'Done',
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF6B7280),
                        bgColor: const Color(0xFFF3F4F6),
                      ),
                    ];

                    return Row(
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: c.key == 'pending' ? 0 : 5,
                                    right: c.key == 'completed' ? 0 : 5,
                                  ),
                                  child: _StatusCard(data: c),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ─── Donut Chart ────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.donut_large_rounded,
                  title: 'Order Distribution',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CafeColors.flame.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // FIX: Removed the duplicate legend Row that was manually
                  // added here. StatusDonutChart already renders its own
                  // legend internally, so having both caused Pending, Ready
                  // and Completed labels to appear twice under the chart.
                  child: StatusDonutChart(ownerId: auth.ownerId, size: 280),
                ),

                const SizedBox(height: 24),

                // ─── Quick Actions ──────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.flash_on_rounded,
                  title: 'Quick Actions',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.storefront_rounded,
                        label: 'POS',
                        subtitle: 'Order Station',
                        color: CafeColors.flame,
                        bgColor: const Color(0xFFFFEDE8),
                        onTap: () => Navigator.pushNamed(context, '/pos'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.kitchen_rounded,
                        label: 'Kitchen',
                        subtitle: 'Live Orders',
                        color: CafeColors.olive,
                        bgColor: CafeColors.oliveLight,
                        onTap: () => Navigator.pushNamed(context, '/kitchen'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [CafeColors.flame, CafeColors.amber],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: CafeColors.flame),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: CafeColors.charcoal,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Status Card Data Model ────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.value}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: data.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CafeColors.charcoal.withOpacity(0.5),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CafeColors.charcoal,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CafeColors.charcoal.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
