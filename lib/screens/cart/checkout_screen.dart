// lib/screens/pos/checkout_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/order_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';
import 'product_list_bottom_sheet.dart';

// ─── Helpers ───────────────────────────────────────────────────────────────────

/// Pure utility — moved out of screen state so it can be shared if needed.
String itemEmoji(String name) {
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

Color itemBgColor(String name) {
  const colors = [
    NovaColors.violetLight,
    NovaColors.tealLight,
    NovaColors.amberLight,
    Color(0xFFFFEEF3),
    Color(0xFFE8F4FD),
  ];
  return colors[name.codeUnitAt(0) % colors.length];
}

// ─── Screen ────────────────────────────────────────────────────────────────────

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

  // FIX: final instead of late + assignment; add controller for programmatic updates
  final FocusNode _cashFocus = FocusNode();
  final TextEditingController _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cashFocus.addListener(_onCashFocusChange);
  }

  void _onCashFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cashFocus.removeListener(_onCashFocusChange);
    _cashFocus.dispose();
    _cashController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: NovaColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: NovaColors.textTertiary, size: 16)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: NovaColors.borderTertiary, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NovaColors.violet, width: 1.5),
      ),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    // FIX: create controller before showDialog, not inside builder
    final qtyController = TextEditingController(
      text: ((item['qty'] as num?)?.toInt() ?? 1).toString(),
    );

    await showDialog<bool?>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      child: const Icon(Icons.edit_rounded,
                          color: NovaColors.violet, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit ${item['name']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.textPrimary,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary),
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
                        onPressed: () {
                          // FIX: read from controller directly, not closure variable
                          final newQty =
                              int.tryParse(qtyController.text.trim());
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
                          backgroundColor: NovaColors.violet,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save',
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
        );
      },
    );

    qtyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (context, auth, child) {
      if (!auth.isAdmin && !auth.isCashier) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/pos');
        });
        return const Scaffold(
            backgroundColor: NovaColors.bgTertiary,
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)));
      }

      final userEmail = auth.user?.email ?? 'No Email';
      final userName = auth.user?.displayName ?? userEmail.split('@').first;
      final photoUrl = auth.user?.photoURL;

      return Scaffold(
        backgroundColor: NovaColors.bgTertiary,
        drawer: AppNavigationShell.isDesktop(context)
            ? null
            : AppNavigationDrawer(auth: auth, currentRoute: '/checkout'),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: NovaColors.bgPrimary,
            child: SafeArea(
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: NovaColors.textSecondary),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: NovaColors.textSecondary, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        color: NovaColors.violet, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Checkout',
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
                  child:
                      Container(height: 0.5, color: NovaColors.borderTertiary),
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
        // FIX: wrap entire body in CheckoutKeyboardScope so physical numpad works
        body: CheckoutKeyboardScope(
          cashController: _cashController,
          onCashChanged: (value) {
            setState(() => _tenderedAmount = double.tryParse(value) ?? 0.0);
          },
          onBack: () => Navigator.pop(context),
          child: AppNavigationShell(
            auth: auth,
            currentRoute: '/checkout',
            child: Consumer<CartProvider>(
              builder: (context, cart, child) {
                final keyboardOpen =
                    MediaQuery.of(context).viewInsets.bottom > 0;
                final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

                // ── Order Details panel ───────────────────────────────────
                final topForm = Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: NovaColors.borderTertiary, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: const BoxDecoration(
                          color: NovaColors.bgSecondary,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: NovaColors.violetLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long_outlined,
                                  color: NovaColors.violet, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Order Details',
                              style: TextStyle(
                                color: NovaColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            14, 14, 14, keyboardOpen ? 8 : 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _orderType,
                                    decoration: _fieldDecoration('Order Type',
                                        icon: Icons.storefront_outlined),
                                    dropdownColor: NovaColors.bgPrimary,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: NovaColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'takeaway',
                                        child: Text('🛍️  Takeaway',
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      DropdownMenuItem(
                                        value: 'dine_in',
                                        child: Text('🍽️  Dine In',
                                            overflow: TextOverflow.ellipsis),
                                      ),
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
                                      isExpanded: true,
                                      value: _tableNumber,
                                      decoration: _fieldDecoration('Table',
                                          icon: Icons.table_bar_outlined),
                                      dropdownColor: NovaColors.bgPrimary,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NovaColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      hint: const Text('Select',
                                          style: TextStyle(
                                              color: NovaColors.textTertiary,
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) => _customerName = value,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: NovaColors.textPrimary,
                                        fontWeight: FontWeight.w500),
                                    decoration: _fieldDecoration(
                                        'Customer Name',
                                        icon: Icons.person_outline_rounded),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _paymentMethod,
                                    decoration: _fieldDecoration('Payment',
                                        icon: Icons.payment_outlined),
                                    dropdownColor: NovaColors.bgPrimary,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: NovaColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'cash',
                                        child: Text('💵  Cash',
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      DropdownMenuItem(
                                        value: 'card',
                                        child: Text('💳  Card',
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _paymentMethod = value ?? 'cash';
                                        if (value != 'cash') {
                                          // FIX: clear controller when switching away from cash
                                          _cashController.clear();
                                          _tenderedAmount = 0.0;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_paymentMethod == 'cash') ...[
                              const SizedBox(height: 10),
                              // FIX: use _cashController so physical numpad + on-screen both work
                              TextField(
                                focusNode: _cashFocus,
                                controller: _cashController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (value) => setState(() {
                                  _tenderedAmount =
                                      double.tryParse(value) ?? 0.0;
                                }),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: NovaColors.textPrimary,
                                    fontWeight: FontWeight.w500),
                                decoration: _fieldDecoration('Cash Tendered',
                                        icon: Icons.money_rounded)
                                    .copyWith(
                                  prefixText: 'Rs  ',
                                  prefixStyle: const TextStyle(
                                      color: NovaColors.textSecondary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              // FIX: show warning based on amount, not just focus state
                              if (_tenderedAmount > 0 &&
                                  _tenderedAmount < cart.total)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: NovaColors.danger, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Amount is less than total',
                                        style: TextStyle(
                                            color: NovaColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (_tenderedAmount >= cart.total)
                                      ? NovaColors.tealLight
                                      : NovaColors.dangerLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (_tenderedAmount >= cart.total)
                                        ? NovaColors.teal.withValues(alpha: 0.3)
                                        : NovaColors.danger
                                            .withValues(alpha: 0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.change_circle_outlined,
                                          size: 15,
                                          color: (_tenderedAmount >= cart.total)
                                              ? NovaColors.teal
                                              : NovaColors.danger,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Change Due',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: NovaColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Rs ${(_tenderedAmount - cart.total).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: (_tenderedAmount >= cart.total)
                                            ? NovaColors.teal
                                            : NovaColors.danger,
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

                // ── Cart items panel ──────────────────────────────────────
                final cartSection = Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: NovaColors.borderTertiary, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: const BoxDecoration(
                          color: NovaColors.bgSecondary,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: NovaColors.violetLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_cart_outlined,
                                  color: NovaColors.violet, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Cart Items',
                              style: TextStyle(
                                color: NovaColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (cart.items.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: NovaColors.violetLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${cart.items.length} item${cart.items.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: NovaColors.violet,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (cart.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: NovaColors.bgSecondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: NovaColors.borderTertiary,
                                        width: 0.5),
                                  ),
                                  child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 32,
                                      color: NovaColors.textTertiary),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Cart is empty',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: NovaColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add products from the menu',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: NovaColors.textTertiary),
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
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          separatorBuilder: (_, __) => const Divider(
                            color: NovaColors.borderTertiary,
                            height: 1,
                            thickness: 0.5,
                          ),
                          itemBuilder: (context, i) {
                            final item = cart.items[i];
                            final cartDocId =
                                item['cartDocId'] as String? ?? '';
                            final price = ((item['unitPrice'] ?? item['price'])
                                    as num?) ??
                                0;
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
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: itemBgColor(name),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        itemEmoji(name),
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: NovaColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: NovaColors.violetLight,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                '×$qty',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: NovaColors.violet,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Rs ${price.toStringAsFixed(0)} each',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      NovaColors.textTertiary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 72),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Rs ${lineTotal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: NovaColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded,
                                        color: NovaColors.textTertiary,
                                        size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 32),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
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
                                        _showEditItemDialog(
                                            context, cart, item);
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
                                              color: NovaColors.violet,
                                              size: 16),
                                          SizedBox(width: 10),
                                          Text('Add More',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500)),
                                        ]),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(children: [
                                          Icon(Icons.edit_outlined,
                                              color: NovaColors.amber,
                                              size: 16),
                                          SizedBox(width: 10),
                                          Text('Edit Qty',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500)),
                                        ]),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        enabled: cartDocId.isNotEmpty,
                                        child: const Row(children: [
                                          Icon(Icons.delete_outline,
                                              color: NovaColors.danger,
                                              size: 16),
                                          SizedBox(width: 10),
                                          Text('Remove',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: NovaColors.danger)),
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

                return ResponsiveCenter(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >=
                                ResponsiveLayout.desktopBreakpoint;

                            return ListView(
                              padding: EdgeInsets.only(
                                bottom: keyboardOpen ? keyboardInset + 12 : 12,
                              ),
                              children: [
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: topForm),
                                      const SizedBox(width: 8),
                                      Expanded(child: cartSection),
                                    ],
                                  )
                                else ...[
                                  topForm,
                                  cartSection,
                                ],
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                      ),

                      // ── Bottom bar ────────────────────────────────────
                      if (!keyboardOpen)
                        Container(
                          decoration: const BoxDecoration(
                            color: NovaColors.bgPrimary,
                            border: Border(
                              top: BorderSide(
                                  color: NovaColors.borderTertiary, width: 0.5),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: NovaColors.textTertiary),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Rs ${cart.total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: NovaColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 44,
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
                                                    ? _tenderedAmount -
                                                        cart.total
                                                    : 0.0;

                                            setState(
                                                () => _isSubmitting = true);

                                            try {
                                              final cartSnapshot =
                                                  cart.items.map((item) {
                                                final qty = (item['qty']
                                                            as num?)
                                                        ?.toInt() ??
                                                    (item['quantity'] as num?)
                                                        ?.toInt() ??
                                                    1;
                                                final price =
                                                    (item['price'] as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                return <String, dynamic>{
                                                  'name':
                                                      item['name'] ?? 'Unknown',
                                                  'qty': qty,
                                                  'quantity': qty,
                                                  'price': price,
                                                  'unitPrice': price,
                                                  'lineTotal': price * qty,
                                                  if (item['productId'] != null)
                                                    'productId':
                                                        item['productId'],
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

                                              if (!mounted) return;

                                              cart.clear();
                                              Navigator.pushNamedAndRemoveUntil(
                                                  context,
                                                  '/pos',
                                                  (route) => false);
                                            } catch (e) {
                                              if (!mounted) return;

                                              final errorMsg = e
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(
                                                              'network') ||
                                                      e
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(
                                                              'internet') ||
                                                      e
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(
                                                              'connect') ||
                                                      e
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(
                                                              'timeout') ||
                                                      e
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(
                                                              'unavailable')
                                                  ? 'No internet connection. Please check your connection and try again.'
                                                  : 'Error: $e';

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(errorMsg)),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() =>
                                                    _isSubmitting = false);
                                              }
                                            }
                                          },
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded,
                                            color: Colors.white, size: 16),
                                    label: Text(
                                      _isSubmitting
                                          ? 'Placing Order...'
                                          : 'Place Order',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cart.items.isEmpty ||
                                              (_paymentMethod == 'cash' &&
                                                  _tenderedAmount <
                                                      cart.total) ||
                                              _isSubmitting
                                          ? NovaColors.bgSecondary
                                          : NovaColors.violet,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    });
  }
}
