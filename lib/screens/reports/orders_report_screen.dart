import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pocketbase/report_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class OrdersReportScreen extends StatefulWidget {
  const OrdersReportScreen({super.key});

  @override
  State<OrdersReportScreen> createState() => _OrdersReportScreenState();
}

class _OrdersReportScreenState extends State<OrdersReportScreen> {
  late final ReportService _reportService;
  String _ordersPeriod = 'weekly';
  static const double _summaryCardTopSpacing = 10;
  static const double _summaryCardMaxExtent = 174;
  static const double _summaryCardMinExtent = 102;
  static const double _periodHeaderExtent = 112;

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

        final columns = ResponsiveLayout.cardColumns(
          MediaQuery.of(context).size.width,
        );

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/orders'),
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
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/orders',
            child: ResponsiveCenter(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _reportService.getOrdersByPeriod(_ordersPeriod),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: CafeColors.flame),
                    );
                  }

                  final orders = snapshot.data!;
                  final grandTotal = orders.fold<double>(
                    0.0,
                    (sum, order) =>
                        sum + ((order['total'] as num?)?.toDouble() ?? 0.0),
                  );

                  return CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _OrdersSummaryHeaderDelegate(
                          minExtentHeight: _summaryCardMinExtent,
                          maxExtentHeight: _summaryCardMaxExtent,
                          periodTitle: _periodTitle(_ordersPeriod),
                          grandTotal: grandTotal,
                          orderCount: orders.length,
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _OrdersPeriodHeaderDelegate(
                          extentHeight: _periodHeaderExtent,
                          child: _buildPeriodSelector(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      if (orders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyView(_ordersPeriod),
                        )
                      else if (columns == 1)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildOrderCard(orders[index], inGrid: false),
                            childCount: orders.length,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 32),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 120,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildOrderCard(orders[index], inGrid: true),
                              childCount: orders.length,
                            ),
                          ),
                        ),
                      if (columns == 1 && orders.isNotEmpty)
                        const SliverToBoxAdapter(child: SizedBox(height: 22)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool inGrid = false}) {
    final orderNumber = order['orderNumber']?.toString() ??
        order['id'].toString().substring(0, 6);
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final status = order['status']?.toString() ?? 'unknown';
    final orderType = order['orderType']?.toString() ?? 'takeaway';
    final createdAt = order['createdAtDate'] as DateTime;

    return _OrderCard(
      orderNumber: orderNumber,
      total: total,
      status: status,
      orderType: orderType,
      createdAt: createdAt,
      formattedDate: _formatOrderDate(createdAt),
      statusColor: _statusColor(status),
      statusBg: _statusBg(status),
      // In a GridView the grid itself handles spacing via mainAxisSpacing,
      // so we remove the card's own bottom margin to avoid double-spacing.
      inGrid: inGrid,
    );
  }

  Widget _emptyView(String period) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class _OrdersSummaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentHeight;
  final double maxExtentHeight;
  final String periodTitle;
  final double grandTotal;
  final int orderCount;

  const _OrdersSummaryHeaderDelegate({
    required this.minExtentHeight,
    required this.maxExtentHeight,
    required this.periodTitle,
    required this.grandTotal,
    required this.orderCount,
  });

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapseRange = maxExtent - minExtent;
    final t =
        collapseRange <= 0 ? 1.0 : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final horizontalPadding = lerpDouble(22, 18, t)!;
    final verticalPadding = lerpDouble(22, 14, t)!;
    final titleSize = lerpDouble(13, 12, t)!;
    final totalSize = lerpDouble(32, 22, t)!;
    final badgeFontSize = lerpDouble(12, 11, t)!;
    final badgeVerticalPadding = lerpDouble(4, 3, t)!;
    final iconBoxPadding = lerpDouble(14, 10, t)!;
    final iconSize = lerpDouble(32, 24, t)!;
    final borderRadius = lerpDouble(20, 16, t)!;
    final spacingAfterTitle = lerpDouble(4, 2, t)!;
    final spacingAfterTotal = lerpDouble(6, 4, t)!;

    return Container(
      color: NovaColors.bgTertiary,
      padding: const EdgeInsets.only(top: _OrdersReportScreenState._summaryCardTopSpacing),
      child: Container(
        decoration: BoxDecoration(
          gradient: CafeColors.headerGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: CafeColors.flame.withOpacity(0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$periodTitle Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: spacingAfterTitle),
                  Text(
                    'Rs ${grandTotal.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: totalSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: spacingAfterTotal),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: badgeVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$orderCount order${orderCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(iconBoxPadding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.summarize_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OrdersSummaryHeaderDelegate oldDelegate) {
    return minExtentHeight != oldDelegate.minExtentHeight ||
        maxExtentHeight != oldDelegate.maxExtentHeight ||
        periodTitle != oldDelegate.periodTitle ||
        grandTotal != oldDelegate.grandTotal ||
        orderCount != oldDelegate.orderCount;
  }
}

class _OrdersPeriodHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extentHeight;
  final Widget child;

  const _OrdersPeriodHeaderDelegate({
    required this.extentHeight,
    required this.child,
  });

  @override
  double get minExtent => extentHeight;

  @override
  double get maxExtent => extentHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: NovaColors.bgTertiary,
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 14),
          const _OrderListHeader(),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OrdersPeriodHeaderDelegate oldDelegate) {
    return extentHeight != oldDelegate.extentHeight || child != oldDelegate.child;
  }
}

class _OrderListHeader extends StatelessWidget {
  const _OrderListHeader();

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
        const Icon(Icons.list_alt_rounded, size: 17, color: CafeColors.flame),
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
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderNumber;
  final double total;
  final String status;
  final String orderType;
  final DateTime createdAt;
  final String formattedDate;
  final Color statusColor;
  final Color statusBg;
  final bool inGrid;

  const _OrderCard({
    required this.orderNumber,
    required this.total,
    required this.status,
    required this.orderType,
    required this.createdAt,
    required this.formattedDate,
    required this.statusColor,
    required this.statusBg,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // In ListView mode keep the original bottom margin for spacing between
      // cards. In GridView mode remove it — mainAxisSpacing handles that.
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #$orderNumber',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CafeColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                      Expanded(
                        child: Text(
                          formattedDate,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: CafeColors.charcoal.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
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
