import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/product_service.dart';

class ProductListBottomSheet extends StatefulWidget {
  const ProductListBottomSheet({super.key});

  @override
  State<ProductListBottomSheet> createState() => _ProductListBottomSheetState();
}

class _ProductListBottomSheetState extends State<ProductListBottomSheet> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ProductListBottomSheet');
  final TextEditingController _searchController = TextEditingController();
  int _focusedIndex = 0;
  int _columns = 3;
  String _query = '';
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  Color _itemBgColor(String name) {
    const colors = [
      NovaColors.violetLight,
      NovaColors.tealLight,
      NovaColors.amberLight,
      Color(0xFFFFEEF3),
      Color(0xFFE8F4FD),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  int _columnCount(double width) {
    if (width < 340) return 2;
    if (width < 520) return 3;
    if (width < 860) return 4;
    return 5;
  }

  void _moveFocus(int delta) {
    if (_products.isEmpty) return;
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(0, _products.length - 1);
    });
  }

  void _addFocusedProduct(BuildContext context) {
    if (_products.isEmpty) return;
    _addProduct(context, _products[_focusedIndex]);
  }

  void _addProduct(BuildContext context, Product product) {
    context.read<CartProvider>().addItem({
      'id': product.id,
      ...product.toMap(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final productService = ProductService(auth.ownerId);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowRight): _SheetMoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SheetMoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _SheetMoveRowIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _SheetMoveRowIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.keyE): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _SheetCloseIntent(),
      },
      child: Actions(
        actions: {
          _SheetMoveIntent: CallbackAction<_SheetMoveIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.delta);
              return null;
            },
          ),
          _SheetMoveRowIntent: CallbackAction<_SheetMoveRowIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.delta * _columns);
              return null;
            },
          ),
          _SheetSelectIntent: CallbackAction<_SheetSelectIntent>(
            onInvoke: (_) {
              _addFocusedProduct(context);
              return null;
            },
          ),
          _SheetCloseIntent: CallbackAction<_SheetCloseIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: NovaColors.bgTertiary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NovaColors.borderSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NovaColors.borderTertiary,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: NovaColors.violet,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Items',
                        style: TextStyle(
                          color: NovaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: NovaColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onTap: () => _searchController.selection =
                        TextSelection.collapsed(
                            offset: _searchController.text.length),
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                        _focusedIndex = 0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: NovaColors.textTertiary,
                        size: 18,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(
                                Icons.close_rounded,
                                color: NovaColors.textTertiary,
                                size: 16,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _focusedIndex = 0;
                                });
                                _focusNode.requestFocus();
                              },
                            ),
                      filled: true,
                      fillColor: NovaColors.bgPrimary,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: NovaColors.borderTertiary,
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: NovaColors.borderTertiary,
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: NovaColors.violet,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: StreamBuilder<List<Product>>(
                    stream: productService.streamProducts,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: NovaColors.violet,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        _products = const [];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: NovaColors.bgPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: NovaColors.borderTertiary,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 36,
                                    color: NovaColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No products available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: NovaColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final allProducts = snapshot.data!;
                      final filteredProducts = allProducts.where((product) {
                        if (_query.isEmpty) return true;
                        return product.name.toLowerCase().contains(_query) ||
                            product.category.toLowerCase().contains(_query);
                      }).toList();

                      _products = filteredProducts;
                      if (_products.isEmpty) {
                        return const Center(
                          child: Text(
                            'No matching products',
                            style: TextStyle(
                              color: NovaColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      if (_focusedIndex >= _products.length) {
                        _focusedIndex = _products.length - 1;
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          _columns = _columnCount(constraints.maxWidth);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.04,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final name = product.name;
                              final isFocused = index == _focusedIndex;

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _addProduct(context, product),
                                onFocusChange: (value) {
                                  if (value) {
                                    setState(() => _focusedIndex = index);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  decoration: BoxDecoration(
                                    color: NovaColors.bgPrimary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFocused
                                          ? NovaColors.violet
                                          : NovaColors.borderTertiary,
                                      width: isFocused ? 1.4 : 0.5,
                                    ),
                                    boxShadow: [
                                      if (isFocused)
                                        BoxShadow(
                                          color: NovaColors.violet
                                              .withOpacity(0.18),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: _itemBgColor(name),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _itemEmoji(name),
                                            style:
                                                const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: NovaColors.textPrimary,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: NovaColors.violetLight,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          'Rs ${product.price.toStringAsFixed(0)}',
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
  }
}

class _SheetMoveIntent extends Intent {
  final int delta;
  const _SheetMoveIntent(this.delta);
}

class _SheetMoveRowIntent extends Intent {
  final int delta;
  const _SheetMoveRowIntent(this.delta);
}

class _SheetSelectIntent extends Intent {
  const _SheetSelectIntent();
}

class _SheetCloseIntent extends Intent {
  const _SheetCloseIntent();
}
