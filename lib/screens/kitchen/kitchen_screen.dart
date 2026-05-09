// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/report_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

// ─── Category → Unsplash image URL ────────────────────────────────────────────
class _CategoryImages {
  static const Map<String, String> _images = {
    'dairy':
        'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200&h=200&fit=crop',
    'fruit':
        'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=200&h=200&fit=crop',
    'vegetable':
        'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=200&h=200&fit=crop',
    'bakery':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200&h=200&fit=crop',
    'meat':
        'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=200&h=200&fit=crop',
    'vegan':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200&h=200&fit=crop',
    'drinks':
        'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=200&h=200&fit=crop',
    'coffee':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=200&h=200&fit=crop',
    'dessert':
        'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=200&h=200&fit=crop',
    'pizza':
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&h=200&fit=crop',
    'burger':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop',
    'salad':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200&h=200&fit=crop',
    'sandwich':
        'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=200&h=200&fit=crop',
    'soup':
        'https://images.unsplash.com/photo-1547592180-85f173990554?w=200&h=200&fit=crop',
    'pasta':
        'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=200&h=200&fit=crop',
    'rice':
        'https://images.unsplash.com/photo-1536304993881-ff86e6a7cf78?w=200&h=200&fit=crop',
    'seafood':
        'https://images.unsplash.com/photo-1559737558-2f5a35f4523b?w=200&h=200&fit=crop',
    'chicken':
        'https://images.unsplash.com/photo-1598103442097-8b74394b95c1?w=200&h=200&fit=crop',
    'breakfast':
        'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=200&h=200&fit=crop',
    'snack':
        'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?w=200&h=200&fit=crop',
  };

  static const String _fallback =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=200&h=200&fit=crop';

  static String forItem(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl']?.toString() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;
    final category = item['category']?.toString() ?? '';
    if (category.isNotEmpty) {
      final key = category.toLowerCase().trim();
      if (_images.containsKey(key)) return _images[key]!;
      for (final e in _images.entries) {
        if (key.contains(e.key) || e.key.contains(key)) return e.value;
      }
    }
    final name = item['name']?.toString().toLowerCase() ?? '';
    for (final e in _images.entries) {
      if (name.contains(e.key)) return e.value;
    }
    return _fallback;
  }
}

// ─── Tiny item thumbnail ───────────────────────────────────────────────────────
class _ItemThumb extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        _CategoryImages.forItem(item),
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : Container(width: 32, height: 32, color: const Color(0xFFF3F4F6)),
        errorBuilder: (_, __, ___) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: CafeColors.creme,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fastfood_rounded,
              color: CafeColors.flame, size: 14),
        ),
      ),
    );
  }
}

// ─── Kitchen Screen ────────────────────────────────────────────────────────────
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
                      offset: Offset(0, 4)),
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
                          const Text('Kitchen Dashboard',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: 0.3)),
                          Text(userRole.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppDrawerAvatarButton(
                          photoUrl: photoUrl, userName: userName),
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
                  // ── Metric cards ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
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

                  // ── Section header ─────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
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
                      const Text('Active Orders',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: CafeColors.charcoal)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: CafeColors.creme,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Live',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: CafeColors.flame)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Orders ─────────────────────────────────────────
                  Expanded(
                    child: StreamBuilder<OrderRecordSnapshot>(
                      stream: _ordersStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: CafeColors.flame));
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
                        for (final doc in docs) _visibleOrderIds.add(doc.id);

                        if (docs.isEmpty) return _emptyView();

                        return LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth > 900
                              ? 3
                              : constraints.maxWidth > 580
                                  ? 2
                                  : 1;

                          Widget buildCard(int index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final items = List<Map<String, dynamic>>.from(
                                data['items'] ?? []);
                            final status =
                                data['status']?.toString() ?? 'pending';
                            final orderNumber =
                                (data['orderNumber'] as num?)?.toInt() ?? 0;
                            final tableNumber = data['tableNumber']?.toString();
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

                          // Mobile & single column: plain list
                          if (columns == 1) {
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 2, 0, 100),
                              itemCount: docs.length,
                              itemBuilder: (_, i) => buildCard(i),
                            );
                          }

                          // Desktop/tablet: masonry-friendly — use ListView of Rows
                          // so each card shrinks to its content with no fixed aspect ratio
                          return _MasonryGrid(
                            columns: columns,
                            count: docs.length,
                            builder: buildCard,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Clear History FAB — admin only
          floatingActionButton: auth.isAdmin
              ? Container(
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
                          offset: const Offset(0, 4)),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_sweep_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Clear History',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : null,
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
                color: CafeColors.creme, shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 48, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          const Text('All caught up!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CafeColors.charcoal)),
          const SizedBox(height: 4),
          Text('No active orders right now',
              style: TextStyle(
                  fontSize: 13, color: CafeColors.charcoal.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ─── Masonry-style grid: cards shrink to their own content height ─────────────
class _MasonryGrid extends StatelessWidget {
  final int columns;
  final int count;
  final Widget Function(int index) builder;

  const _MasonryGrid({
    required this.columns,
    required this.count,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // Distribute indices into columns top-to-bottom, left-to-right
    final cols = List.generate(columns, (_) => <int>[]);
    for (var i = 0; i < count; i++) {
      cols[i % columns].add(i);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cols.map((indices) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: cols.indexOf(indices) == 0 ? 0 : 4,
                right: cols.indexOf(indices) == columns - 1 ? 0 : 4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: indices.map((i) => builder(i)).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 1),
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: CafeColors.charcoal.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ─── Kitchen Order Card ───────────────────────────────────────────────────────
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isPending ? CafeColors.flame : CafeColors.olive;
    final statusBg =
        isPending ? const Color(0xFFFFEDE8) : CafeColors.oliveLight;

    return Container(
      // margin only bottom — card height = content height, nothing extra
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      // intrinsic height — wraps content exactly
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.04),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: isPending
                          ? CafeColors.headerGradient
                          : const LinearGradient(
                              colors: [Color(0xFF2D6A4F), Color(0xFF40916C)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#$orderNumber',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      orderType.toUpperCase() +
                          (tableNumber != null ? ' · T$tableNumber' : ''),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal.withOpacity(0.55),
                          letterSpacing: 0.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11,
                          color: CafeColors.charcoal.withOpacity(0.35)),
                      const SizedBox(width: 2),
                      Text(_formatTime(createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color: CafeColors.charcoal.withOpacity(0.35))),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      isPending ? 'PENDING' : 'READY',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
            ),

            // ── Items ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  final name = item['name']?.toString() ?? 'Item';
                  final qty = (item['qty'] as num?)?.toInt() ??
                      (item['quantity'] as num?)?.toInt() ??
                      1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        _ItemThumb(item: item),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CafeColors.charcoal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPending
                                ? CafeColors.creme
                                : CafeColors.oliveLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('×$qty',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: isPending
                  ? SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF2D6A4F), Color(0xFF40916C)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: CafeColors.olive.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: onMarkReady,
                          icon: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                          label: const Text('Mark Ready',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: CafeColors.olive, size: 13),
                        const SizedBox(width: 4),
                        Text('Ready for pickup',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CafeColors.olive.withOpacity(0.8))),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
