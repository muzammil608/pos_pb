import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/product_service.dart';

// ---------------------------------------------------------------------------
// Category → Unsplash image map (mirrors pos_screen.dart _CategoryImages)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Shared product image widget (mirrors pos_screen.dart _ProductImage)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Main bottom sheet
// ---------------------------------------------------------------------------
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

  // Mirrors ResponsiveLayout.productColumns used in pos_screen.dart
  int _columnCount(double width) {
    if (width < 380) return 1;
    if (width < 600) return 1; // list mode handles <600
    if (width < 900) return 3;
    if (width < 1200) return 4;
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
                // Drag handle
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
                // Header
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
                // Search bar
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
                // Product grid / list
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
                          // ── Mobile: list tiles with image ──────────────
                          if (constraints.maxWidth < 600) {
                            _columns = 1;
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return _BottomSheetProductTile(
                                  product: product,
                                  isFocused: index == _focusedIndex,
                                  onTap: () => _addProduct(context, product),
                                  onFocus: () =>
                                      setState(() => _focusedIndex = index),
                                );
                              },
                            );
                          }

                          // ── Desktop / tablet: grid cards with image ────
                          _columns = _columnCount(constraints.maxWidth);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              // Exact same values as pos_screen.dart _ProductCard grid
                              childAspectRatio:
                                  constraints.maxWidth < 380 ? 1.35 : 0.78,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return _BottomSheetProductGridCard(
                                product: product,
                                isFocused: index == _focusedIndex,
                                onTap: () => _addProduct(context, product),
                                onFocus: () =>
                                    setState(() => _focusedIndex = index),
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

// ---------------------------------------------------------------------------
// List tile  (mirrors _ProductListTile from pos_screen.dart)
// ---------------------------------------------------------------------------
class _BottomSheetProductTile extends StatefulWidget {
  final Product product;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const _BottomSheetProductTile({
    required this.product,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
  });

  @override
  State<_BottomSheetProductTile> createState() =>
      _BottomSheetProductTileState();
}

class _BottomSheetProductTileState extends State<_BottomSheetProductTile>
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
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Product image — 72×72, left-rounded (identical to _ProductListTile)
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
              // Name + category pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary,
                      ),
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
              // Price pill + add circle (identical to _ProductListTile)
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

// ---------------------------------------------------------------------------
// Grid card  (mirrors _ProductCard from pos_screen.dart)
// ---------------------------------------------------------------------------
class _BottomSheetProductGridCard extends StatefulWidget {
  final Product product;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const _BottomSheetProductGridCard({
    required this.product,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
  });

  @override
  State<_BottomSheetProductGridCard> createState() =>
      _BottomSheetProductGridCardState();
}

class _BottomSheetProductGridCardState
    extends State<_BottomSheetProductGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
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
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onFocusChange: (v) {
              if (v) widget.onFocus();
            },
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image — top 5 flex (same ratio as _ProductCard)
                Expanded(
                  flex: 5,
                  child: _ProductImage(
                    product: widget.product,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                // Info — bottom 4 flex
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: NovaColors.textPrimary,
                            height: 1.2,
                          ),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intent classes (unchanged)
// ---------------------------------------------------------------------------
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
