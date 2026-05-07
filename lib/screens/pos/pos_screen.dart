// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';

class CafeColors {
  static const Color flame = Color(0xFFFF4D1C); // primary accent
  static const Color amber = Color(0xFFFFA724); // secondary warm
  static const Color espresso = Color(0xFF1E0F00); // deep background
  static const Color latte = Color(0xFFFFF3E8); // light card surface
  static const Color steam = Color(0xFFFFFAF5); // soft card bg
  static const Color creme = Color(0xFFFFE4C4); // light chip bg
  static const Color olive = Color(0xFF2D6A4F); // "ready" green
  static const Color oliveLight = Color(0xFFD8F3DC); // green badge bg
  static const Color charcoal = Color(0xFF2C2C2C); // text dark

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

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: CafeColors.headerGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CafeColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rs ${price.toStringAsFixed(0)} / item',
                style: const TextStyle(
                  fontSize: 13,
                  color: CafeColors.flame,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (value) => qty = int.tryParse(value) ?? 1,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: '1',
                  labelStyle:
                      TextStyle(color: CafeColors.flame.withOpacity(0.8)),
                  prefixIcon: const Icon(Icons.format_list_numbered,
                      color: CafeColors.flame),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: CafeColors.flame.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: CafeColors.flame, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: CafeColors.flame.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: CafeColors.flame)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: CafeColors.headerGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, qty),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Add to Cart',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
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
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: const BoxDecoration(
            color: CafeColors.latte,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 2),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CafeColors.flame.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: CafeColors.headerGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CafeColors.flame.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to Collect',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Tap Print & Complete to close order',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
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
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: CafeColors.flame,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder(
                    stream: _orderService?.getOrders(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: CafeColors.flame),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                              (item) => Map<String, dynamic>.from(item as Map),
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
                                  (data['orderNumber'] as num?)?.toInt() ?? 0;
                              final total =
                                  (data['total'] as num?)?.toDouble() ?? 0.0;
                              final tendered = (data['tenderedAmount'] as num?)
                                      ?.toDouble() ??
                                  total;
                              final change =
                                  (data['change'] as num?)?.toDouble() ?? 0.0;
                              final createdAt = data['createdAt'] as DateTime?;
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
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.coffee_outlined,
                size: 48, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          const Text('No ready orders yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CafeColors.charcoal)),
          const SizedBox(height: 4),
          Text('New orders will appear here',
              style: TextStyle(
                  fontSize: 13, color: CafeColors.charcoal.withOpacity(0.5))),
        ],
      ),
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Derive unique categories from product list
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
              body: Center(child: CircularProgressIndicator()));
        }

        final user = auth.user!;
        final userEmail = user.email;
        final userName = user.displayName ?? userEmail.split('@').first;
        final photoUrl = user.photoURL;

        return Scaffold(
          backgroundColor: CafeColors.latte,
          drawer: AppNavigationDrawer(auth: auth, currentRoute: '/pos'),
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
                      Icon(Icons.storefront_rounded,
                          color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Order Station',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    StreamBuilder(
                      stream: _orderService?.getOrders(),
                      builder: (context, snapshot) {
                        final readyCount = _readyOrderCount(snapshot);
                        return AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
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
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  if (readyCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: CafeColors.flame,
                                              width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 16, minHeight: 16),
                                        child: Text(
                                          '$readyCount',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: CafeColors.flame,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
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
          body: StreamBuilder<List<Product>>(
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

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: CafeColors.flame.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        style: const TextStyle(
                            fontSize: 14, color: CafeColors.charcoal),
                        decoration: InputDecoration(
                          hintText: 'Search menu items...',
                          hintStyle:
                              TextStyle(color: Colors.grey[400], fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: CafeColors.flame, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: Colors.grey[500], size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (allProducts.isNotEmpty)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? CafeColors.headerGradient
                                    : null,
                                color: isSelected ? null : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : CafeColors.flame.withOpacity(0.2),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              CafeColors.flame.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : CafeColors.charcoal.withOpacity(0.7),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: () {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: CafeColors.flame),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Error loading products'));
                      }
                      if (filteredProducts.isEmpty) {
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
                                child: const Icon(Icons.coffee_maker_outlined,
                                    size: 52, color: CafeColors.flame),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No items match "$_searchQuery"'
                                    : 'No items in this category',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CafeColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = _crossAxisCount(constraints.maxWidth);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              childAspectRatio: 0.95,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
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
                  Container(
                    decoration: const BoxDecoration(
                      gradient: CafeColors.bottomBarGradient,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x44FF4D1C),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Row(
                      children: [
                        // Checkout button
                        Expanded(
                          child: _BottomBarButton(
                            onPressed: cart.items.isEmpty
                                ? null
                                : () =>
                                    Navigator.pushNamed(context, '/checkout'),
                            icon: Icons.shopping_bag_outlined,
                            label: 'Checkout',
                            badge: cart.items.isNotEmpty
                                ? '${cart.items.length}'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Ready orders button
                        Expanded(
                          child: StreamBuilder(
                            stream: _orderService?.getOrders(),
                            builder: (context, snapshot) {
                              final readyCount = _readyOrderCount(snapshot);
                              return _BottomBarButton(
                                onPressed: () => _showReadyOrdersSheet(context),
                                icon: Icons.receipt_long_outlined,
                                label: 'Ready Orders',
                                badge: readyCount > 0 ? '$readyCount' : null,
                                badgeColor: const Color(0xFF2ECC71),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

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
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Pick an emoji icon for category
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

  LinearGradient _cardAccentGradient(String name) {
    final gradients = [
      const LinearGradient(colors: [Color(0xFFFFE0CC), Color(0xFFFFCDB5)]),
      const LinearGradient(colors: [Color(0xFFFFE5D9), Color(0xFFFFCEC5)]),
      const LinearGradient(colors: [Color(0xFFFFF0CC), Color(0xFFFFE4A0)]),
      const LinearGradient(colors: [Color(0xFFE8F4FD), Color(0xFFCDE8FB)]),
      const LinearGradient(colors: [Color(0xFFEDF9EC), Color(0xFFCCF0CB)]),
    ];
    return gradients[name.codeUnitAt(0) % gradients.length];
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CafeColors.flame.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top colored icon area
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _cardAccentGradient(widget.product.name),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji(widget.product.category),
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
              ),
              // Bottom info area
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: CafeColors.headerGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rs ${widget.product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: CafeColors.flame.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: CafeColors.flame,
                              size: 16,
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

class _BottomBarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? badge;
  final Color badgeColor;

  const _BottomBarButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon,
                size: 18, color: isDisabled ? Colors.white38 : Colors.white),
            label: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDisabled ? Colors.white38 : Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled ? Colors.white12 : Colors.white24,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDisabled ? Colors.white12 : Colors.white38,
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
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: CafeColors.flame, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

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

  LinearGradient _accentGradient() {
    final gradients = [
      const LinearGradient(
          colors: [Color(0xFFFFE0CC), Color(0xFFFFCDB5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      const LinearGradient(
          colors: [Color(0xFFFFF0CC), Color(0xFFFFE4A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      const LinearGradient(
          colors: [Color(0xFFEDF9EC), Color(0xFFCCF0CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      const LinearGradient(
          colors: [Color(0xFFE8F4FD), Color(0xFFCDE8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CafeColors.flame.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: _accentGradient(),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Order type emoji badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _orderTypeEmoji(orderType),
                      style: const TextStyle(fontSize: 22),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CafeColors.charcoal,
                        ),
                      ),
                      if (customerName != null && customerName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 12, color: CafeColors.charcoal),
                            const SizedBox(width: 3),
                            Text(
                              customerName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: CafeColors.charcoal.withOpacity(0.6),
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: CafeColors.headerGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CafeColors.flame.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    orderType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                final name = item['name'] ?? 'Unknown';
                final rawQty = item['qty'] ??
                    item['quantity'] ??
                    item['count'] ??
                    item['amount'] ??
                    1;
                final qty = int.tryParse(rawQty.toString()) ?? 1;
                final price = (item['price'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: const BoxDecoration(
                          gradient: CafeColors.headerGradient,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CafeColors.charcoal,
                          ),
                        ),
                      ),
                      if (price != null)
                        Text(
                          'Rs ${(price * qty).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: CafeColors.charcoal.withOpacity(0.5),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: CafeColors.headerGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '×$qty',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Divider(color: CafeColors.flame.withOpacity(0.1), height: 20),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 11,
                          color: CafeColors.charcoal.withOpacity(0.45)),
                    ),
                    Text(
                      'Rs ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CafeColors.charcoal,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.print_rounded,
                        color: Colors.white, size: 17),
                    label: const Text(
                      'Print & Complete',
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
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
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
