import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/icon_helper.dart';
import '../../models/product_model.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(0) : '',
    );
    final purchasePriceController = TextEditingController(
      text: product != null && product.purchasePrice > 0
          ? product.purchasePrice.toStringAsFixed(0)
          : '',
    );
    final categoryController =
        TextEditingController(text: product?.category ?? '');
    final stockController = TextEditingController(
      text: (product?.stockQty ?? 0).toString(),
    );
    final lowStockController = TextEditingController(
      text: (product?.lowStockThreshold ?? 5).toString(),
    );
    final damagedController = TextEditingController(
      text: (product?.damagedQty ?? 0).toString(),
    );
    final barcodeController =
        TextEditingController(text: product?.barcode ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = product != null;

    IconData selectedIcon = product?.icon ?? Icons.fastfood;
    if (!isEdit) {
      selectedIcon = IconHelper.getDefaultIcon(categoryController.text);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: CafeColors.headerGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isEdit
                                      ? Icons.edit_rounded
                                      : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isEdit ? 'Edit Product' : 'Add Product',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: CafeColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _StyledField(
                            controller: nameController,
                            label: 'Product Name',
                            icon: Icons.shopping_bag_outlined,
                            autofocus: !isEdit,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _StyledField(
                            controller: priceController,
                            label: 'Sale Price',
                            icon: Icons.payments_outlined,
                            prefixText: 'Rs ',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Price is required';
                              }
                              if (double.tryParse(v.trim()) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _StyledField(
                            controller: purchasePriceController,
                            label: 'Purchase Price',
                            icon: Icons.shopping_cart_checkout_rounded,
                            prefixText: 'Rs ',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              if (double.tryParse(v.trim()) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _StyledField(
                            controller: categoryController,
                            label: 'Category',
                            icon: Icons.category_outlined,
                            hint: 'e.g. Drinks, POS, Burgers',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) {
                              if (!isEdit && value.isNotEmpty) {
                                final defaultIcon =
                                    IconHelper.getDefaultIcon(value);
                                setSheetState(() => selectedIcon = defaultIcon);
                              }
                            },
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Category is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StyledField(
                                  controller: stockController,
                                  label: 'Stock Qty',
                                  icon: Icons.inventory_2_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StyledField(
                                  controller: lowStockController,
                                  label: 'Low Alert',
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StyledField(
                                  controller: damagedController,
                                  label: 'Damaged',
                                  icon: Icons.broken_image_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StyledField(
                                  controller: barcodeController,
                                  label: 'Barcode',
                                  icon: Icons.qr_code_2_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Choose Icon',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CafeColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 56,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: IconHelper.fastFoodIcons.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final icon = IconHelper.fastFoodIcons[index];
                                final isSelected = icon == selectedIcon;
                                return GestureDetector(
                                  onTap: () =>
                                      setSheetState(() => selectedIcon = icon),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? CafeColors.creme
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? CafeColors.flame
                                            : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? CafeColors.flame
                                          : Colors.grey[500],
                                      size: 24,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          Consumer<ProductProvider>(
                            builder: (context, provider, _) {
                              return SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: provider.isLoading
                                        ? null
                                        : CafeColors.headerGradient,
                                    color: provider.isLoading
                                        ? Colors.grey[200]
                                        : null,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: provider.isLoading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: CafeColors.flame
                                                  .withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: provider.isLoading
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            final name =
                                                nameController.text.trim();
                                            final price = double.parse(
                                                priceController.text.trim());
                                            final purchasePrice =
                                                double.tryParse(
                                                      purchasePriceController
                                                          .text
                                                          .trim(),
                                                    ) ??
                                                    0;
                                            final category =
                                                categoryController.text.trim();
                                            final iconCodePoint =
                                                selectedIcon.codePoint;
                                            final stockQty = int.tryParse(
                                                    stockController.text
                                                        .trim()) ??
                                                0;
                                            final lowStockThreshold =
                                                int.tryParse(lowStockController
                                                        .text
                                                        .trim()) ??
                                                    5;
                                            final damagedQty = int.tryParse(
                                                    damagedController.text
                                                        .trim()) ??
                                                0;
                                            final barcode =
                                                barcodeController.text.trim();

                                            String? error;
                                            if (isEdit) {
                                              error =
                                                  await provider.updateProduct(
                                                id: product.id,
                                                name: name,
                                                price: price,
                                                purchasePrice: purchasePrice,
                                                category: category,
                                                iconCodePoint: iconCodePoint,
                                                stockQty: stockQty,
                                                lowStockThreshold:
                                                    lowStockThreshold,
                                                damagedQty: damagedQty,
                                                barcode: barcode,
                                              );
                                            } else {
                                              error =
                                                  await provider.createProduct(
                                                name: name,
                                                price: price,
                                                purchasePrice: purchasePrice,
                                                category: category,
                                                iconCodePoint: iconCodePoint,
                                                stockQty: stockQty,
                                                lowStockThreshold:
                                                    lowStockThreshold,
                                                damagedQty: damagedQty,
                                                barcode: barcode,
                                              );
                                            }

                                            if (!sheetContext.mounted) return;
                                            Navigator.pop(sheetContext);

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(
                                                      error != null
                                                          ? Icons.error_outline
                                                          : Icons
                                                              .check_circle_outline,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(error ??
                                                        (isEdit
                                                            ? 'Product updated'
                                                            : 'Product added')),
                                                  ],
                                                ),
                                                backgroundColor: error != null
                                                    ? const Color(0xFFE53935)
                                                    : CafeColors.olive,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                            );
                                          },
                                    icon: provider.isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            isEdit
                                                ? Icons.save_rounded
                                                : Icons.add_rounded,
                                            color: Colors.white,
                                          ),
                                    label: Text(
                                      provider.isLoading
                                          ? (isEdit ? 'Saving...' : 'Adding...')
                                          : (isEdit
                                              ? 'Save Changes'
                                              : 'Add Product'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDE8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: CafeColors.flame, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CafeColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${product.name}"? This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CafeColors.charcoal.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                            color: CafeColors.charcoal.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: CafeColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final error = await context
                              .read<ProductProvider>()
                              .deleteProduct(product.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    error != null
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(error ?? 'Product deleted'),
                                ],
                              ),
                              backgroundColor: error != null
                                  ? const Color(0xFFE53935)
                                  : CafeColors.olive,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProductProvider>(
      builder: (context, auth, productProvider, child) {
        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/products'),
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
                      Icon(Icons.inventory_2_rounded,
                          color: Colors.white70, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Products',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.3,
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
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/products',
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NovaColors.borderTertiary,
                                width: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              cursorColor: NovaColors.violet,
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                              style: const TextStyle(
                                  fontSize: 14, color: NovaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: const TextStyle(
                                    color: NovaColors.textTertiary,
                                    fontSize: 14),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: NovaColors.textSecondary, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            color: NovaColors.textTertiary,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                filled: true,
                                fillColor: NovaColors.bgPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _showProductForm(context),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: CafeColors.headerGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: CafeColors.flame.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<Product>>(
                      stream: context.read<ProductProvider>().productsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: CafeColors.flame),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        final allProducts = snapshot.data ?? [];

                        if (allProducts.isEmpty) {
                          return _emptyProductsView(context);
                        }

                        final categories = [
                          'All',
                          ...{...allProducts.map((p) => p.category)},
                        ];

                        final filtered = allProducts.where((p) {
                          final matchesSearch = _searchQuery.isEmpty ||
                              p.name.toLowerCase().contains(_searchQuery) ||
                              p.category.toLowerCase().contains(_searchQuery);
                          final matchesCategory = _selectedCategory == 'All' ||
                              p.category == _selectedCategory;
                          return matchesSearch && matchesCategory;
                        }).toList();

                        return Column(
                          children: [
                            if (categories.length > 1)
                              SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.zero,
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final cat = categories[i];
                                    final isSelected = _selectedCategory == cat;
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedCategory = cat),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? CafeColors.headerGradient
                                              : null,
                                          color:
                                              isSelected ? null : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : CafeColors.flame
                                                    .withOpacity(0.2),
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: CafeColors.flame
                                                        .withOpacity(0.25),
                                                    blurRadius: 6,
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
                                                : CafeColors.charcoal
                                                    .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          CafeColors.flame,
                                          CafeColors.amber
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          CafeColors.charcoal.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: filtered.isEmpty
                                  ? _noResultsView()
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns =
                                            ResponsiveLayout.cardColumns(
                                          constraints.maxWidth,
                                        );

                                        if (columns == 1) {
                                          return ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 4, 0, 100),
                                            itemCount: filtered.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, i) {
                                              final product = filtered[i];
                                              return _ProductCard(
                                                product: product,
                                                onEdit: () => _showProductForm(
                                                  context,
                                                  product: product,
                                                ),
                                                onDelete: () => _confirmDelete(
                                                    context, product),
                                              );
                                            },
                                          );
                                        }

                                        return GridView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 4, 0, 100),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 4.8,
                                          ),
                                          itemCount: filtered.length,
                                          itemBuilder: (context, i) {
                                            final product = filtered[i];
                                            return _ProductCard(
                                              product: product,
                                              onEdit: () => _showProductForm(
                                                context,
                                                product: product,
                                              ),
                                              onDelete: () => _confirmDelete(
                                                  context, product),
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyProductsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CafeColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first product to get started',
            style: TextStyle(
              fontSize: 13,
              color: CafeColors.charcoal.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: CafeColors.headerGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showProductForm(context),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add First Product',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResultsView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 36, color: CafeColors.flame),
          ),
          const SizedBox(height: 12),
          Text(
            'No results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CafeColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? prefixText;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.prefixText,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: CafeColors.charcoal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        labelStyle: TextStyle(
            color: CafeColors.charcoal.withOpacity(0.55), fontSize: 13),
        prefixIcon: Icon(icon, color: CafeColors.flame, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CafeColors.flame, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: CafeColors.steam,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CafeColors.flame.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CafeColors.creme,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(product.icon, color: CafeColors.flame, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CafeColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CafeColors.oliveLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CafeColors.olive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Rs ${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: CafeColors.flame,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Color(0xFF1976D2), size: 16),
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDE8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: CafeColors.flame, size: 16),
              ),
              onPressed: onDelete,
              tooltip: 'Delete',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ],
        ),
      ),
    );
  }
}
