// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/responsive_layout.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  ProductService? _productService;
  OrderService? _orderService;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pulseController;

  String _searchQuery = '';
  String _selectedCategory = 'All';

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
      _productService = ProductService(auth.ownerId);
      _orderService = OrderService(auth.ownerId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<int?> _showQtyDialog(
      BuildContext context, String productName, double price) async {
    int qty = 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: NovaColors.bgPrimary,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: NovaColors.violetLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded,
                        color: NovaColors.violet, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rs ${price.toStringAsFixed(0)} / item',
                style: const TextStyle(
                  fontSize: 13,
                  color: NovaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (value) => qty = int.tryParse(value) ?? 1,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NovaColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: '1',
                  labelStyle: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.format_list_numbered,
                      color: NovaColors.violet, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: NovaColors.borderTertiary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: NovaColors.borderTertiary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: NovaColors.violet, width: 1.5),
                  ),
                  filled: true,
                  fillColor: NovaColors.bgSecondary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side:
                            const BorderSide(color: NovaColors.borderSecondary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: NovaColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, qty),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NovaColors.violet,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Add to Cart',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _readyOrderCount(AsyncSnapshot snapshot) {
    if (!snapshot.hasData) return 0;
    return snapshot.data!.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'ready';
    }).length;
  }

  void _showReadyOrdersSheet(BuildContext context) {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Container(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              decoration: const BoxDecoration(
                color: NovaColors.bgSecondary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 2),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: NovaColors.borderSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: NovaColors.bgPrimary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: NovaColors.borderTertiary, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: NovaColors.tealLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: NovaColors.teal,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ready to Collect',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: NovaColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Tap Print & Complete to close order',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: NovaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder(
                            stream: _orderService?.getOrders(),
                            builder: (context, snapshot) {
                              final count = _readyOrderCount(snapshot);
                              if (count == 0) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NovaColors.tealLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: NovaColors.teal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder(
                        stream: _orderService?.getOrders(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: NovaColors.violet),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return _emptyOrdersView();
                          }

                          final readyOrders = snapshot.data!.docs.where((doc) {
                            final data = doc.data();
                            return data['status'] == 'ready';
                          }).toList();

                          readyOrders.sort((a, b) {
                            final aMs =
                                ((a.data() as Map)['createdAt'] as DateTime?)
                                        ?.millisecondsSinceEpoch ??
                                    0;
                            final bMs =
                                ((b.data() as Map)['createdAt'] as DateTime?)
                                        ?.millisecondsSinceEpoch ??
                                    0;
                            return bMs.compareTo(aMs);
                          });

                          if (readyOrders.isEmpty) return _emptyOrdersView();

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: readyOrders.length,
                            itemBuilder: (context, index) {
                              final order = readyOrders[index];
                              final data = order.data();
                              final orderId = order.id;
                              final orderType =
                                  data['orderType']?.toString() ?? 'takeaway';
                              final customerName =
                                  data['customerName']?.toString().trim();
                              final orderLabel =
                                  '#${data['orderNumber'] ?? orderId.substring(0, 6)}';
                              final items = List<Map<String, dynamic>>.from(
                                (data['items'] as List? ?? []).map(
                                  (item) =>
                                      Map<String, dynamic>.from(item as Map),
                                ),
                              );

                              return _ReadyOrderCard(
                                orderLabel: orderLabel,
                                orderType: orderType,
                                customerName: customerName,
                                items: items,
                                total: (data['total'] as num?)?.toDouble() ?? 0,
                                index: index,
                                onComplete: () async {
                                  Navigator.pop(sheetContext);
                                  await _orderService?.updateStatus(
                                      orderId, 'completed');
                                  if (!rootContext.mounted) return;

                                  final orderNumber =
                                      (data['orderNumber'] as num?)?.toInt() ??
                                          0;
                                  final total =
                                      (data['total'] as num?)?.toDouble() ??
                                          0.0;
                                  final tendered =
                                      (data['tenderedAmount'] as num?)
                                              ?.toDouble() ??
                                          total;
                                  final change =
                                      (data['change'] as num?)?.toDouble() ??
                                          0.0;
                                  final createdAt =
                                      data['createdAt'] as DateTime?;
                                  final date = createdAt != null
                                      ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                                      : '';
                                  final servedBy = Provider.of<AuthProvider>(
                                          rootContext,
                                          listen: false)
                                      .role;

                                  await showDialog(
                                    context: rootContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => ReceiptDialog(
                                      companyName: 'Orion POS',
                                      phone: '+92-317-7921817',
                                      email: 'info@orion.com',
                                      website: 'www.orion.com',
                                      servedBy: servedBy,
                                      customerName:
                                          customerName ?? 'Walk-in Customer',
                                      orderType: orderType,
                                      items: items,
                                      total: total,
                                      cash: tendered,
                                      change: change,
                                      tax: 0.0,
                                      paymentMethod:
                                          data['paymentMethod'] ?? 'cash',
                                      orderNo: 'ORDER-$orderNumber',
                                      date: date,
                                    ),
                                  );
                                },
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
          ),
        );
      },
    );
  }

  Widget _emptyOrdersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NovaColors.bgSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: NovaColors.borderTertiary),
            ),
            child: const Icon(Icons.coffee_outlined,
                size: 40, color: NovaColors.textTertiary),
          ),
          const SizedBox(height: 14),
          const Text('No ready orders yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: NovaColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('New orders will appear here',
              style: TextStyle(fontSize: 13, color: NovaColors.textTertiary)),
        ],
      ),
    );
  }

  int _crossAxisCount(double width) {
    if (width < 380) return 1;
    return ResponsiveLayout.productColumns(width);
  }

  List<String> _getCategories(List<Product> products) {
    final cats = products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, auth, cart, child) {
        if (auth.user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          });
          return const Scaffold(
              backgroundColor: NovaColors.bgTertiary,
              body: Center(
                  child: CircularProgressIndicator(color: NovaColors.violet)));
        }

        final user = auth.user!;
        final userEmail = user.email;
        final userName = user.displayName ?? userEmail.split('@').first;
        final photoUrl = user.photoURL;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          resizeToAvoidBottomInset: false, // ← prevents keyboard overflow
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/pos'),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              color: NovaColors.bgPrimary,
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme:
                      const IconThemeData(color: NovaColors.textSecondary),
                  title: const Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          color: NovaColors.violet, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Order Station',
                        style: TextStyle(
                          color: NovaColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0.5),
                    child: Container(
                        height: 0.5, color: NovaColors.borderTertiary),
                  ),
                  actions: [
                    StreamBuilder(
                      stream: _orderService?.getOrders(),
                      builder: (context, snapshot) {
                        final readyCount = _readyOrderCount(snapshot);
                        return IconButton(
                          tooltip: 'Ready Orders',
                          onPressed: () => _showReadyOrdersSheet(context),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                readyCount > 0
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_outlined,
                                color: readyCount > 0
                                    ? NovaColors.violet
                                    : NovaColors.textSecondary,
                                size: 22,
                              ),
                              if (readyCount > 0)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: NovaColors.teal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: NovaColors.bgPrimary,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$readyCount',
                                        style: const TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
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
            currentRoute: '/pos',
            child: StreamBuilder<List<Product>>(
              stream: _productService?.streamProducts ??
                  Stream<List<Product>>.value([]),
              builder: (context, snapshot) {
                final allProducts = snapshot.data ?? [];
                final categories = _getCategories(allProducts);

                final filteredProducts = allProducts.where((product) {
                  final matchSearch = _searchQuery.isEmpty ||
                      product.name.toLowerCase().contains(_searchQuery) ||
                      product.category.toLowerCase().contains(_searchQuery);
                  final matchCategory = _selectedCategory == 'All' ||
                      product.category == _selectedCategory;
                  return matchSearch && matchCategory;
                }).toList();

                return ResponsiveCenter(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // ── Search bar ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: NovaColors.bgPrimary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: NovaColors.borderTertiary, width: 0.5),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                            style: const TextStyle(
                                fontSize: 14, color: NovaColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search menu items…',
                              hintStyle: const TextStyle(
                                  color: NovaColors.textTertiary, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: NovaColors.textSecondary, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          color: NovaColors.textTertiary,
                                          size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Category chips ────────────────────────────────
                      if (allProducts.isNotEmpty)
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? NovaColors.violet
                                        : NovaColors.bgPrimary,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? NovaColors.violet
                                          : NovaColors.borderTertiary,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : NovaColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),

                      // ── Product area ──────────────────────────────────
                      Expanded(
                        child: () {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: NovaColors.violet),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading products',
                                    style: TextStyle(
                                        color: NovaColors.textSecondary)));
                          }
                          if (filteredProducts.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: NovaColors.bgSecondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: NovaColors.borderTertiary),
                                    ),
                                    child: const Icon(
                                        Icons.coffee_maker_outlined,
                                        size: 40,
                                        color: NovaColors.textTertiary),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No items match "$_searchQuery"'
                                        : 'No items in this category',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: NovaColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;

                              // ── Mobile: vertical list ─────────────────
                              if (isMobile) {
                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, index) {
                                    final product = filteredProducts[index];
                                    return _ProductListTile(
                                      product: product,
                                      onTap: () async {
                                        final qty = await _showQtyDialog(
                                            context,
                                            product.name,
                                            product.price);
                                        if (qty != null && qty > 0) {
                                          final productMap = product.toMap();
                                          productMap['qty'] = qty;
                                          await cart.addItem(productMap);
                                        }
                                      },
                                    );
                                  },
                                );
                              }

                              // ── Desktop / tablet: grid ────────────────
                              return GridView.builder(
                                scrollDirection: Axis.vertical,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      _crossAxisCount(constraints.maxWidth),
                                  childAspectRatio:
                                      constraints.maxWidth < 380 ? 1.35 : 0.95,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (_, index) {
                                  final product = filteredProducts[index];
                                  return _ProductCard(
                                    product: product,
                                    onTap: () async {
                                      final qty = await _showQtyDialog(
                                          context, product.name, product.price);
                                      if (qty != null && qty > 0) {
                                        final productMap = product.toMap();
                                        productMap['qty'] = qty;
                                        await cart.addItem(productMap);
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          );
                        }(),
                      ),

                      // ── Bottom action bar ─────────────────────────────
                      SafeArea(
                        top: false,
                        child: Container(
                          decoration: BoxDecoration(
                            color: NovaColors.bgPrimary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            border: const Border(
                              top: BorderSide(
                                  color: NovaColors.borderTertiary, width: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _BottomBarButton(
                                  onPressed: cart.items.isEmpty
                                      ? null
                                      : () => Navigator.pushNamed(
                                          context, '/checkout'),
                                  icon: Icons.shopping_bag_outlined,
                                  label: 'Checkout',
                                  badge: cart.items.isNotEmpty
                                      ? '${cart.items.length}'
                                      : null,
                                  isPrimary: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StreamBuilder(
                                  stream: _orderService?.getOrders(),
                                  builder: (context, snapshot) {
                                    final readyCount =
                                        _readyOrderCount(snapshot);
                                    return _BottomBarButton(
                                      onPressed: () =>
                                          _showReadyOrdersSheet(context),
                                      icon: Icons.receipt_long_outlined,
                                      label: 'Ready Orders',
                                      badge:
                                          readyCount > 0 ? '$readyCount' : null,
                                      isPrimary: false,
                                      badgeColor: NovaColors.teal,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Product List Tile (mobile) ────────────────────────────────────────────────
class _ProductListTile extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductListTile({required this.product, required this.onTap});

  @override
  State<_ProductListTile> createState() => _ProductListTileState();
}

class _ProductListTileState extends State<_ProductListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _emoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('coffee') || c.contains('hot drink')) return '☕';
    if (c.contains('cold') || c.contains('drink') || c.contains('juice')) {
      return '🧃';
    }
    if (c.contains('food') || c.contains('meal') || c.contains('snack')) {
      return '🍽️';
    }
    if (c.contains('dessert') || c.contains('sweet')) return '🍰';
    if (c.contains('sandwich') || c.contains('burger')) return '🥪';
    if (c.contains('pizza')) return '🍕';
    if (c.contains('salad')) return '🥗';
    return '🍴';
  }

  Color _bgColor(String name) {
    final colors = [
      const Color(0xFFF3F2FE),
      const Color(0xFFE1F5EE),
      const Color(0xFFFAEEDA),
      const Color(0xFFFFEEF3),
      const Color(0xFFE8F4FD),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
          ),
          child: Row(
            children: [
              // Emoji thumbnail
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bgColor(widget.product.name),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _emoji(widget.product.category),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              // Name + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.product.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: NovaColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Price + add button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: NovaColors.violetLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Rs ${widget.product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.violet,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: NovaColors.violetLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: NovaColors.violet,
                        size: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Product Card (desktop/tablet) ────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _categoryEmoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('coffee') || c.contains('hot drink')) return '☕';
    if (c.contains('cold') || c.contains('drink') || c.contains('juice')) {
      return '🧃';
    }
    if (c.contains('food') || c.contains('meal') || c.contains('snack')) {
      return '🍽️';
    }
    if (c.contains('dessert') || c.contains('sweet')) return '🍰';
    if (c.contains('sandwich') || c.contains('burger')) return '🥪';
    if (c.contains('pizza')) return '🍕';
    if (c.contains('salad')) return '🥗';
    return '🍴';
  }

  Color _cardBgColor(String name) {
    final colors = [
      const Color(0xFFF3F2FE),
      const Color(0xFFE1F5EE),
      const Color(0xFFFAEEDA),
      const Color(0xFFFFEEF3),
      const Color(0xFFE8F4FD),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardBgColor(widget.product.name),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji(widget.product.category),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: NovaColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: NovaColors.violetLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Rs ${widget.product.price.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: NovaColors.violet,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: NovaColors.violetLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: NovaColors.violet,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Bar Button ─────────────────────────────────────────────────────────
class _BottomBarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? badge;
  final bool isPrimary;
  final Color badgeColor;

  const _BottomBarButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.badge,
    this.isPrimary = true,
    this.badgeColor = NovaColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 44,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon,
                size: 16,
                color: isDisabled
                    ? NovaColors.textTertiary
                    : isPrimary
                        ? Colors.white
                        : NovaColors.violet),
            label: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: isDisabled
                    ? NovaColors.textTertiary
                    : isPrimary
                        ? Colors.white
                        : NovaColors.violet,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled
                  ? NovaColors.bgSecondary
                  : isPrimary
                      ? NovaColors.violet
                      : NovaColors.violetLight,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDisabled
                      ? NovaColors.borderTertiary
                      : isPrimary
                          ? NovaColors.violet
                          : NovaColors.violet.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: NovaColors.bgPrimary, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Ready Order Card ──────────────────────────────────────────────────────────
class _ReadyOrderCard extends StatelessWidget {
  final String orderLabel;
  final String orderType;
  final String? customerName;
  final List<Map<String, dynamic>> items;
  final double total;
  final int index;
  final VoidCallback onComplete;

  const _ReadyOrderCard({
    required this.orderLabel,
    required this.orderType,
    this.customerName,
    required this.items,
    required this.total,
    required this.index,
    required this.onComplete,
  });

  String _orderTypeEmoji(String type) {
    final t = type.toLowerCase();
    if (t.contains('dine')) return '🍽️';
    if (t.contains('take')) return '🛍️';
    if (t.contains('delivery')) return '🚴';
    return '📦';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: NovaColors.bgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: NovaColors.borderTertiary, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      _orderTypeEmoji(orderType),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order $orderLabel',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.textPrimary,
                        ),
                      ),
                      if (customerName != null && customerName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 11, color: NovaColors.textTertiary),
                            const SizedBox(width: 3),
                            Text(
                              customerName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: NovaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NovaColors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    orderType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.tealDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: items.map((item) {
                final name = item['name'] ?? 'Unknown';
                final rawQty = item['qty'] ??
                    item['quantity'] ??
                    item['count'] ??
                    item['amount'] ??
                    1;
                final qty = int.tryParse(rawQty.toString()) ?? 1;
                final price = (item['price'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: const BoxDecoration(
                          color: NovaColors.violet,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: NovaColors.textPrimary,
                          ),
                        ),
                      ),
                      if (price != null)
                        Text(
                          'Rs ${(price * qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: NovaColors.textSecondary,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '×$qty',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.violet,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
                color: NovaColors.borderTertiary, height: 20, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 11, color: NovaColors.textTertiary)),
                    Text(
                      'Rs ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.print_rounded,
                      color: Colors.white, size: 15),
                  label: const Text(
                    'Print & Complete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.teal,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
