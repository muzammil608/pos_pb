// ignore_for_file: use_super_parameters

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/clickable_cursor.dart';
import '../../models/pos_header_slide_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pos_header_service.dart';
import '../../services/printer/thermal_printer_service.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/inventory_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/responsive_layout.dart';
import '../cart/product_list_bottom_sheet.dart';

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

bool _cashIsInsufficient(double tendered, double total) {
  return tendered.round() < total.round();
}

class _CartActionOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;

  const _CartActionOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.enabled = true,
  });
}

class _EditQuantityDialog extends StatefulWidget {
  final String itemName;
  final int initialQty;
  final InputDecoration fieldDecoration;

  const _EditQuantityDialog({
    required this.itemName,
    required this.initialQty,
    required this.fieldDecoration,
  });

  @override
  State<_EditQuantityDialog> createState() => _EditQuantityDialogState();
}

class _EditQuantityDialogState extends State<_EditQuantityDialog> {
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.initialQty.toString(),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _save() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid quantity greater than 0.'),
        ),
      );
      return;
    }
    Navigator.pop(context, qty);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: NovaColors.bgPrimary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 330;
            final cancelButton = OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: NovaColors.borderSecondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: NovaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
            final saveButton = ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.violet,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.all(compact ? 16 : 24),
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
                        child: const Icon(
                          Icons.edit_rounded,
                          color: NovaColors.violet,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit ${widget.itemName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary,
                    ),
                    decoration: widget.fieldDecoration,
                  ),
                  const SizedBox(height: 18),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: cancelButton),
                        const SizedBox(width: 10),
                        Expanded(child: saveButton),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CartActionTile extends StatelessWidget {
  final _CartActionOption action;
  final bool selected;
  final VoidCallback? onTap;

  const _CartActionTile({
    required this.action,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = action.enabled ? action.color : NovaColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? NovaColors.violetLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? NovaColors.violet : NovaColors.borderSecondary,
            ),
          ),
          child: Row(
            children: [
              Icon(action.icon, color: foreground, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: action.enabled
                        ? NovaColors.textPrimary
                        : NovaColors.textTertiary,
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

class _CartItemActionsDialog extends StatefulWidget {
  final String itemName;
  final List<_CartActionOption> actions;
  final GlobalKey? anchorKey;

  const _CartItemActionsDialog({
    required this.itemName,
    required this.actions,
    this.anchorKey,
  });

  @override
  State<_CartItemActionsDialog> createState() => _CartItemActionsDialogState();
}

class _CartItemActionsDialogState extends State<_CartItemActionsDialog> {
  late final FocusNode _focusNode;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'CartItemActionsDialog');
    _selectedIndex = widget.actions.indexWhere((a) => a.enabled);
    if (_selectedIndex < 0) _selectedIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    if (widget.actions.isEmpty) return;
    var next = _selectedIndex;
    for (var i = 0; i < widget.actions.length; i++) {
      next = (next + delta) % widget.actions.length;
      if (next < 0) next = widget.actions.length - 1;
      if (widget.actions[next].enabled) {
        setState(() => _selectedIndex = next);
        return;
      }
    }
  }

  void _submitSelection() {
    if (widget.actions.isEmpty) return;
    final action = widget.actions[_selectedIndex];
    if (!action.enabled) return;
    Navigator.of(context, rootNavigator: false).pop(action.value);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _submitSelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context, rootNavigator: false).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const menuWidth = 320.0;
    const horizontalMargin = 12.0;
    const verticalMargin = 12.0;

    double left = (media.size.width - menuWidth) / 2;
    double top = media.size.height * 0.3;

    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    final anchorBox =
        widget.anchorKey?.currentContext?.findRenderObject() as RenderBox?;

    if (overlay != null && anchorBox != null) {
      final anchorTopLeft =
          anchorBox.localToGlobal(Offset.zero, ancestor: overlay);
      final anchorBottomRight = anchorBox.localToGlobal(
        anchorBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );

      left = (anchorBottomRight.dx - menuWidth).clamp(
        horizontalMargin,
        media.size.width - menuWidth - horizontalMargin,
      );
      top = (anchorBottomRight.dy + 6).clamp(
        verticalMargin,
        media.size.height - 240,
      );
      if (top > media.size.height - 220) {
        top = (anchorTopLeft.dy - 196).clamp(
          verticalMargin,
          media.size.height - 220,
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context, rootNavigator: false).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: menuWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NovaColors.borderSecondary),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: NovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use arrow keys and Enter',
                        style: TextStyle(
                          fontSize: 12,
                          color: NovaColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < widget.actions.length; i++)
                        _CartActionTile(
                          action: widget.actions[i],
                          selected: i == _selectedIndex,
                          onTap: widget.actions[i].enabled
                              ? () =>
                                  Navigator.of(context, rootNavigator: false)
                                      .pop(widget.actions[i].value)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  InventoryService? _inventoryService;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final FocusNode _cashFocusNode = FocusNode(debugLabel: 'PosCashTendered');
  final FocusNode _checkoutShortcutFocusNode =
      FocusNode(debugLabel: 'PosCheckoutShortcuts');
  final ScrollController _productScrollController = ScrollController();
  final GlobalKey<PosSearchBarState> _searchBarKey =
      GlobalKey<PosSearchBarState>();
  final GlobalKey<PosCategoryChipsState> _categoryChipsKey =
      GlobalKey<PosCategoryChipsState>();
  final Map<String, GlobalKey> _cartItemKeys = {};
  final Map<String, GlobalKey> _cartItemMenuKeys = {};
  final Map<int, GlobalKey> _productItemKeys = {};

  late AnimationController _pulseController;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _customerName = '';
  String _paymentMethod = 'cash';
  final String _orderType = 'dine_in';

  int _focusedProductIndex = -1;
  List<Product> _lastFilteredProducts = [];
  int _focusedCartIndex = 0;

  double _tenderedAmount = 0.0;
  bool _isSubmitting = false;
  bool _actionsDialogOpen = false;
  bool _productSheetOpen = false;
  bool _checkoutKeyboardMode = false;

  bool _readyOrdersSheetOpen = false;

  String _normalizeSearch(String value) => value.toLowerCase().trim();

  int _matchScore(Product product, String normalizedQuery) {
    final name = product.name.toLowerCase();
    final category = product.category.toLowerCase();
    final barcode = product.barcode.toLowerCase();

    if (barcode.isNotEmpty && barcode == normalizedQuery) return -1;
    if (name == normalizedQuery) return 0;
    if (name.startsWith(normalizedQuery)) return 1;
    if (name.contains(' $normalizedQuery')) return 2;
    if (category == normalizedQuery) return 3;
    if (category.startsWith(normalizedQuery)) return 4;
    if (name.contains(normalizedQuery)) return 5;
    if (category.contains(normalizedQuery)) return 6;
    return 99;
  }

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
        if (mounted) _startNewOrder();
      },
      onF2Cart: () {
        if (!mounted) return;
        _showReadyOrdersSheet(context);
      },
      onF3HoldOrder: () {
        if (mounted) _clearCurrentOrderWithUndo();
      },
      onF4AddCustomer: () {
        if (mounted) _openProducts();
      },
      onF5Refresh: () {
        if (mounted) setState(() {});
      },
      onF6Inventory: () {
        if (mounted) _openInventory();
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
      _inventoryService = InventoryService(auth.ownerId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _cashController.dispose();
    _cashFocusNode.dispose();
    _checkoutShortcutFocusNode.dispose();
    _productScrollController.dispose();
    _pulseController.dispose();
    _posHeaderService?.dispose();
    PosHotkeyRegistry.unregisterAll();
    super.dispose();
  }

  void _onArrowDown() {
    if (_isCheckoutKeyboardActive) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
        return;
      }
      _moveFocusedCartItem(cart, 1);
      return;
    }

    if (_lastFilteredProducts.isEmpty) return;
    _setFocusedProductIndex(
      (_focusedProductIndex + 1).clamp(0, _lastFilteredProducts.length - 1),
    );
  }

  void _onArrowUp() {
    if (_isCheckoutKeyboardActive) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
        return;
      }
      _moveFocusedCartItem(cart, -1);
      return;
    }

    if (_lastFilteredProducts.isEmpty) return;
    _setFocusedProductIndex(
      (_focusedProductIndex - 1).clamp(0, _lastFilteredProducts.length - 1),
    );
  }

  void _onArrowRight() {
    _categoryChipsKey.currentState?.nextCategory();
  }

  void _onArrowLeft() {
    _categoryChipsKey.currentState?.prevCategory();
  }

  void _onConfirmFocusedItem() {
    if (_isCheckoutKeyboardActive) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      _placeOrder(context, cart).then((success) {
        if (!mounted || !success) return;
        _focusPosForNewOrder();
      });
      return;
    }

    if (_focusedProductIndex < 0 ||
        _focusedProductIndex >= _lastFilteredProducts.length) {
      return;
    }
    final product = _lastFilteredProducts[_focusedProductIndex];
    _addProductWithQtyDialog(product);
  }

  void _onDeleteFocusedItem() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _deleteFocusedCartItem(cart);
  }

  void _onEditFocusedItem() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _showCartItemActions(context, cart, cart.items[_safeCartIndex(cart)]);
  }

  void _setFocusedProductIndex(int index) {
    if (!mounted) return;
    setState(() {
      _focusedProductIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedProductIntoView(index);
    });
  }

  void _scrollFocusedProductIntoView([int? index]) {
    final focusedIndex = index ?? _focusedProductIndex;
    final context = _productItemKeys[focusedIndex]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.18,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUndoCart() {
    final stack = CartUndoStack.instance;
    if (stack.canUndo) {
      final description = stack.lastDescription ?? 'last action';
      stack.undo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undone: $description'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onCheckout() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _focusCheckoutForOrder(cart);
  }

  void _onClearCart() {
    _clearCurrentOrderWithUndo();
    _resetCheckoutForm();
  }

  void _clearCurrentOrderWithUndo() {
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

  void _startNewOrder() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isNotEmpty) {
      _clearCurrentOrderWithUndo();
    }
    _searchBarKey.currentState?.clear();
    _searchBarKey.currentState?.requestFocus();
    _resetCheckoutForm();
  }

  void _resetCheckoutForm() {
    _customerName = '';
    _customerNameController.clear();
    _paymentMethod = 'cash';
    _tenderedAmount = 0.0;
    _cashController.clear();
    _focusedCartIndex = 0;
    _actionsDialogOpen = false;
    _checkoutKeyboardMode = false;
  }

  void _focusCheckoutForOrder(CartProvider cart) {
    if (cart.items.isEmpty) return;
    setState(() {
      _focusedCartIndex = cart.items.length - 1;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cashFocusNode.requestFocus();
    });
  }

  void _focusPosForNewOrder() {
    if (_checkoutKeyboardMode) {
      setState(() => _checkoutKeyboardMode = false);
    }
    _cashFocusNode.unfocus();
    _checkoutShortcutFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchBarKey.currentState?.clear();
      _searchBarKey.currentState?.requestFocus();
    });
  }

  void _openProducts() {
    Navigator.pushNamed(context, '/products');
  }

  void _openInventory() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory is available for admins.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pushNamed(context, '/inventory');
  }

  Future<void> _addProductWithQtyDialog(Product product) async {
    final qty = await _showQtyDialog(context, product.name, product.price);
    if (qty != null && qty > 0 && mounted) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final productMap = product.toMap();
      productMap['id'] = product.id;
      productMap['qty'] = qty;
      await cart.addItem(productMap);

      CartUndoStack.instance.push('Add ${product.name}', () {
        final addedItem = cart.items.lastWhere(
          (item) => item['productId'] == product.id,
          orElse: () => const <String, dynamic>{},
        );
        final cartDocId = addedItem['cartDocId']?.toString();
        if (cartDocId != null && cartDocId.isNotEmpty) {
          cart.removeItem(cartDocId);
        }
      });
    }
  }

  int _safeCartIndex(CartProvider cart) {
    if (cart.items.isEmpty) return 0;
    return _focusedCartIndex.clamp(0, cart.items.length - 1);
  }

  bool get _isCheckoutKeyboardActive =>
      _checkoutKeyboardMode ||
      _checkoutShortcutFocusNode.hasFocus ||
      _cashFocusNode.hasFocus;

  void _moveFocusedCartItem(CartProvider cart, int direction) {
    if (cart.items.isEmpty) {
      _focusPosForNewOrder();
      return;
    }
    final next = (_safeCartIndex(cart) + direction).clamp(
      0,
      cart.items.length - 1,
    );
    setState(() {
      _focusedCartIndex = next;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkoutShortcutFocusNode.requestFocus();
    });
  }

  void _selectCartItem(int index) {
    setState(() {
      _focusedCartIndex = index;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkoutShortcutFocusNode.requestFocus();
    });
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

  void _selectPaymentMethod(String method) {
    if (method != 'cash' && method != 'card') return;

    setState(() {
      _checkoutKeyboardMode = true;
      _paymentMethod = method;
      if (method != 'cash') {
        _cashController.clear();
        _tenderedAmount = 0.0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (method == 'cash') {
        _cashFocusNode.requestFocus();
      } else {
        _checkoutShortcutFocusNode.requestFocus();
      }
    });
  }

  Future<void> _showEditItemDialog(
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    final newQty = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => _EditQuantityDialog(
        itemName: item['name']?.toString() ?? 'Item',
        initialQty: (item['qty'] as num?)?.toInt() ?? 1,
        fieldDecoration: _fieldDecoration(
          'Quantity',
          icon: Icons.format_list_numbered,
        ),
      ),
    );

    if (newQty != null && newQty > 0) {
      await cart.updateItemQuantity(item['cartDocId'] as String, newQty);
    }
  }

  Future<void> _deleteCartItem(
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    final cartDocId = item['cartDocId'] as String? ?? '';
    if (cartDocId.isEmpty) return;

    CartUndoStack.instance.push('Remove ${item['name'] ?? 'item'}', () {
      cart.addItem(item);
    });
    await cart.removeItem(cartDocId);
  }

  Future<void> _deleteFocusedCartItem(CartProvider cart) async {
    if (cart.items.isEmpty) return;
    await _deleteCartItem(cart, cart.items[_safeCartIndex(cart)]);
    if (!mounted) return;
    if (cart.items.isEmpty) {
      _focusPosForNewOrder();
    }
  }

  Future<void> _openProductBottomSheet(BuildContext context) async {
    if (_productSheetOpen) return;
    _productSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final size = MediaQuery.of(sheetContext).size;
          final isWide = size.width >= 900;
          final panelWidth = isWide ? size.width / 3 : size.width;
          final panelHeight = size.height * 0.82;

          return Align(
            alignment: Alignment.bottomRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isWide ? 360 : 0,
                maxWidth: isWide
                    ? panelWidth.clamp(360.0, 560.0).toDouble()
                    : panelWidth,
                maxHeight: panelHeight,
              ),
              child: const ProductListBottomSheet(),
            ),
          );
        },
      );
    } finally {
      _productSheetOpen = false;
      if (mounted) {
        _checkoutShortcutFocusNode.requestFocus();
      }
    }
  }

  Future<void> _showCartItemActions(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    if (_actionsDialogOpen) return;
    _actionsDialogOpen = true;

    final cartDocId = item['cartDocId'] as String? ?? '';
    final menuKey = _cartItemMenuKeys[cartDocId];
    final actions = [
      const _CartActionOption(
        value: 'add',
        label: 'Add More',
        icon: Icons.add_circle_outline,
        color: NovaColors.violet,
      ),
      const _CartActionOption(
        value: 'edit',
        label: 'Edit Qty',
        icon: Icons.edit_outlined,
        color: NovaColors.amber,
      ),
      _CartActionOption(
        value: 'delete',
        label: 'Remove',
        icon: Icons.delete_outline,
        color: NovaColors.danger,
        enabled: cartDocId.isNotEmpty,
      ),
    ];

    String? value;
    try {
      value = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cart actions',
        barrierColor: Colors.black12,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (dialogContext, _, __) => _CartItemActionsDialog(
          itemName: item['name']?.toString() ?? 'Item',
          actions: actions,
          anchorKey: menuKey,
        ),
      );
    } finally {
      _actionsDialogOpen = false;
    }

    if (!mounted || !context.mounted || value == null) return;
    if (value == 'add') {
      await _openProductBottomSheet(context);
    } else if (value == 'edit') {
      await _showEditItemDialog(cart, item);
    } else if (value == 'delete') {
      await _deleteCartItem(cart, item);
      if (!mounted) return;
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
      }
    }
  }

  Future<String?> _validateStockBeforePlace(
    List<Map<String, dynamic>> cartSnapshot,
  ) async {
    final issues = <String>[];

    for (final item in cartSnapshot) {
      final productId = item['productId']?.toString() ?? '';
      final name = item['name']?.toString() ?? 'Item';
      final requestedQty = (item['qty'] as num?)?.toInt() ??
          (item['quantity'] as num?)?.toInt() ??
          1;

      if (productId.isEmpty) {
        issues.add('$name: product mapping missing');
        continue;
      }

      try {
        final product = await _inventoryService!.getProduct(productId);
        final available = product.stockQty;
        if (available <= 0) {
          issues.add('$name is out of stock');
        } else if (requestedQty > available) {
          issues.add(
              '$name has only $available in stock (requested $requestedQty)');
        }
      } catch (_) {
        issues.add('Could not verify stock for $name');
      }
    }

    if (issues.isEmpty) return null;
    return 'Cannot place order:\n${issues.join('\n')}';
  }

  Future<bool> _placeOrder(BuildContext context, CartProvider cart) async {
    if (cart.items.isEmpty) return false;
    if (_paymentMethod == 'cash' &&
        _cashIsInsufficient(_tenderedAmount, cart.total)) {
      return false;
    }
    if (_isSubmitting) return false;

    final messenger = ScaffoldMessenger.of(context);
    final changeAmount =
        _paymentMethod == 'cash' ? _tenderedAmount - cart.total : 0.0;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isSubmitting = true);

    try {
      final cartSnapshot = cart.items.map((item) {
        final qty = (item['qty'] as num?)?.toInt() ??
            (item['quantity'] as num?)?.toInt() ??
            1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        return <String, dynamic>{
          'name': item['name'] ?? 'Unknown',
          'qty': qty,
          'quantity': qty,
          'price': price,
          'unitPrice': price,
          'lineTotal': price * qty,
          if (item['productId'] != null) 'productId': item['productId'],
        };
      }).toList();

      final stockIssueMessage = await _validateStockBeforePlace(cartSnapshot);
      if (stockIssueMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(stockIssueMessage),
            duration: const Duration(seconds: 4),
          ),
        );
        return false;
      }

      final order = await _orderService!.createOrder(
        items: cartSnapshot,
        total: cart.total,
        status: 'ready',
        orderType: _orderType,
        customerName: _customerName,
        paymentMethod: _paymentMethod,
        tenderedAmount: _paymentMethod == 'cash' ? _tenderedAmount : 0.0,
        change: changeAmount,
      );
      if (!mounted) return false;

      await ThermalPrinterService.instance.printReceiptAuto(
        ThermalReceiptData(
          companyName: 'Orion POS',
          phone: '+92-317-7921817',
          email: 'info@orion.com',
          website: 'www.orion.com',
          servedBy: auth.role,
          customerName: _customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : _customerName.trim(),
          orderType: _orderType,
          items: order.items,
          total: order.total,
          cash: order.tenderedAmount,
          change: order.change,
          tax: 0.0,
          paymentMethod: order.paymentMethod ?? _paymentMethod,
          orderNo: 'ORDER-${order.orderNumber}',
          date:
              '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} '
              '${order.createdAt.hour.toString().padLeft(2, '0')}:'
              '${order.createdAt.minute.toString().padLeft(2, '0')}',
        ),
      );

      await cart.clear();
      _resetCheckoutForm();
      messenger.showSnackBar(
        const SnackBar(content: Text('Order placed successfully.')),
      );
      _focusPosForNewOrder();
      return true;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase().contains('network') ||
              e.toString().toLowerCase().contains('internet') ||
              e.toString().toLowerCase().contains('connect') ||
              e.toString().toLowerCase().contains('timeout') ||
              e.toString().toLowerCase().contains('unavailable')
          ? 'No internet connection. Please check your connection and try again.'
          : 'Error: $e';

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Product? _findProductByBarcode(List<Product> products, String rawCode) {
    final code = rawCode.trim().toLowerCase();
    if (code.isEmpty) return null;

    for (final product in products) {
      final barcode = product.barcode.trim().toLowerCase();
      final id = product.id.trim().toLowerCase();
      if ((barcode.isNotEmpty && barcode == code) || id == code) {
        return product;
      }
    }
    return null;
  }

  Future<void> _addScannedProduct(Product product) async {
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);
    final productMap = product.toMap()
      ..['id'] = product.id
      ..['qty'] = 1;

    await cart.addItem(productMap);

    CartUndoStack.instance.push('Scan ${product.name}', () {
      final addedItem = cart.items.lastWhere(
        (item) => item['productId'] == product.id,
        orElse: () => const <String, dynamic>{},
      );
      final cartDocId = addedItem['cartDocId']?.toString();
      if (cartDocId != null && cartDocId.isNotEmpty) {
        cart.removeItem(cartDocId);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${product.name} - Rs ${product.price.toStringAsFixed(0)}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    _searchBarKey.currentState?.clear();
    _searchBarKey.currentState?.requestFocus();
  }

  Future<void> _handleSearchSubmitted(
    String value,
    List<Product> products,
  ) async {
    final product = _findProductByBarcode(products, value);
    if (product == null) return;
    await _addScannedProduct(product);
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
    final orderType = data['orderType']?.toString() ?? 'dine_in';
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
          appBar: AppNavigationAppBar(
            title: 'Order Station',
            icon: Icons.storefront_rounded,
            photoUrl: photoUrl,
            userName: userName,
            actions: [
              if (_isDesktop)
                IconButton(
                  tooltip: 'Keyboard Shortcuts (?)',
                  onPressed: () => PosShortcutHelp.show(context),
                  icon: const Icon(Icons.keyboard_rounded,
                      color: Colors.white70, size: 20),
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
                                    color: NovaColors.bgPrimary, width: 1.5),
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
            ],
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/pos',
            child: PosKeyboardScope(
              searchBarKey: _searchBarKey,
              categoryChipsKey: _categoryChipsKey,
              onNewOrder: _startNewOrder,
              onCheckout: _onCheckout,
              onReadyOrders: () => _showReadyOrdersSheet(context),
              onProducts: _openProducts,
              onClearCart: _onClearCart,
              onDeleteFocusedItem: _onDeleteFocusedItem,
              onEditFocusedItem: _onEditFocusedItem,
              onUndoCart: _onUndoCart,
              onConfirmFocusedItem: _onConfirmFocusedItem,
              onArrowUp: _onArrowUp,
              onArrowDown: _onArrowDown,
              onArrowLeft: _onArrowLeft,
              onArrowRight: _onArrowRight,
              onRefresh: () => setState(() {}),
              onEscape: null,
              onSelectPaymentMethod: _selectPaymentMethod,
              onInventory: _openInventory,
              child: StreamBuilder<List<Product>>(
                stream: _productService?.streamProducts ??
                    Stream<List<Product>>.value([]),
                builder: (context, snapshot) {
                  final allProducts = snapshot.data ?? [];
                  final categories = _getCategories(allProducts);

                  final normalizedQuery = _normalizeSearch(_searchQuery);

                  final filteredProducts = allProducts.where((product) {
                    final name = product.name.toLowerCase();
                    final category = product.category.toLowerCase();
                    final barcode = product.barcode.toLowerCase();
                    final matchSearch = normalizedQuery.isEmpty ||
                        name.contains(normalizedQuery) ||
                        category.contains(normalizedQuery) ||
                        barcode.contains(normalizedQuery);
                    final matchCategory = _selectedCategory == 'All' ||
                        product.category == _selectedCategory;
                    return matchSearch && matchCategory;
                  }).toList();

                  if (normalizedQuery.isNotEmpty) {
                    filteredProducts.sort((a, b) {
                      final scoreCompare = _matchScore(a, normalizedQuery)
                          .compareTo(_matchScore(b, normalizedQuery));
                      if (scoreCompare != 0) return scoreCompare;
                      return a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          );
                    });
                  }

                  _lastFilteredProducts = filteredProducts;
                  if (_lastFilteredProducts.isEmpty) {
                    _focusedProductIndex = -1;
                  } else if (_focusedProductIndex < 0 ||
                      _focusedProductIndex >= _lastFilteredProducts.length) {
                    _focusedProductIndex = 0;
                  }

                  return LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final isDesktop = viewportConstraints.maxWidth >=
                          ResponsiveLayout.desktopBreakpoint;

                      Widget buildProductArea({
                        required EdgeInsets searchPadding,
                        required EdgeInsets chipPadding,
                        required EdgeInsets listPadding,
                        required bool includeFooter,
                      }) {
                        Widget buildProductList() {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: NovaColors.violet),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Error loading products',
                                style: TextStyle(
                                  color: NovaColors.textSecondary,
                                ),
                              ),
                            );
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
                                        color: NovaColors.borderTertiary,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.coffee_maker_outlined,
                                      size: 40,
                                      color: NovaColors.textTertiary,
                                    ),
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
                                  controller: _productScrollController,
                                  padding: listPadding,
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, index) {
                                    final product = filteredProducts[index];
                                    final isFocused =
                                        _focusedProductIndex == index;
                                    return _ProductListTile(
                                      key: _productItemKeys.putIfAbsent(
                                        index,
                                        GlobalKey.new,
                                      ),
                                      product: product,
                                      isFocused: isFocused,
                                      onTap: () =>
                                          _addProductWithQtyDialog(product),
                                    );
                                  },
                                );
                              }

                              return GridView.builder(
                                controller: _productScrollController,
                                padding: listPadding,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      _crossAxisCount(constraints.maxWidth),
                                  childAspectRatio:
                                      constraints.maxWidth < 380 ? 1.35 : 0.78,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (_, index) {
                                  final product = filteredProducts[index];
                                  final isFocused =
                                      _focusedProductIndex == index;
                                  return _ProductCard(
                                    key: _productItemKeys.putIfAbsent(
                                      index,
                                      GlobalKey.new,
                                    ),
                                    product: product,
                                    isFocused: isFocused,
                                    onTap: () =>
                                        _addProductWithQtyDialog(product),
                                  );
                                },
                              );
                            },
                          );
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: searchPadding,
                              child: PosSearchBar(
                                key: _searchBarKey,
                                controller: _searchController,
                                onChanged: (v) {
                                  setState(() {
                                    _searchQuery = v;
                                  });
                                  _setFocusedProductIndex(0);
                                },
                                onSubmitted: (v) =>
                                    _handleSearchSubmitted(v, allProducts),
                                onClear: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                  _focusedProductIndex = -1;
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (allProducts.isNotEmpty)
                              Padding(
                                padding: chipPadding,
                                child: PosCategoryChips(
                                  key: _categoryChipsKey,
                                  categories: categories,
                                  selected: _selectedCategory,
                                  onSelected: (cat) {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                    _setFocusedProductIndex(0);
                                  },
                                ),
                              ),
                            if (_posHeaderService != null) ...[
                              const SizedBox(height: 10),
                              PosHeaderSlideshow(
                                service: _posHeaderService!,
                                canEdit: auth.isAdmin,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Expanded(child: buildProductList()),
                            if (includeFooter)
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
                                        width: 0.5,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 18,
                                        offset: const Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _BottomBarButton(
                                          onPressed: cart.items.isEmpty
                                              ? null
                                              : _onCheckout,
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
                                        child:
                                            StreamBuilder<OrderRecordSnapshot>(
                                          stream: _orderService?.getOrders(),
                                          builder: (context, snapshot) {
                                            final readyCount =
                                                _readyOrderCount(snapshot);
                                            return _BottomBarButton(
                                              onPressed: () =>
                                                  _showReadyOrdersSheet(
                                                      context),
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
                        );
                      }

                      Widget buildCheckoutPanel() {
                        final itemCount = cart.items.length;
                        final readyOrdersStream = _orderService?.getOrders();

                        return Focus(
                            focusNode: _checkoutShortcutFocusNode,
                            child: Container(
                              decoration: BoxDecoration(
                                color: NovaColors.bgPrimary,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: NovaColors.borderTertiary,
                                  width: 0.75,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: const BoxDecoration(
                                      color: NovaColors.bgSecondary,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: NovaColors.violetLight,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons
                                                .shopping_cart_checkout_rounded,
                                            color: NovaColors.violet,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            'Checkout',
                                            style: TextStyle(
                                              color: NovaColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (itemCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: NovaColors.violetLight,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '$itemCount item${itemCount == 1 ? '' : 's'}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: NovaColors.violet,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 14, 16, 0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: NovaColors.bgSecondary,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: NovaColors.borderTertiary,
                                          width: 0.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Order Details',
                                            style: TextStyle(
                                              color: NovaColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _customerNameController,
                                            onChanged: (value) => setState(
                                              () => _customerName = value,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: NovaColors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: _fieldDecoration(
                                              'Customer Name',
                                              icon:
                                                  Icons.person_outline_rounded,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _paymentMethod,
                                            decoration: _fieldDecoration(
                                              'Payment Method',
                                              icon: Icons.payment_outlined,
                                            ),
                                            dropdownColor: NovaColors.bgPrimary,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: NovaColors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'cash',
                                                child: Text('Cash'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'card',
                                                child: Text('Card'),
                                              ),
                                            ],
                                            onChanged: (value) =>
                                                _selectPaymentMethod(
                                              value ?? 'cash',
                                            ),
                                          ),
                                          if (_paymentMethod == 'cash') ...[
                                            const SizedBox(height: 10),
                                            TextField(
                                              focusNode: _cashFocusNode,
                                              controller: _cashController,
                                              textInputAction:
                                                  TextInputAction.done,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              onChanged: (value) =>
                                                  setState(() {
                                                _tenderedAmount =
                                                    double.tryParse(value) ??
                                                        0.0;
                                              }),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: _fieldDecoration(
                                                'Cash Tendered',
                                                icon: Icons.money_rounded,
                                              ).copyWith(
                                                prefixText: 'Rs  ',
                                                prefixStyle: const TextStyle(
                                                  color:
                                                      NovaColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (_tenderedAmount > 0 &&
                                                _cashIsInsufficient(
                                                  _tenderedAmount,
                                                  cart.total,
                                                ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                  top: 6,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: NovaColors.danger,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Amount is less than total',
                                                      style: TextStyle(
                                                        color:
                                                            NovaColors.danger,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: !_cashIsInsufficient(
                                                  _tenderedAmount,
                                                  cart.total,
                                                )
                                                    ? NovaColors.tealLight
                                                    : NovaColors.dangerLight,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: !_cashIsInsufficient(
                                                    _tenderedAmount,
                                                    cart.total,
                                                  )
                                                      ? NovaColors.teal
                                                          .withValues(
                                                          alpha: 0.3,
                                                        )
                                                      : NovaColors.danger
                                                          .withValues(
                                                              alpha: 0.2),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .change_circle_outlined,
                                                        size: 15,
                                                        color: !_cashIsInsufficient(
                                                                _tenderedAmount,
                                                                cart.total)
                                                            ? NovaColors.teal
                                                            : NovaColors.danger,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Text(
                                                        'Change Due',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
                                                          color: NovaColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    'Rs ${(_tenderedAmount - cart.total).toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                      color: !_cashIsInsufficient(
                                                              _tenderedAmount,
                                                              cart.total)
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
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: cart.items.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(18),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        NovaColors.bgSecondary,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: NovaColors
                                                          .borderTertiary,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.shopping_bag_outlined,
                                                    size: 34,
                                                    color:
                                                        NovaColors.textTertiary,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'No items in cart',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        NovaColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                  ),
                                                  child: Text(
                                                    'Add products from the left side to start checkout.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: NovaColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              12,
                                            ),
                                            itemCount: cart.items.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(
                                              height: 16,
                                              color: NovaColors.borderTertiary,
                                            ),
                                            itemBuilder: (context, index) {
                                              final item = cart.items[index];
                                              final cartDocId =
                                                  item['cartDocId']
                                                          as String? ??
                                                      '';
                                              final price =
                                                  ((item['unitPrice'] ??
                                                                  item['price'])
                                                              as num?)
                                                          ?.toDouble() ??
                                                      0.0;
                                              final qty = (item['qty'] as num?)
                                                      ?.toInt() ??
                                                  1;
                                              final lineTotal =
                                                  ((item['lineTotal']) as num?)
                                                          ?.toDouble() ??
                                                      price * qty;
                                              final name =
                                                  item['name']?.toString() ??
                                                      'Item';
                                              final isFocused =
                                                  index == _safeCartIndex(cart);
                                              final itemKey =
                                                  _cartItemKeys.putIfAbsent(
                                                cartDocId,
                                                GlobalKey.new,
                                              );
                                              final menuButtonKey =
                                                  _cartItemMenuKeys.putIfAbsent(
                                                cartDocId,
                                                GlobalKey.new,
                                              );

                                              return InkWell(
                                                key: itemKey,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                onTap: () =>
                                                    _selectCartItem(index),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 140,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: isFocused
                                                        ? NovaColors.violetLight
                                                        : NovaColors
                                                            .bgSecondary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                    border: Border.all(
                                                      color: isFocused
                                                          ? NovaColors.violet
                                                          : NovaColors
                                                              .borderTertiary,
                                                      width:
                                                          isFocused ? 1 : 0.5,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 42,
                                                        height: 42,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              itemBgColor(name),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            10,
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            itemEmoji(name),
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              name,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: NovaColors
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: isFocused
                                                                        ? NovaColors
                                                                            .bgPrimary
                                                                        : NovaColors
                                                                            .violetLight,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      5,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    '×$qty',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: NovaColors
                                                                          .violet,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 6),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Rs ${price.toStringAsFixed(0)} each',
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: NovaColors
                                                                          .textTertiary,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                          maxWidth: 72,
                                                        ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            'Rs ${lineTotal.toStringAsFixed(0)}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: NovaColors
                                                                  .textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        key: menuButtonKey,
                                                        icon: const Icon(
                                                          Icons
                                                              .more_vert_rounded,
                                                          color: NovaColors
                                                              .textTertiary,
                                                          size: 16,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () async {
                                                          _selectCartItem(
                                                              index);
                                                          await _showCartItemActions(
                                                            context,
                                                            cart,
                                                            item,
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: NovaColors.bgSecondary,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(18),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      16,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: NovaColors.textTertiary,
                                              ),
                                            ),
                                            Text(
                                              'Rs ${cart.total.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700,
                                                color: NovaColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _BottomBarButton(
                                                onPressed: cart.items.isEmpty ||
                                                        (_paymentMethod ==
                                                                'cash' &&
                                                            _cashIsInsufficient(
                                                                _tenderedAmount,
                                                                cart.total)) ||
                                                        _isSubmitting
                                                    ? null
                                                    : () => _placeOrder(
                                                          context,
                                                          cart,
                                                        ),
                                                icon: _isSubmitting
                                                    ? Icons
                                                        .hourglass_top_rounded
                                                    : Icons.send_rounded,
                                                label: _isSubmitting
                                                    ? 'Placing...'
                                                    : 'Place Order',
                                                badge: itemCount > 0
                                                    ? '$itemCount'
                                                    : null,
                                                isPrimary: true,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: StreamBuilder<
                                                  OrderRecordSnapshot>(
                                                stream: readyOrdersStream,
                                                builder: (context, snapshot) {
                                                  final readyCount =
                                                      _readyOrderCount(
                                                          snapshot);
                                                  return _BottomBarButton(
                                                    onPressed: () =>
                                                        _showReadyOrdersSheet(
                                                            context),
                                                    icon: Icons
                                                        .receipt_long_outlined,
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ));
                      }

                      if (isDesktop) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: buildProductArea(
                                  searchPadding: const EdgeInsets.fromLTRB(
                                    0,
                                    14,
                                    12,
                                    0,
                                  ),
                                  chipPadding: const EdgeInsets.only(right: 12),
                                  listPadding: const EdgeInsets.fromLTRB(
                                    0,
                                    4,
                                    12,
                                    0,
                                  ),
                                  includeFooter: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: buildCheckoutPanel(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ResponsiveCenter(
                        padding: EdgeInsets.zero,
                        child: buildProductArea(
                          searchPadding: const EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            0,
                          ),
                          chipPadding: EdgeInsets.zero,
                          listPadding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            12,
                          ),
                          includeFooter: true,
                        ),
                      );
                    },
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
                            (i) => ClickableCursor(
                              child: GestureDetector(
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
                            mouseCursor: SystemMouseCursors.click,
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
            mouseCursor: SystemMouseCursors.click,
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
        mouseCursor: SystemMouseCursors.click,
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
      child: CachedNetworkImage(
        imageUrl: _imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) {
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
        errorWidget: (context, url, error) {
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
    Key? key,
    required this.product,
    required this.onTap,
    this.isFocused = false,
  }) : super(key: key);

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
    return ClickableCursor(
      child: GestureDetector(
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: NovaColors.textPrimary,
                          height: 1.15,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isFocused;

  const _ProductCard({
    super.key,
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
    return ClickableCursor(
      child: GestureDetector(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageHeight = constraints.maxHeight * 0.75;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: _ProductImage(
                        product: widget.product,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: NovaColors.textPrimary,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NovaColors.violetLight,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      'Rs ${widget.product.price.toStringAsFixed(0)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: NovaColors.violet,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 23,
                                  height: 23,
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
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
  final List<Map<String, dynamic>> items;
  final double total;
  final int index;
  final VoidCallback onComplete;

  const _ReadyOrderCard({
    required this.orderLabel,
    required this.items,
    required this.total,
    required this.index,
    required this.onComplete,
  });

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
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: NovaColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order $orderLabel',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary,
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
