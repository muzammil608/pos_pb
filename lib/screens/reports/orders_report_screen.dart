// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pocketbase/report_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

// ─── Vibrant Café Color Palette ───────────────────────────────────────────────

class OrdersReportScreen extends StatefulWidget {
  const OrdersReportScreen({super.key});

  @override
  State<OrdersReportScreen> createState() => _OrdersReportScreenState();
}

class _OrdersReportScreenState extends State<OrdersReportScreen> {
  late final ReportService _reportService;
  String _ordersPeriod = 'weekly';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _reportService = ReportService(auth.ownerId);
  }

  String _periodTitle(String period) {
    return switch (period) {
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => 'Weekly',
    };
  }

  String _formatOrderDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year}  $hour:$minute';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => CafeColors.olive,
      'ready' => CafeColors.amber,
      'pending' => CafeColors.flame,
      _ => const Color(0xFF9CA3AF),
    };
  }

  Color _statusBg(String status) {
    return switch (status) {
      'completed' => CafeColors.oliveLight,
      'ready' => const Color(0xFFFFF3CC),
      'pending' => const Color(0xFFFFEDE8),
      _ => const Color(0xFFF3F4F6),
    };
  }

  // ─── Period Selector Widget ───────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CafeColors.flame.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: ['weekly', 'monthly', 'yearly'].map((period) {
          final isSelected = _ordersPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ordersPeriod = period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? CafeColors.headerGradient : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CafeColors.flame.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  _periodTitle(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : CafeColors.charcoal.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)),
          );
        }

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/orders'),

          // ─── AppBar ────────────────────────────────────────────────────
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
                      Icon(Icons.receipt_long_rounded,
                          color: Colors.white70, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Orders Report',
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

          // ─── Body ──────────────────────────────────────────────────────
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/orders',
            child: ResponsiveCenter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Orders Stream ────────────────────────────────────────
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _reportService.getOrdersByPeriod(_ordersPeriod),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: CircularProgressIndicator(
                                  color: CafeColors.flame),
                            ),
                          );
                        }

                        final orders = snapshot.data!;
                        final grandTotal = orders.fold<double>(
                          0.0,
                          (sum, order) =>
                              sum +
                              ((order['total'] as num?)?.toDouble() ?? 0.0),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Summary Card ───────────────────────────────
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: CafeColors.headerGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: CafeColors.flame.withOpacity(0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(22),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_periodTitle(_ordersPeriod)} Total',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs ${grandTotal.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${orders.length} order${orders.length == 1 ? '' : 's'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.summarize_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ─── Period Selector (below summary card) ────────
                            _buildPeriodSelector(),

                            const SizedBox(height: 20),

                            // ─── Section Label ──────────────────────────────
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        CafeColors.flame,
                                        CafeColors.amber
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.list_alt_rounded,
                                    size: 17, color: CafeColors.flame),
                                const SizedBox(width: 6),
                                const Text(
                                  'Order List',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: CafeColors.charcoal,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ─── Orders List ────────────────────────────────
                            if (orders.isEmpty)
                              _emptyView(_ordersPeriod)
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = ResponsiveLayout.cardColumns(
                                    constraints.maxWidth,
                                  );

                                  Widget buildOrderCard(int index) {
                                    final order = orders[index];
                                    final orderNumber = order['orderNumber']
                                            ?.toString() ??
                                        order['id'].toString().substring(0, 6);
                                    final total =
                                        (order['total'] as num?)?.toDouble() ??
                                            0.0;
                                    final status =
                                        order['status']?.toString() ??
                                            'unknown';
                                    final orderType =
                                        order['orderType']?.toString() ??
                                            'takeaway';
                                    final createdAt =
                                        order['createdAtDate'] as DateTime;

                                    return _OrderCard(
                                      orderNumber: orderNumber,
                                      total: total,
                                      status: status,
                                      orderType: orderType,
                                      createdAt: createdAt,
                                      formattedDate:
                                          _formatOrderDate(createdAt),
                                      statusColor: _statusColor(status),
                                      statusBg: _statusBg(status),
                                    );
                                  }

                                  if (columns == 1) {
                                    return Column(
                                      children: List.generate(
                                        orders.length,
                                        buildOrderCard,
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 3.8,
                                    ),
                                    itemCount: orders.length,
                                    itemBuilder: (context, index) =>
                                        buildOrderCard(index),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyView(String period) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: CafeColors.creme,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 40, color: CafeColors.flame),
            ),
            const SizedBox(height: 14),
            Text(
              'No ${period.toLowerCase()} orders',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CafeColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Orders will appear here once placed',
              style: TextStyle(
                fontSize: 13,
                color: CafeColors.charcoal.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order Card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final String orderNumber;
  final double total;
  final String status;
  final String orderType;
  final DateTime createdAt;
  final String formattedDate;
  final Color statusColor;
  final Color statusBg;

  const _OrderCard({
    required this.orderNumber,
    required this.total,
    required this.status,
    required this.orderType,
    required this.createdAt,
    required this.formattedDate,
    required this.statusColor,
    required this.statusBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CafeColors.flame.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // ─── Icon Badge ───────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CafeColors.creme,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: CafeColors.flame, size: 22),
            ),
            const SizedBox(width: 12),

            // ─── Info ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #$orderNumber',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Rs ${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CafeColors.flame,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11,
                          color: CafeColors.charcoal.withOpacity(0.4)),
                      const SizedBox(width: 3),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: CafeColors.charcoal.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      // Order type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CafeColors.creme,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          orderType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: CafeColors.flame,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
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
