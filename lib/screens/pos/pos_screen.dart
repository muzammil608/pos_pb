import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/pos_header_slide_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pos_header_service.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/responsive_layout.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class _CategoryImages {
  static const Map<String, String> _images = {
    'dairy':
        'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&h=300&fit=crop',
    'fruit':
        'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&h=300&fit=crop',
    'vegetable':
        'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&h=300&fit=crop',
    'bakery':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=300&fit=crop',
    'meat':
        'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=400&h=300&fit=crop',
    'vegan':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=300&fit=crop',
    'drinks':
        'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400&h=300&fit=crop',
    'coffee':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=300&fit=crop',
    'dessert':
        'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=400&h=300&fit=crop',
    'pizza':
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=300&fit=crop',
    'burger':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop',
    'salad':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=300&fit=crop',
    'sandwich':
        'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=400&h=300&fit=crop',
    'soup':
        'https://images.unsplash.com/photo-1547592180-85f173990554?w=400&h=300&fit=crop',
    'pasta':
        'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=400&h=300&fit=crop',
    'rice':
        'https://images.unsplash.com/photo-1536304993881-ff86e6a7cf78?w=400&h=300&fit=crop',
    'seafood':
        'https://images.unsplash.com/photo-1559737558-2f5a35f4523b?w=400&h=300&fit=crop',
    'chicken':
        'https://images.unsplash.com/photo-1598103442097-8b74394b95c1?w=400&h=300&fit=crop',
    'breakfast':
        'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=400&h=300&fit=crop',
    'snack':
        'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?w=400&h=300&fit=crop',
  };

  static const String _fallback =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=300&fit=crop';

  static String forCategory(String category) {
    final key = category.toLowerCase().trim();
    if (_images.containsKey(key)) return _images[key]!;
    for (final entry in _images.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return _fallback;
  }
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  ProductService? _productService;
  OrderService? _orderService;
  PosHeaderService? _posHeaderService;

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<PosSearchBarState> _searchBarKey =
      GlobalKey<PosSearchBarState>();
  final GlobalKey<PosCategoryChipsState> _categoryChipsKey =
      GlobalKey<PosCategoryChipsState>();

  late AnimationController _pulseController;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  int _focusedProductIndex = -1;
  List<Product> _lastFilteredProducts = [];

  bool _readyOrdersSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _registerHotkeys();
  }

  Future<void> _registerHotkeys() async {
    await PosHotkeyRegistry.register(
      onF1NewOrder: () {
        if (mounted) {
          _searchBarKey.currentState?.requestFocus();
        }
      },
      onF2Cart: () {
        if (!mounted) return;
        _showReadyOrdersSheet(context);
      },
      onF3HoldOrder: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hold order — coming soon'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onF4AddCustomer: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add customer — coming soon'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onF5Refresh: () {
        if (mounted) setState(() {});
      },
      onF6Kitchen: () {
        if (mounted) _onKitchen();
      },
      onCtrlF: () {
        _searchBarKey.currentState?.requestFocus();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.ownerId.isNotEmpty) {
      _productService = ProductService(auth.ownerId);
      _orderService = OrderService(auth.ownerId);
      _posHeaderService = PosHeaderService(auth.ownerId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    _posHeaderService?.dispose();
    PosHotkeyRegistry.unregisterAll();
    super.dispose();
  }

  void _onArrowDown() {
    if (_lastFilteredProducts.isEmpty) return;
    setState(() {
      _focusedProductIndex =
          (_focusedProductIndex + 1).clamp(0, _lastFilteredProducts.length - 1);
    });
  }

  void _onArrowUp() {
    if (_lastFilteredProducts.isEmpty) return;
    setState(() {
      _focusedProductIndex =
          (_focusedProductIndex - 1).clamp(0, _lastFilteredProducts.length - 1);
    });
  }

  void _onArrowRight() {
    _categoryChipsKey.currentState?.nextCategory();
  }

  void _onArrowLeft() {
    _categoryChipsKey.currentState?.prevCategory();
  }

  void _onConfirmFocusedItem() {
    if (_focusedProductIndex < 0 ||
        _focusedProductIndex >= _lastFilteredProducts.length) {
      return;
    }
    final product = _lastFilteredProducts[_focusedProductIndex];
    _addProductWithQtyDialog(product);
  }

  void _onDeleteFocusedItem() {}

  void _onUndoCart() {
    final stack = CartUndoStack.instance;
    if (stack.canUndo) {
      stack.undo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undone: ${stack.lastDescription ?? "last action"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onCheckout() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isNotEmpty) {
      Navigator.pushNamed(context, '/checkout');
    }
  }

  void _onKitchen() {
    Navigator.pushNamed(context, '/kitchen');
  }

  void _onClearCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    final snapshot = List<Map<String, dynamic>>.from(cart.items);
    CartUndoStack.instance.push('Clear cart', () {
      for (final item in snapshot) {
        cart.addItem(item);
      }
    });
    cart.clear();
  }

  Future<void> _addProductWithQtyDialog(Product product) async {
    final qty = await _showQtyDialog(context, product.name, product.price);
    if (qty != null && qty > 0 && mounted) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final productMap = product.toMap();
      productMap['qty'] = qty;
      await cart.addItem(productMap);

      CartUndoStack.instance.push('Add ${product.name}', () {
        cart.removeItem(product.id);
      });
    }
  }

  Future<int?> _showQtyDialog(
      BuildContext context, String productName, double price) async {
    int qty = 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final isDesktop = screenWidth >= 768;

        return Dialog(
          insetPadding: isDesktop
              ? EdgeInsets.symmetric(
                  horizontal: (screenWidth - 400) / 2,
                  vertical: 80,
                )
              : const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: NovaColors.bgPrimary,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 400 : double.infinity,
            ),
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
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(Icons.close_rounded,
                            color: NovaColors.textTertiary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs ${price.toStringAsFixed(0)} / item',
                    style: const TextStyle(
                        fontSize: 13, color: NovaColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) => qty = int.tryParse(value) ?? 1,
                    onSubmitted: (_) => Navigator.pop(dialogContext, qty),
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
                        borderSide: const BorderSide(
                            color: NovaColors.violet, width: 1.5),
                      ),
                      filled: true,
                      fillColor: NovaColors.bgSecondary,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                            side: const BorderSide(
                                color: NovaColors.borderSecondary),
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
      },
    );
  }

  int _readyOrderCount(AsyncSnapshot<OrderRecordSnapshot> snapshot) {
    if (!snapshot.hasData) return 0;
    return snapshot.data!.docs
        .where((doc) => doc.data()['status'] == 'ready')
        .length;
  }

  Future<void> _completeReadyOrder({
    required BuildContext sheetContext,
    required BuildContext rootContext,
    required OrderRecordDocument doc,
  }) async {
    final data = doc.data();
    final orderId = doc.id;
    final orderType = data['orderType']?.toString() ?? 'takeaway';
    final customerName = data['customerName']?.toString().trim();
    final items = List<Map<String, dynamic>>.from(
      (data['items'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    Navigator.pop(sheetContext);
    await _orderService?.updateStatus(orderId, 'completed');
    if (!rootContext.mounted) return;

    final orderNumber = (data['orderNumber'] as num?)?.toInt() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final tendered = (data['tenderedAmount'] as num?)?.toDouble() ?? total;
    final change = (data['change'] as num?)?.toDouble() ?? 0.0;
    final createdAt = data['createdAt'] as DateTime?;
    final localCreatedAt = createdAt?.toLocal();
    final date = localCreatedAt != null
        ? '${localCreatedAt.day}/${localCreatedAt.month}/${localCreatedAt.year} '
            '${localCreatedAt.hour.toString().padLeft(2, '0')}:'
            '${localCreatedAt.minute.toString().padLeft(2, '0')}'
        : '';
    final servedBy = Provider.of<AuthProvider>(rootContext, listen: false).role;

    await showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) => ReceiptDialog(
        companyName: 'Orion POS',
        phone: '+92-317-7921817',
        email: 'info@orion.com',
        website: 'www.orion.com',
        servedBy: servedBy,
        customerName: customerName ?? 'Walk-in Customer',
        orderType: orderType,
        items: items,
        total: total,
        cash: tendered,
        change: change,
        tax: 0.0,
        paymentMethod: data['paymentMethod'] ?? 'cash',
        orderNo: 'ORDER-$orderNumber',
        date: date,
      ),
    );
  }

  Future<void> _showReadyOrdersSheet(BuildContext context) async {
    if (_readyOrdersSheetOpen) return;
    _readyOrdersSheetOpen = true;

    final rootContext = context;
    try {
      await showModalBottomSheet<void>(
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
                            StreamBuilder<OrderRecordSnapshot>(
                              stream: _orderService?.getOrders(),
                              builder: (context, snapshot) {
                                if (_orderService == null) {
                                  return const SizedBox.shrink();
                                }
                                if (snapshot.hasError ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }
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
                        child: StreamBuilder<OrderRecordSnapshot>(
                          stream: _orderService?.getOrders(),
                          builder: (context, snapshot) {
                            if (_orderService == null) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: NovaColors.violet),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(
                                      color: NovaColors.textSecondary),
                                ),
                              );
                            }
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

                            final readyDocs = snapshot.data!.docs.where((doc) {
                              return doc.data()['status'] == 'ready';
                            }).toList();

                            readyDocs.sort((a, b) {
                              final aDate = a.data()['createdAt'] as DateTime?;
                              final bDate = b.data()['createdAt'] as DateTime?;
                              final aMs = aDate?.millisecondsSinceEpoch ?? 0;
                              final bMs = bDate?.millisecondsSinceEpoch ?? 0;
                              return bMs.compareTo(aMs);
                            });

                            if (readyDocs.isEmpty) return _emptyOrdersView();

                            return Shortcuts(
                              shortcuts: const {
                                SingleActivator(LogicalKeyboardKey.enter):
                                    ConfirmItemIntent(),
                                SingleActivator(LogicalKeyboardKey.numpadEnter):
                                    ConfirmItemIntent(),
                              },
                              child: Actions(
                                actions: {
                                  ConfirmItemIntent:
                                      CallbackAction<ConfirmItemIntent>(
                                    onInvoke: (_) {
                                      _completeReadyOrder(
                                        sheetContext: sheetContext,
                                        rootContext: rootContext,
                                        doc: readyDocs.first,
                                      );
                                      return null;
                                    },
                                  ),
                                },
                                child: Focus(
                                  autofocus: true,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 24),
                                    itemCount: readyDocs.length,
                                    itemBuilder: (context, index) {
                                      final doc = readyDocs[index];
                                      final data = doc.data();

                                      final orderType =
                                          data['orderType']?.toString() ??
                                              'takeaway';
                                      final customerName = data['customerName']
                                          ?.toString()
                                          .trim();
                                      final orderLabel =
                                          '#${data['orderNumber'] ?? doc.id.substring(0, 6)}';
                                      final items =
                                          List<Map<String, dynamic>>.from(
                                        (data['items'] as List? ?? []).map(
                                          (item) => Map<String, dynamic>.from(
                                              item as Map),
                                        ),
                                      );

                                      return _ReadyOrderCard(
                                        orderLabel: orderLabel,
                                        orderType: orderType,
                                        customerName: customerName,
                                        items: items,
                                        total: (data['total'] as num?)
                                                ?.toDouble() ??
                                            0,
                                        index: index,
                                        onComplete: () => _completeReadyOrder(
                                          sheetContext: sheetContext,
                                          rootContext: rootContext,
                                          doc: doc,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
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
    } finally {
      if (mounted) setState(() => _readyOrdersSheetOpen = false);
    }
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
          resizeToAvoidBottomInset: false,
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
                    if (_isDesktop)
                      IconButton(
                        tooltip: 'Keyboard Shortcuts (?)',
                        onPressed: () => PosShortcutHelp.show(context),
                        icon: const Icon(Icons.keyboard_rounded,
                            color: NovaColors.textSecondary, size: 20),
                      ),
                    StreamBuilder<OrderRecordSnapshot>(
                      stream: _orderService?.getOrders(),
                      builder: (context, snapshot) {
                        final readyCount = _readyOrderCount(snapshot);
                        return IconButton(
                          tooltip: 'Ready Orders  (F2)',
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
            child: PosKeyboardScope(
              searchBarKey: _searchBarKey,
              categoryChipsKey: _categoryChipsKey,
              onCheckout: _onCheckout,
              onReadyOrders: () => _showReadyOrdersSheet(context),
              onKitchen: _onKitchen,
              onClearCart: _onClearCart,
              onDeleteFocusedItem: _onDeleteFocusedItem,
              onUndoCart: _onUndoCart,
              onConfirmFocusedItem: _onConfirmFocusedItem,
              onArrowUp: _onArrowUp,
              onArrowDown: _onArrowDown,
              onArrowLeft: _onArrowLeft,
              onArrowRight: _onArrowRight,
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

                  _lastFilteredProducts = filteredProducts;

                  return ResponsiveCenter(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: PosSearchBar(
                            key: _searchBarKey,
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (allProducts.isNotEmpty)
                          PosCategoryChips(
                            key: _categoryChipsKey,
                            categories: categories,
                            selected: _selectedCategory,
                            onSelected: (cat) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        if (_posHeaderService != null) ...[
                          const SizedBox(height: 10),
                          PosHeaderSlideshow(
                            service: _posHeaderService!,
                            canEdit: auth.isAdmin,
                          ),
                        ],
                        const SizedBox(height: 10),
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

                                if (isMobile) {
                                  return ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 12),
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (_, index) {
                                      final product = filteredProducts[index];
                                      final isFocused =
                                          _focusedProductIndex == index;
                                      return _ProductListTile(
                                        product: product,
                                        isFocused: isFocused,
                                        onTap: () =>
                                            _addProductWithQtyDialog(product),
                                      );
                                    },
                                  );
                                }

                                return GridView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        _crossAxisCount(constraints.maxWidth),
                                    childAspectRatio: constraints.maxWidth < 380
                                        ? 1.35
                                        : 0.78,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, index) {
                                    final product = filteredProducts[index];
                                    final isFocused =
                                        _focusedProductIndex == index;
                                    return _ProductCard(
                                      product: product,
                                      isFocused: isFocused,
                                      onTap: () =>
                                          _addProductWithQtyDialog(product),
                                    );
                                  },
                                );
                              },
                            );
                          }(),
                        ),
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
                                    color: NovaColors.borderTertiary,
                                    width: 0.5),
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
                                    onPressed:
                                        cart.items.isEmpty ? null : _onCheckout,
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
                                  child: StreamBuilder<OrderRecordSnapshot>(
                                    stream: _orderService?.getOrders(),
                                    builder: (context, snapshot) {
                                      final readyCount =
                                          _readyOrderCount(snapshot);
                                      return _BottomBarButton(
                                        onPressed: () =>
                                            _showReadyOrdersSheet(context),
                                        icon: Icons.receipt_long_outlined,
                                        label: 'Ready Orders',
                                        badge: readyCount > 0
                                            ? '$readyCount'
                                            : null,
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
          ),
        );
      },
    );
  }
}

class PosHeaderSlideshow extends StatefulWidget {
  final PosHeaderService service;
  final bool canEdit;

  const PosHeaderSlideshow({
    super.key,
    required this.service,
    required this.canEdit,
  });

  @override
  State<PosHeaderSlideshow> createState() => _PosHeaderSlideshowState();
}

class _PosHeaderSlideshowState extends State<PosHeaderSlideshow> {
  static const Duration _interval = Duration(seconds: 4);
  static const double _headerRadius = 20;

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _startTimer();
  }

  Future<void> _editSlides(List<PosHeaderSlide> slides) async {
    final updated = await showDialog<List<PosHeaderSlide>>(
      context: context,
      builder: (_) => _PosHeaderEditorDialog(slides: slides),
    );
    if (updated == null || !mounted) return;

    try {
      await widget.service.saveSlides(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('POS header updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save header. ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PosHeaderSlide>>(
      stream: widget.service.slidesStream,
      builder: (context, snapshot) {
        final slides = snapshot.data ?? PosHeaderSlide.defaults('');
        final activeSlides = slides.where((slide) => slide.isActive).toList();
        if (activeSlides.isEmpty) return const SizedBox.shrink();

        final activeIndex = _index % activeSlides.length;
        final slide = activeSlides[activeIndex];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            final height = isCompact ? 132.0 : 170.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_headerRadius),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_headerRadius),
                    border: Border.all(color: NovaColors.borderTertiary),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 650),
                        child: _HeaderSlideView(
                          key: ValueKey('${slide.id}-$activeIndex'),
                          slide: slide,
                          isCompact: isCompact,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            activeSlides.length,
                            (i) => GestureDetector(
                              onTap: () => _goTo(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: i == activeIndex ? 18 : 7,
                                height: 7,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    i == activeIndex ? 0.95 : 0.45,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(activeIndex),
                        tween: Tween(begin: 0, end: 1),
                        duration: _interval,
                        builder: (context, value, child) {
                          return Align(
                            alignment: Alignment.bottomLeft,
                            child: FractionallySizedBox(
                              widthFactor: value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          height: 3,
                          color: const Color(0xFFFF8C00).withOpacity(0.85),
                        ),
                      ),
                      if (widget.canEdit)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton.filledTonal(
                            onPressed: () => _editSlides(slides),
                            tooltip: 'Edit POS header',
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderSlideView extends StatelessWidget {
  final PosHeaderSlide slide;
  final bool isCompact;

  const _HeaderSlideView({
    super.key,
    required this.slide,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.startColor, slide.middleColor, slide.endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.10),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? 320 : 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE84B30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slide.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 18 : 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.subtitle,
                      maxLines: isCompact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: isCompact ? 12 : 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosHeaderEditorDialog extends StatefulWidget {
  final List<PosHeaderSlide> slides;

  const _PosHeaderEditorDialog({required this.slides});

  @override
  State<_PosHeaderEditorDialog> createState() => _PosHeaderEditorDialogState();
}

class _PosHeaderEditorDialogState extends State<_PosHeaderEditorDialog> {
  late final List<_SlideEditState> _slides;

  @override
  void initState() {
    super.initState();
    _slides = widget.slides.take(4).map(_SlideEditState.new).toList();
    if (_slides.isEmpty) {
      _slides.addAll(PosHeaderSlide.defaults('').map(_SlideEditState.new));
    }
  }

  @override
  void dispose() {
    for (final slide in _slides) {
      slide.dispose();
    }
    super.dispose();
  }

  List<PosHeaderSlide> _buildSlides() {
    return [
      for (var i = 0; i < _slides.length; i++) _slides[i].toSlide(i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 640;
    final dialogWidth = isCompact ? screenWidth - 24 : 560.0;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 40,
        vertical: isCompact ? 16 : 24,
      ),
      backgroundColor: NovaColors.bgPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        isCompact ? 18 : 22,
        isCompact ? 18 : 24,
        12,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        0,
        isCompact ? 18 : 24,
        16,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        0,
        isCompact ? 12 : 16,
        16,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NovaColors.violetLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.view_carousel_rounded,
              color: NovaColors.violet,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit POS Header',
                  style: TextStyle(
                    color: NovaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Update the slides shown above your product grid.',
                  style: TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _slides.length; i++) ...[
                _SlideEditCard(index: i, state: _slides[i]),
                if (i != _slides.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (isCompact) ...[
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: NovaColors.textSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NovaColors.violet,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, _buildSlides()),
              child: const Text('Save'),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: NovaColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NovaColors.violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, _buildSlides()),
            child: const Text('Save'),
          ),
        ],
      ],
    );
  }
}

class _SlideEditState {
  final PosHeaderSlide original;
  late final TextEditingController badge;
  late final TextEditingController title;
  late final TextEditingController subtitle;
  late final TextEditingController startColor;
  late final TextEditingController middleColor;
  late final TextEditingController endColor;

  _SlideEditState(this.original) {
    badge = TextEditingController(text: original.badge);
    title = TextEditingController(text: original.title);
    subtitle = TextEditingController(text: original.subtitle);
    startColor = TextEditingController(text: colorToHex(original.startColor));
    middleColor = TextEditingController(text: colorToHex(original.middleColor));
    endColor = TextEditingController(text: colorToHex(original.endColor));
  }

  PosHeaderSlide toSlide(int index) {
    return original.copyWith(
      badge: badge.text.trim(),
      title: title.text.trim(),
      subtitle: subtitle.text.trim(),
      startColor: colorFromHex(startColor.text, original.startColor.value),
      middleColor: colorFromHex(middleColor.text, original.middleColor.value),
      endColor: colorFromHex(endColor.text, original.endColor.value),
      sortOrder: index,
      isActive: true,
    );
  }

  void dispose() {
    badge.dispose();
    title.dispose();
    subtitle.dispose();
    startColor.dispose();
    middleColor.dispose();
    endColor.dispose();
  }
}

class _SlideEditCard extends StatelessWidget {
  static const List<Color> _palette = [
    Color(0xFF2E1600),
    Color(0xFF7A3300),
    Color(0xFFC45C00),
    Color(0xFFE84B30),
    Color(0xFFBE123C),
    Color(0xFFD4537E),
    Color(0xFF7C3AED),
    Color(0xFF534AB7),
    Color(0xFF1D4ED8),
    Color(0xFF0891B2),
    Color(0xFF1D9E75),
    Color(0xFF2E7D32),
    Color(0xFF65A30D),
    Color(0xFFEAB308),
    Color(0xFFBA7517),
    Color(0xFF6B7280),
    Color(0xFF374151),
    Color(0xFF111827),
  ];

  final int index;
  final _SlideEditState state;

  const _SlideEditCard({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        border: Border.all(color: NovaColors.borderTertiary),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: NovaColors.violetLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: NovaColors.violet,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Slide',
                  style: TextStyle(
                    color: NovaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _HeaderEditorField(
              controller: state.badge,
              label: 'Badge',
            ),
            const SizedBox(height: 10),
            _HeaderEditorField(
              controller: state.title,
              label: 'Title',
            ),
            const SizedBox(height: 10),
            _HeaderEditorField(
              controller: state.subtitle,
              label: 'Subtitle',
            ),
            const SizedBox(height: 12),
            Text(
              'Choose gradient colors',
              style: TextStyle(
                color: NovaColors.textPrimary,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _HeaderColorPalette(
              label: 'Start color',
              controller: state.startColor,
              colors: _palette,
            ),
            const SizedBox(height: 10),
            _HeaderColorPalette(
              label: 'Middle color',
              controller: state.middleColor,
              colors: _palette,
            ),
            const SizedBox(height: 10),
            _HeaderColorPalette(
              label: 'End color',
              controller: state.endColor,
              colors: _palette,
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: Listenable.merge([
                state.badge,
                state.title,
                state.subtitle,
                state.startColor,
                state.middleColor,
                state.endColor,
              ]),
              builder: (context, _) {
                return Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorFromHex(state.startColor.text,
                            state.original.startColor.value),
                        colorFromHex(state.middleColor.text,
                            state.original.middleColor.value),
                        colorFromHex(
                            state.endColor.text, state.original.endColor.value),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.black.withOpacity(0.08),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.badge.text.trim().isEmpty
                              ? 'BADGE'
                              : state.badge.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          state.title.text.trim().isEmpty
                              ? 'Slide title'
                              : state.title.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.subtitle.text.trim().isEmpty
                              ? 'Slide subtitle'
                              : state.subtitle.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderColorPalette extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<Color> colors;

  const _HeaderColorPalette({
    required this.label,
    required this.controller,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selectedHex = value.text.trim().toUpperCase();
        final selectedColor = colorFromHex(selectedHex, Colors.black.value);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showColorPaletteDialog(
              context,
              label: label,
              controller: controller,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NovaColors.bgPrimary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NovaColors.borderTertiary),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NovaColors.borderSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedHex,
                          style: const TextStyle(
                            color: NovaColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.palette_outlined,
                    color: NovaColors.violet,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showColorPaletteDialog(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required List<Color> colors,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final selectedHex = value.text.trim().toUpperCase();

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: NovaColors.bgPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorFromHex(selectedHex, Colors.black.value),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NovaColors.borderSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: NovaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in colors)
                        _PaletteSwatch(
                          color: color,
                          isSelected:
                              colorToHex(color).toUpperCase() == selectedHex,
                          onTap: () => controller.text = colorToHex(color),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: NovaColors.violet),
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

class _PaletteSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 42 : 36,
          height: isSelected ? 42 : 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? NovaColors.textPrimary : Colors.white,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? 0.16 : 0.08),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                )
              : null,
        ),
      ),
    );
  }
}

class _HeaderEditorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _HeaderEditorField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: NovaColors.violet,
      style: const TextStyle(
        fontSize: 14,
        color: NovaColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: NovaColors.textSecondary,
          fontSize: 13,
        ),
        filled: true,
        fillColor: NovaColors.bgPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: NovaColors.borderTertiary,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: NovaColors.violet,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Product product;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const _ProductImage({
    required this.product,
    this.width,
    this.height,
    this.borderRadius,
  });

  String get _imageUrl => product.imageUrl?.isNotEmpty == true
      ? product.imageUrl!
      : _CategoryImages.forCategory(product.category);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        _imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: NovaColors.bgSecondary,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: NovaColors.violet,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: NovaColors.violetLight,
            child: const Center(
              child: Icon(Icons.fastfood_rounded,
                  color: NovaColors.violet, size: 28),
            ),
          );
        },
      ),
    );
  }
}

class _ProductListTile extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isFocused;

  const _ProductListTile({
    required this.product,
    required this.onTap,
    this.isFocused = false,
  });

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
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isFocused
                  ? NovaColors.violet
                  : NovaColors.borderTertiary,
              width: widget.isFocused ? 1.5 : 0.5,
            ),
            boxShadow: widget.isFocused
                ? [
                    BoxShadow(
                      color: NovaColors.violet.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                child: _ProductImage(
                  product: widget.product,
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: 12),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NovaColors.bgTertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.product.category,
                        style: const TextStyle(
                          fontSize: 10,
                          color: NovaColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                      child: const Icon(Icons.add_rounded,
                          color: NovaColors.violet, size: 15),
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

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isFocused;

  const _ProductCard({
    required this.product,
    required this.onTap,
    this.isFocused = false,
  });

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
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isFocused
                  ? NovaColors.violet
                  : NovaColors.borderTertiary,
              width: widget.isFocused ? 1.5 : 0.5,
            ),
            boxShadow: widget.isFocused
                ? [
                    BoxShadow(
                      color: NovaColors.violet.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _ProductImage(
                  product: widget.product,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: NovaColors.violet,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: NovaColors.violetLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: NovaColors.violet, size: 13),
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
                    child: Text(_orderTypeEmoji(orderType),
                        style: const TextStyle(fontSize: 20)),
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
                            Text(customerName!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: NovaColors.textSecondary)),
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
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13, color: NovaColors.textPrimary)),
                      ),
                      if (price != null)
                        Text(
                          'Rs ${(price * qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, color: NovaColors.textSecondary),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('×$qty',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: NovaColors.violet)),
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
                  label: const Text('Print & Complete',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
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
