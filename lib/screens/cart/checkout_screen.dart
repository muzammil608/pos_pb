// ignore_for_file: deprecated_member_use, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../widgets/app_navigation.dart';
import 'product_list_bottom_sheet.dart';

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

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final OrderService _orderService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _orderService = OrderService(auth.ownerId);
  }

  String _orderType = 'takeaway';
  String? _tableNumber;
  String _customerName = '';
  String _paymentMethod = 'cash';
  double _tenderedAmount = 0.0;
  bool _isSubmitting = false;
  late FocusNode _cashFocus = FocusNode();

  @override
  void dispose() {
    _cashFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: CafeColors.flame.withOpacity(0.8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon:
          icon != null ? Icon(icon, color: CafeColors.flame, size: 18) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CafeColors.flame, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    TextEditingController? qtyController;
    await showDialog<bool?>(
      context: context,
      builder: (dialogContext) {
        qtyController = TextEditingController(
          text: ((item['qty'] as num?)?.toInt() ?? 1).toString(),
        );
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: CafeColors.headerGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit ${item['name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: _fieldDecoration('Quantity',
                      icon: Icons.format_list_numbered),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
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
                          onPressed: () {
                            final newQty =
                                int.tryParse(qtyController!.text.trim());
                            if (newQty == null || newQty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Enter a valid quantity greater than 0.'),
                                ),
                              );
                              Navigator.pop(dialogContext, false);
                              return;
                            }
                            cart.updateItemQuantity(
                                item['cartDocId'] as String, newQty);
                            Navigator.pop(dialogContext, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save',
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
        );
      },
    );
    qtyController?.dispose();
  }

  String _itemEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('coffee') || n.contains('espresso') || n.contains('latte')) {
      return '☕';
    }
    if (n.contains('juice') || n.contains('cold') || n.contains('drink')) {
      return '🧃';
    }
    if (n.contains('burger') || n.contains('sandwich')) return '🥪';
    if (n.contains('pizza')) return '🍕';
    if (n.contains('cake') || n.contains('dessert') || n.contains('sweet')) {
      return '🍰';
    }
    if (n.contains('salad')) return '🥗';
    return '🍴';
  }

  LinearGradient _itemAccentGradient(String name) {
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
    return Consumer<AuthProvider>(builder: (context, auth, child) {
      if (!auth.isAdmin && !auth.isCashier) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/pos');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final userEmail = auth.user?.email ?? 'No Email';
      final userName = auth.user?.displayName ?? userEmail.split('@').first;
      final photoUrl = auth.user?.photoURL;

      return Scaffold(
        backgroundColor: CafeColors.latte,
        drawer: AppNavigationDrawer(auth: auth, currentRoute: '/checkout'),
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
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Checkout',
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
        body: Consumer<CartProvider>(
          builder: (context, cart, child) {
            final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            final topForm = Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CafeColors.flame.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: CafeColors.headerGradient,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, 16, 16, keyboardOpen ? 8 : 16),
                    child: Column(
                      children: [
                        // Order type + Table row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _orderType,
                                decoration: _fieldDecoration('Order Type',
                                    icon: Icons.storefront_outlined),
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CafeColors.charcoal,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'takeaway',
                                      child: Text('🛍️  Takeaway')),
                                  DropdownMenuItem(
                                      value: 'dine_in',
                                      child: Text('🍽️  Dine In')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _orderType = value ?? 'takeaway';
                                    if (_orderType != 'dine_in') {
                                      _tableNumber = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            if (_orderType == 'dine_in') ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _tableNumber,
                                  decoration: _fieldDecoration('Table',
                                      icon: Icons.table_bar_outlined),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CafeColors.charcoal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hint: Text('Select',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13)),
                                  items: List.generate(
                                    20,
                                    (i) => DropdownMenuItem(
                                      value: '${i + 1}',
                                      child: Text('Table ${i + 1}'),
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _tableNumber = value),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (value) => _customerName = value,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: CafeColors.charcoal,
                                    fontWeight: FontWeight.w600),
                                decoration: _fieldDecoration('Customer Name',
                                    icon: Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _paymentMethod,
                                decoration: _fieldDecoration('Payment',
                                    icon: Icons.payment_outlined),
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CafeColors.charcoal,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'cash', child: Text('💵  Cash')),
                                  DropdownMenuItem(
                                      value: 'card', child: Text('💳  Card')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _paymentMethod = value ?? 'cash';
                                    if (value != 'cash') _tenderedAmount = 0.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        // Cash tendered section
                        if (_paymentMethod == 'cash') ...[
                          const SizedBox(height: 12),
                          TextField(
                            focusNode: _cashFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (value) => setState(() {
                              _tenderedAmount = double.tryParse(value) ?? 0.0;
                            }),
                            style: const TextStyle(
                                fontSize: 14,
                                color: CafeColors.charcoal,
                                fontWeight: FontWeight.w600),
                            decoration: _fieldDecoration('Cash Tendered',
                                    icon: Icons.money_rounded)
                                .copyWith(
                              prefixText: 'Rs  ',
                              prefixStyle: const TextStyle(
                                  color: CafeColors.flame,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_cashFocus.hasFocus &&
                              _tenderedAmount < cart.total)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.red, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Please enter the full amount',
                                    style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          // Change due card
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: (_tenderedAmount >= cart.total)
                                  ? const Color(0xFFEDF9EC)
                                  : const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (_tenderedAmount >= cart.total)
                                    ? const Color(0xFFCCF0CB)
                                    : Colors.red.shade100,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.change_circle_outlined,
                                      size: 16,
                                      color: (_tenderedAmount >= cart.total)
                                          ? const Color(0xFF2ECC71)
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Change Due',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: CafeColors.charcoal
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rs ${(_tenderedAmount - cart.total).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: (_tenderedAmount >= cart.total)
                                        ? const Color(0xFF27AE60)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );

            final cartSection = Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CafeColors.flame.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: CafeColors.headerGradient,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Cart Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        if (cart.items.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${cart.items.length} item${cart.items.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: CafeColors.flame,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (cart.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                color: CafeColors.creme,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shopping_cart_outlined,
                                  size: 36, color: CafeColors.flame),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Cart is empty',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: CafeColors.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add products from the menu',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: CafeColors.charcoal.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      itemCount: cart.items.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      separatorBuilder: (_, __) => Divider(
                        color: CafeColors.flame.withOpacity(0.08),
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final item = cart.items[i];
                        final cartDocId = item['cartDocId'] as String? ?? '';
                        final price =
                            ((item['unitPrice'] ?? item['price']) as num?) ?? 0;
                        final qty = (item['qty'] as num?)?.toInt() ?? 1;
                        final lineTotal =
                            ((item['lineTotal']) as num?)?.toDouble() ??
                                (price.toDouble() * qty);
                        final name = item['name']?.toString() ?? 'Item';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: _itemAccentGradient(name),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _itemEmoji(name),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name + sub info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: CafeColors.charcoal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: CafeColors.headerGradient,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '×$qty',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Rs ${price.toStringAsFixed(0)} each',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: CafeColors.charcoal
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Line total
                              Text(
                                'Rs ${lineTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: CafeColors.charcoal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Action buttons
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded,
                                    color: CafeColors.charcoal.withOpacity(0.4),
                                    size: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                onSelected: (value) {
                                  if (value == 'add') {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          const ProductListBottomSheet(),
                                    );
                                  } else if (value == 'edit') {
                                    _showEditItemDialog(context, cart, item);
                                  } else if (value == 'delete' &&
                                      cartDocId.isNotEmpty) {
                                    cart.removeItem(cartDocId);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'add',
                                    child: Row(children: [
                                      Icon(Icons.add_circle_outline,
                                          color: CafeColors.flame, size: 18),
                                      SizedBox(width: 10),
                                      Text('Add More',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined,
                                          color: CafeColors.amber, size: 18),
                                      SizedBox(width: 10),
                                      Text('Edit Qty',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    enabled: cartDocId.isNotEmpty,
                                    child: const Row(children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.red, size: 18),
                                      SizedBox(width: 10),
                                      Text('Remove',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: keyboardOpen ? keyboardInset + 12 : 12,
                    ),
                    children: [
                      topForm,
                      cartSection,
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (!keyboardOpen)
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
                        // Total display
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rs ${cart.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Place order button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: cart.items.isEmpty ||
                                      (_paymentMethod == 'cash' &&
                                          _tenderedAmount < cart.total) ||
                                      _isSubmitting
                                  ? null
                                  : () async {
                                      if (_orderType == 'dine_in' &&
                                          (_tableNumber == null ||
                                              _tableNumber!.isEmpty)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please select a table for dine in orders.'),
                                          ),
                                        );
                                        return;
                                      }

                                      final changeAmount =
                                          _paymentMethod == 'cash'
                                              ? _tenderedAmount - cart.total
                                              : 0.0;

                                      setState(() => _isSubmitting = true);

                                      try {
                                        final cartSnapshot =
                                            cart.items.map((item) {
                                          final qty =
                                              (item['qty'] as num?)?.toInt() ??
                                                  (item['quantity'] as num?)
                                                      ?.toInt() ??
                                                  1;
                                          final price = (item['price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          return <String, dynamic>{
                                            'name': item['name'] ?? 'Unknown',
                                            'qty': qty,
                                            'quantity': qty,
                                            'price': price,
                                            'unitPrice': price,
                                            'lineTotal': price * qty,
                                            if (item['productId'] != null)
                                              'productId': item['productId'],
                                          };
                                        }).toList();

                                        await _orderService.createOrder(
                                          items: cartSnapshot,
                                          total: cart.total,
                                          orderType: _orderType,
                                          tableNumber: _tableNumber,
                                          customerName: _customerName,
                                          paymentMethod: _paymentMethod,
                                          tenderedAmount:
                                              _paymentMethod == 'cash'
                                                  ? _tenderedAmount
                                                  : 0.0,
                                          change: changeAmount,
                                        );

                                        if (!context.mounted) return;

                                        cart.clear();

                                        Navigator.pushNamedAndRemoveUntil(
                                            context, '/pos', (route) => false);
                                      } catch (e) {
                                        if (!context.mounted) return;

                                        final errorMsg = e
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('network') ||
                                                e
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('internet') ||
                                                e
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('connect') ||
                                                e
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('timeout') ||
                                                e
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('unavailable')
                                            ? 'No internet connection. Please check your connection and try again.'
                                            : 'Error: $e';

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(errorMsg)),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                              label: Text(
                                _isSubmitting
                                    ? 'Placing Order...'
                                    : 'Place Order',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cart.items.isEmpty ||
                                        (_paymentMethod == 'cash' &&
                                            _tenderedAmount < cart.total) ||
                                        _isSubmitting
                                    ? Colors.white12
                                    : Colors.white24,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: cart.items.isEmpty
                                        ? Colors.white12
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
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
    });
  }
}
