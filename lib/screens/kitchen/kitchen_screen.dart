// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../../core/theme/app_theme.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/report_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with TickerProviderStateMixin {
  late final OrderService _service;
  late final ReportService _reportService;

  final Set<String> _hiddenOrderIds = <String>{};
  final List<String> _visibleOrderIds = [];

  Stream<OrderRecordSnapshot>? _ordersStream;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.ownerId.isNotEmpty) {
      _service = OrderService(auth.ownerId);
      _reportService = ReportService(auth.ownerId);
      _ordersStream = _service.getOrders();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

        if (!auth.isAdmin && !auth.isKitchen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)),
          );
        }

        final userRole = auth.role;
        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/kitchen'),
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
                  title: Row(
                    children: [
                      const Icon(Icons.kitchen_rounded,
                          color: Colors.white70, size: 22),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Kitchen Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            userRole.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
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
            currentRoute: '/kitchen',
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: StreamBuilder<Map<String, int>>(
                      stream: _reportService.getOrderStatusStats(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ??
                            {'pending': 0, 'ready': 0, 'completed': 0};
                        return Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Pending',
                                value: '${stats['pending']}',
                                icon: Icons.hourglass_top_rounded,
                                color: const Color(0xFFFF4D1C),
                                bgColor: const Color(0xFFFFEDE8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                title: 'Ready',
                                value: '${stats['ready']}',
                                icon: Icons.check_circle_outline_rounded,
                                color: CafeColors.olive,
                                bgColor: CafeColors.oliveLight,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                title: 'Done',
                                value: '${stats['completed']}',
                                icon: Icons.task_alt_rounded,
                                color: const Color(0xFF6B7280),
                                bgColor: const Color(0xFFF3F4F6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
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
                        const Text(
                          'Active Orders',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: CafeColors.charcoal,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: CafeColors.creme,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: CafeColors.flame,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<OrderRecordSnapshot>(
                      stream: _ordersStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: CafeColors.flame),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        final docs = snapshot.hasData
                            ? snapshot.data!.docs.where((doc) {
                                final data = doc.data();
                                final status =
                                    data['status']?.toString() ?? 'pending';
                                return !_hiddenOrderIds.contains(doc.id) &&
                                    (status == 'pending' || status == 'ready');
                              }).toList()
                            : <OrderRecordDocument>[];

                        _visibleOrderIds.clear();
                        for (final doc in docs) {
                          _visibleOrderIds.add(doc.id);
                        }

                        if (docs.isEmpty) {
                          return _emptyView();
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = ResponsiveLayout.cardColumns(
                                constraints.maxWidth);

                            Widget buildCard(int index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final items = List<Map<String, dynamic>>.from(
                                  data['items'] ?? []);
                              final status =
                                  data['status']?.toString() ?? 'pending';
                              final orderNumber =
                                  (data['orderNumber'] as num?)?.toInt() ?? 0;
                              final tableNumber =
                                  data['tableNumber']?.toString();
                              final createdAt = data['createdAt'] as DateTime?;
                              final orderType =
                                  data['orderType']?.toString() ?? 'takeaway';

                              return _KitchenOrderCard(
                                docId: doc.id,
                                orderNumber: orderNumber,
                                status: status,
                                orderType: orderType,
                                tableNumber: tableNumber,
                                items: items,
                                createdAt: createdAt,
                                onMarkReady: () =>
                                    _service.updateStatus(doc.id, 'ready'),
                              );
                            }

                            if (columns == 1) {
                              return ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 4, 0, 120),
                                itemCount: docs.length,
                                itemBuilder: (context, index) =>
                                    buildCard(index),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.55,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) => buildCard(index),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D1C), Color(0xFFFF8C42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    for (final id in _visibleOrderIds) {
                      _hiddenOrderIds.add(id);
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Kitchen history cleared'),
                        ],
                      ),
                      backgroundColor: CafeColors.charcoal,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Clear History',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 48, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CafeColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No active orders right now',
            style: TextStyle(
              fontSize: 13,
              color: CafeColors.charcoal.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
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

class _KitchenOrderCard extends StatelessWidget {
  final String docId;
  final int orderNumber;
  final String status;
  final String orderType;
  final String? tableNumber;
  final List<Map<String, dynamic>> items;
  final DateTime? createdAt;
  final VoidCallback onMarkReady;

  const _KitchenOrderCard({
    required this.docId,
    required this.orderNumber,
    required this.status,
    required this.orderType,
    this.tableNumber,
    required this.items,
    required this.createdAt,
    required this.onMarkReady,
  });

  bool get isPending => status == 'pending';

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isPending ? CafeColors.flame : CafeColors.olive;
    final statusBg =
        isPending ? const Color(0xFFFFEDE8) : CafeColors.oliveLight;
    final statusLabel = isPending ? 'PENDING' : 'READY';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isPending
            ? Border.all(color: CafeColors.flame.withOpacity(0.15), width: 1)
            : Border.all(color: CafeColors.olive.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Order number badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: isPending
                        ? CafeColors.headerGradient
                        : const LinearGradient(
                            colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
                          ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$orderNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderType.toUpperCase() +
                            (tableNumber != null
                                ? ' · Table $tableNumber'
                                : ''),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12,
                              color: CafeColors.charcoal.withOpacity(0.4)),
                          const SizedBox(width: 3),
                          Text(
                            _formatTime(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: CafeColors.charcoal.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: items.map((item) {
                final name = item['name']?.toString() ?? 'Item';
                final qty = (item['qty'] as num?)?.toInt() ??
                    (item['quantity'] as num?)?.toInt() ??
                    1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isPending
                              ? CafeColors.creme
                              : CafeColors.oliveLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$qty',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CafeColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPending)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CafeColors.olive.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onMarkReady,
                      icon: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'Mark Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: CafeColors.olive, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Ready for pickup',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CafeColors.olive.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
