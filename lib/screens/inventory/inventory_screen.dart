// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/utils/app_notice.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/no_animation_route.dart';
import '../../services/pocketbase/inventory_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  InventoryService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _service ??= InventoryService(auth.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) return const _LoadingScaffold();

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const _LoadingScaffold();
        }

        final userEmail = auth.user?.email ?? '';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: AppNavigationShell.isDesktop(context)
              ? null
              : AppNavigationDrawer(auth: auth, currentRoute: '/inventory'),
          appBar: AppNavigationAppBar(
            title: 'Inventory Dashboard',
            icon: Icons.inventory_rounded,
            photoUrl: photoUrl,
            userName: userName,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
          body: Center(
            child: Container(
              width: double.infinity,
              alignment: Alignment.topCenter,
              child: AppNavigationShell(
                auth: auth,
                currentRoute: '/inventory',
                child: ResponsiveCenter(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: _InventoryBody(service: _service!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InventoryBody extends StatefulWidget {
  const _InventoryBody({required this.service});
  final InventoryService service;

  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody> {
  late Future<List<dynamic>> _future;
  StreamSubscription<List<Product>>? _productsSub;
  bool _profitExpanded = false;

  Future<List<dynamic>> _loadData() => Future.wait([
        widget.service.getProducts(),
        widget.service.getTransactions(limit: 120),
      ]);

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _productsSub = widget.service.streamProducts().listen((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final next = _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _future = next;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading inventory:\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: NovaColors.textSecondary, fontSize: 13),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: NovaColors.teal));
        }

        final products = snapshot.data![0] as List<Product>;
        final transactions = snapshot.data![1] as List<InventoryTransaction>;
        final summary = InventorySummary.fromProducts(products);

        final categorySet = products.map((e) => e.category.trim()).toSet();
        final categories = categorySet.where((e) => e.isNotEmpty).toList()
          ..sort();

        final lowStock = products
            .where((p) => p.stockQty <= p.lowStockThreshold)
            .toList()
          ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

        return LayoutBuilder(builder: (context, c) {
          final isDesktop = c.maxWidth >= 1000;
          final isTablet = c.maxWidth >= AppBreakpoints.mobile;

          return ListView(
            children: [
              _HeaderRow(
                totalProducts: products.length,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 12),
              _BarcodeRestockPanel(
                products: products,
                service: widget.service,
                onMutated: _refresh,
              ),
              const SizedBox(height: 12),
              _ProfitExpansionPanel(
                products: products,
                transactions: transactions,
                expanded: _profitExpanded,
                onToggle: () =>
                    setState(() => _profitExpanded = !_profitExpanded),
              ),
              const SizedBox(height: 12),
              if (isDesktop)
                Builder(builder: (context) {
                  final cards = _buildMetricCards(summary, products);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < 3; i++) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(child: cards[i]),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _InventoryTablePanel(
                              products: products,
                              categories: categories,
                              service: widget.service,
                              onMutated: _refresh,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            cards[3],
                            const SizedBox(height: 14),
                            _SidePanels(
                              lowStock: lowStock,
                              txStream: widget.service.streamTransactions(),
                              isTablet: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                })
              else if (isTablet)
                Column(
                  children: [
                    _MetricsGrid(summary: summary, products: products),
                    const SizedBox(height: 14),
                    _InventoryTablePanel(
                      products: products,
                      categories: categories,
                      service: widget.service,
                      onMutated: _refresh,
                    ),
                    const SizedBox(height: 14),
                    _SidePanels(
                      lowStock: lowStock,
                      txStream: widget.service.streamTransactions(),
                      isTablet: true,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _MetricsGrid(summary: summary, products: products),
                    const SizedBox(height: 14),
                    _InventoryTablePanel(
                      products: products,
                      categories: categories,
                      service: widget.service,
                      onMutated: _refresh,
                    ),
                    const SizedBox(height: 14),
                    _SidePanels(
                      lowStock: lowStock,
                      txStream: widget.service.streamTransactions(),
                      isTablet: false,
                    ),
                  ],
                ),
            ],
          );
        });
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.totalProducts, required this.onRefresh});
  final int totalProducts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 760;

      final titleCol = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Overview',
            style: TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Showing $totalProducts products',
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
          ),
        ],
      );

      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/products')
                .then((_) => onRefresh()),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Product'),
            style: FilledButton.styleFrom(
              backgroundColor: NovaColors.teal,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ).copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
          ),
        ],
      );

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleCol, const SizedBox(height: 10), actions],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [titleCol, actions],
      );
    });
  }
}

class _BarcodeRestockPanel extends StatefulWidget {
  const _BarcodeRestockPanel({
    required this.products,
    required this.service,
    required this.onMutated,
  });

  final List<Product> products;
  final InventoryService service;
  final VoidCallback onMutated;

  @override
  State<_BarcodeRestockPanel> createState() => _BarcodeRestockPanelState();
}

class _BarcodeRestockPanelState extends State<_BarcodeRestockPanel> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode(debugLabel: 'InventoryBarcodeScanner');
  bool _isSaving = false;

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Product? _findProduct(String rawCode) {
    final code = rawCode.trim().toLowerCase();
    if (code.isEmpty) return null;

    for (final product in widget.products) {
      if (product.barcode.trim().toLowerCase() == code ||
          product.id.trim().toLowerCase() == code) {
        return product;
      }
    }
    return null;
  }

  Future<void> _handleScan(String rawCode) async {
    if (_isSaving) return;

    final code = rawCode.trim();
    if (code.isEmpty) return;

    final product = _findProduct(code);
    if (product == null) {
      AppNotice.show(
        context,
        'No product found for barcode $code.',
        type: AppNoticeType.error,
      );
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    final qty = await _showBarcodeQtyDialog(product);
    if (qty == null || qty <= 0 || !mounted) {
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.service.restock(
        productId: product.id,
        productName: product.name,
        quantity: qty,
        note: 'Barcode restock: $code',
      );
      if (!mounted) return;
      AppNotice.show(
        context,
        'Added $qty to ${product.name}.',
        type: AppNoticeType.success,
      );
      widget.onMutated();
    } catch (e) {
      if (mounted) {
        AppNotice.show(
          context,
          'Barcode restock failed: $e',
          type: AppNoticeType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        _barcodeController.clear();
        _barcodeFocusNode.requestFocus();
      }
    }
  }

  Future<int?> _showBarcodeQtyDialog(Product product) {
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add stock - ${product.name}',
          style: const TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current stock: ${product.stockQty}',
                style: const TextStyle(
                  color: NovaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: NovaColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: _barcodeInputDecoration(
                  label: 'Quantity to add',
                  icon: Icons.add_box_outlined,
                ),
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  if (qty == null || qty <= 0) {
                    return 'Enter a positive quantity';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, int.parse(qtyController.text.trim()));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NovaColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(qtyController.text.trim()));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: NovaColors.teal,
              foregroundColor: Colors.white,
            ).copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            child: const Text('Add Stock'),
          ),
        ],
      ),
    ).whenComplete(qtyController.dispose);
  }

  InputDecoration _barcodeInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: NovaColors.textSecondary),
      prefixIcon: Icon(icon, color: NovaColors.teal, size: 18),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.teal, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD85A30)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD85A30)),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.mobile;
        final title = Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: NovaColors.tealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: NovaColors.tealDeep,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barcode Restock',
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scan an existing product barcode, then enter quantity',
                    style: TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final input = TextField(
          controller: _barcodeController,
          focusNode: _barcodeFocusNode,
          enabled: !_isSaving,
          textInputAction: TextInputAction.done,
          onSubmitted: _handleScan,
          style: const TextStyle(color: NovaColors.textPrimary, fontSize: 13),
          decoration: _barcodeInputDecoration(
            label: 'Scan or enter barcode',
            icon: Icons.document_scanner_outlined,
          ).copyWith(
            suffixIcon: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NovaColors.teal,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Submit barcode',
                    mouseCursor: SystemMouseCursors.click,
                    onPressed: () => _handleScan(_barcodeController.text),
                    icon: const Icon(
                      Icons.keyboard_return_rounded,
                      color: NovaColors.textSecondary,
                      size: 18,
                    ),
                  ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              title,
              const SizedBox(height: 12),
              input,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 14),
            SizedBox(width: 320, child: input),
          ],
        );
      }),
    );
  }
}

class _ProfitExpansionPanel extends StatelessWidget {
  const _ProfitExpansionPanel({
    required this.products,
    required this.transactions,
    required this.expanded,
    required this.onToggle,
  });

  final List<Product> products;
  final List<InventoryTransaction> transactions;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final productById = {
      for (final p in products) p.id: p,
    };
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    final saleTx = transactions.where(
      (t) =>
          t.type.toLowerCase() == 'sale' &&
          t.createdAt.toLocal().isAfter(cutoff),
    );
    final soldQtyByProduct = <String, int>{};
    for (final tx in saleTx) {
      soldQtyByProduct[tx.productId] =
          (soldQtyByProduct[tx.productId] ?? 0) + tx.quantity;
    }

    final productsWithCost = products.where((p) => p.purchasePrice > 0).length;
    final saleValue = soldQtyByProduct.entries.fold<double>(0, (sum, entry) {
      final p = productById[entry.key];
      if (p == null) return sum;
      return sum + (p.price * entry.value);
    });
    final purchaseValue =
        soldQtyByProduct.entries.fold<double>(0, (sum, entry) {
      final p = productById[entry.key];
      if (p == null) return sum;
      return sum + (p.purchasePrice * entry.value);
    });
    final stockSaleValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.price * p.stockQty),
    );
    final stockCostValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.purchasePrice * p.stockQty),
    );
    final stockProfit = stockSaleValue - stockCostValue;
    final profit = saleValue - purchaseValue;
    final margin = saleValue <= 0 ? 0 : (profit / saleValue) * 100;
    final soldProducts = soldQtyByProduct.keys
        .map((id) => productById[id])
        .whereType<Product>()
        .toList();
    soldProducts.sort(
      (a, b) => _salesProfit(b, soldQtyByProduct[b.id] ?? 0)
          .compareTo(_salesProfit(a, soldQtyByProduct[a.id] ?? 0)),
    );

    return Container(
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: NovaColors.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: NovaColors.tealDeep, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profit',
                          style: TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded
                              ? 'Sales margin ${margin.toStringAsFixed(1)}%'
                              : 'Tap to view sold-value profit summary',
                          style: const TextStyle(
                              color: NovaColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(profit),
                    style: TextStyle(
                      color: profit >= 0
                          ? NovaColors.tealDeep
                          : const Color(0xFFB54724),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: NovaColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1, color: NovaColors.borderTertiary),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, c) {
                    final compact = c.maxWidth < AppBreakpoints.mobile;
                    final stats = [
                      _ProfitStat(
                        label: 'Sold Value',
                        value: _formatMoney(saleValue),
                      ),
                      _ProfitStat(
                        label: 'COGS',
                        value: _formatMoney(purchaseValue),
                      ),
                      _ProfitStat(
                        label: 'Profit Margin',
                        value: '${margin.toStringAsFixed(1)}%',
                      ),
                      _ProfitStat(
                        label: 'Cost Prices',
                        value: '$productsWithCost/${products.length}',
                      ),
                      _ProfitStat(
                        label: 'Stock Profit',
                        value: _formatMoney(stockProfit),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            stats[i],
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: stats[i]),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  if (soldProducts.isEmpty)
                    const _MutedText(text: 'No sales yet to calculate profit.')
                  else
                    Column(
                      children: soldProducts.take(3).map((p) {
                        return _ProfitProductRow(
                          product: p,
                          soldQty: soldQtyByProduct[p.id] ?? 0,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _ProfitStat extends StatelessWidget {
  const _ProfitStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitProductRow extends StatelessWidget {
  const _ProfitProductRow({
    required this.product,
    required this.soldQty,
  });
  final Product product;
  final int soldQty;

  @override
  Widget build(BuildContext context) {
    final profit = _salesProfit(product, soldQty);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: NovaColors.textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'x$soldQty',
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            '${_formatMoney(product.purchasePrice)} -> ${_formatMoney(product.price)}',
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            _formatMoney(profit),
            style: TextStyle(
              color:
                  profit >= 0 ? NovaColors.tealDeep : const Color(0xFFB54724),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary, required this.products});
  final InventorySummary summary;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final cards = _buildMetricCards(summary, products);

    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 700 ? 4 : 2;

      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += columns) {
        final rowCards = cards.sublist(i, (i + columns).clamp(0, cards.length));
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < rowCards.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(child: rowCards[j]),
                ],
              ],
            ),
          ),
        );
        if (i + columns < cards.length) rows.add(const SizedBox(height: 10));
      }

      return Column(children: rows);
    });
  }
}

List<Widget> _buildMetricCards(
  InventorySummary summary,
  List<Product> products,
) {
  final out = products.where((p) => p.stockQty <= 0).length;

  return [
    _MetricCard(
      title: 'Total SKUs',
      value: '${summary.totalProducts}',
      subText: '${products.where((p) => p.stockQty > 0).length} in stock',
      icon: Icons.inventory_2_rounded,
      iconColor: NovaColors.teal,
    ),
    _MetricCard(
      title: 'Stock Value',
      value: 'Rs ${summary.stockValue.toStringAsFixed(0)}',
      subText: 'Current inventory value',
      icon: Icons.payments_rounded,
      iconColor: const Color(0xFF378ADD),
    ),
    _MetricCard(
      title: 'Low Stock',
      value: '${summary.lowStockCount}',
      subText:
          summary.lowStockCount == 0 ? 'All healthy' : 'Needs reorder soon',
      icon: Icons.warning_rounded,
      iconColor: NovaColors.violet,
    ),
    _MetricCard(
      title: 'Out of Stock',
      value: '$out',
      subText: out == 0 ? 'No blockers' : 'Action required',
      icon: Icons.block_rounded,
      iconColor: const Color(0xFFD85A30),
    ),
  ];
}

double _unitProfit(Product product) => product.price - product.purchasePrice;
double _salesProfit(Product product, int soldQty) =>
    _unitProfit(product) * soldQty;

String _formatMoney(num value) => 'Rs ${value.toStringAsFixed(0)}';

class _InventoryTablePanel extends StatefulWidget {
  const _InventoryTablePanel({
    required this.products,
    required this.categories,
    required this.service,
    required this.onMutated,
  });

  final List<Product> products;
  final List<String> categories;
  final InventoryService service;
  final VoidCallback onMutated;

  @override
  State<_InventoryTablePanel> createState() => _InventoryTablePanelState();
}

class _InventoryTablePanelState extends State<_InventoryTablePanel> {
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode =
      FocusNode(debugLabel: 'InventorySearchField');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyboard);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboard);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _handleKeyboard(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final keyboard = HardwareKeyboard.instance;
    final isCtrlOrMeta = keyboard.isControlPressed || keyboard.isMetaPressed;
    final isFocusSearch =
        (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyF) ||
            event.logicalKey == LogicalKeyboardKey.slash;

    if (isFocusSearch) {
      _focusSearch();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)) {
      _clearSearch();
      _searchFocusNode.unfocus();
      return true;
    }

    return false;
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<Product> get _filtered {
    List<Product> list = _selectedCategory == 'All Categories'
        ? widget.products
        : widget.products
            .where((p) => p.category == _selectedCategory)
            .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.barcode.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 760;
      final compactTable = c.maxWidth < 1080;
      final tableColumnSpacing = compactTable ? 8.0 : 18.0;
      final tableHorizontalMargin = compactTable ? 8.0 : 12.0;
      final productWidth = compactTable ? 150.0 : 190.0;
      final categoryWidth = compactTable ? 70.0 : 96.0;
      final moneyWidth = compactTable ? 50.0 : 62.0;
      final stockWidth = compactTable ? 76.0 : 94.0;
      final reorderWidth = compactTable ? 42.0 : 62.0;
      final statusWidth = compactTable ? 82.0 : 94.0;
      final actionsWidth = compactTable ? 102.0 : 120.0;
      final double contentHeight = (visible.length * 60.0).clamp(200.0, 600.0);

      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  const Text(
                    'Product Inventory',
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox.shrink(),
                    dropdownColor: NovaColors.bgSecondary,
                    style: const TextStyle(
                        color: NovaColors.textPrimary, fontSize: 12),
                    items: [
                      const DropdownMenuItem(
                        value: 'All Categories',
                        child: Text('All Categories'),
                      ),
                      ...widget.categories.map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                      color: NovaColors.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText:
                        'Search by name, barcode or category…  ( / or Ctrl+F )',
                    hintStyle: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: NovaColors.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            mouseCursor: SystemMouseCursors.click,
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded,
                                color: NovaColors.textSecondary, size: 16),
                          )
                        : null,
                    filled: true,
                    fillColor: NovaColors.bgSecondary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NovaColors.borderTertiary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NovaColors.borderTertiary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NovaColors.teal),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: NovaColors.borderTertiary),

            // Content
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No products found.',
                  style:
                      TextStyle(color: NovaColors.textSecondary, fontSize: 12),
                ),
              )
            else if (isMobile)
              SizedBox(
                height: contentHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _ProductCardList(
                    products: visible,
                    onRestock: (p) => _showRestockDialog(context, p),
                    onAdjust: (p) => _showAdjustDialog(context, p),
                    onOrder: (p) => _openSupplierOrder(context, p, visible),
                  ),
                ),
              )
            else
              SizedBox(
                height: contentHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 54,
                      dataRowMaxHeight: 60,
                      columnSpacing: tableColumnSpacing,
                      horizontalMargin: tableHorizontalMargin,
                      headingTextStyle: const TextStyle(
                        color: NovaColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(
                            width: productWidth,
                            child: const Text('Product'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: categoryWidth,
                            child: const Text('Category'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Purchase'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Sale'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Profit'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: stockWidth,
                            child: const Text('Stock'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: reorderWidth,
                            child: const Text('Alert'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: statusWidth,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Status'),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: actionsWidth,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Actions'),
                            ),
                          ),
                        ),
                      ],
                      rows: visible.map((p) {
                        return DataRow(cells: [
                          DataCell(
                            SizedBox(
                              width: productWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NovaColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    p.barcode.isNotEmpty ? p.barcode : p.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NovaColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: categoryWidth,
                              child: Text(
                                p.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: NovaColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(value: p.purchasePrice),
                          )),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(value: p.price),
                          )),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(
                              value: _unitProfit(p),
                              emphasize: true,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: stockWidth,
                            child: _StockCell(
                              product: p,
                              compact: compactTable,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: reorderWidth,
                            child: Text(
                              '${p.lowStockThreshold}',
                              style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  fontSize: 12),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: statusWidth,
                            child: _StatusPill(product: p),
                          )),
                          DataCell(SizedBox(
                            width: actionsWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _TableActionButton(
                                  tooltip: 'Restock',
                                  icon: Icons.add_circle_outline_rounded,
                                  color: NovaColors.teal,
                                  onPressed: () =>
                                      _showRestockDialog(context, p),
                                ),
                                _TableActionButton(
                                  tooltip: 'Adjust stock',
                                  icon: Icons.tune_rounded,
                                  color: NovaColors.textSecondary,
                                  onPressed: () =>
                                      _showAdjustDialog(context, p),
                                ),
                                _TableActionButton(
                                  tooltip: 'Supplier order',
                                  icon: Icons.local_shipping_outlined,
                                  color: NovaColors.violet,
                                  onPressed: () =>
                                      _openSupplierOrder(context, p, visible),
                                ),
                              ],
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Text(
                'Showing ${visible.length} of ${widget.products.length} products'
                '${_searchQuery.isNotEmpty ? ' · filtered by "$_searchQuery"' : ''}',
                style: const TextStyle(
                    color: NovaColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _openSupplierOrder(
    BuildContext context,
    Product product,
    List<Product> availableProducts,
  ) {
    Navigator.of(context).push(
      NoAnimationPageRoute(
        builder: (_) => SupplierOrderScreen(
          product: product,
          products: availableProducts,
        ),
      ),
    );
  }

  Future<void> _showRestockDialog(BuildContext context, Product p) async {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Restock — ${p.name}',
          style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${p.stockQty}',
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Quantity to add'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: noteCtrl,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NovaColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: FilledButton.styleFrom(
                    backgroundColor: NovaColors.teal,
                    foregroundColor: Colors.white)
                .copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.restock(
          productId: p.id,
          productName: p.name,
          quantity: int.parse(qtyCtrl.text.trim()),
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        if (!mounted) return;
        AppNotice.show(
          context,
          'Restocked ${p.name} successfully.',
          type: AppNoticeType.success,
        );
        try {
          widget.onMutated();
        } catch (e) {
          debugPrint('[Inventory] refresh after restock skipped: $e');
        }
      } catch (e) {
        if (mounted) {
          AppNotice.show(
            context,
            'Restock failed: $e',
            type: AppNoticeType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  Future<void> _showAdjustDialog(BuildContext context, Product p) async {
    final deltaCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Adjust Stock — ${p.name}',
          style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${p.stockQty}',
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              const Text('Enter +10 to add, -5 to remove.',
                  style:
                      TextStyle(color: NovaColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 12),
              TextFormField(
                controller: deltaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Delta (e.g. +10 or -3)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n == 0) return 'Enter a non-zero integer';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: noteCtrl,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Reason (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NovaColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: FilledButton.styleFrom(
                    backgroundColor: NovaColors.violet,
                    foregroundColor: Colors.white)
                .copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.adjust(
          productId: p.id,
          productName: p.name,
          delta: int.parse(deltaCtrl.text.trim()),
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        if (mounted) widget.onMutated();
      } catch (e) {
        if (mounted) {
          AppNotice.show(
            context,
            'Adjustment failed: $e',
            type: AppNoticeType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NovaColors.borderSecondary),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NovaColors.teal),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD85A30)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD85A30)),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
// Mobile product card list

class _ProductCardList extends StatelessWidget {
  const _ProductCardList({
    required this.products,
    required this.onRestock,
    required this.onAdjust,
    required this.onOrder,
  });

  final List<Product> products;
  final void Function(Product) onRestock;
  final void Function(Product) onAdjust;
  final void Function(Product) onOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: NovaColors.borderTertiary)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NovaColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.barcode.isNotEmpty ? p.barcode : p.id,
                      style: const TextStyle(
                          color: NovaColors.textTertiary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buy ${_formatMoney(p.purchasePrice)}  |  Sell ${_formatMoney(p.price)}  |  Profit ${_formatMoney(_unitProfit(p))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: NovaColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(product: p),
                        const SizedBox(width: 8),
                        Flexible(child: _StockCell(product: p)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Restock',
                    mouseCursor: SystemMouseCursors.click,
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 20, color: NovaColors.teal),
                    onPressed: () => onRestock(p),
                  ),
                  IconButton(
                    tooltip: 'Adjust',
                    mouseCursor: SystemMouseCursors.click,
                    icon: const Icon(Icons.tune_rounded,
                        size: 20, color: NovaColors.textSecondary),
                    onPressed: () => onAdjust(p),
                  ),
                  IconButton(
                    tooltip: 'Supplier order',
                    mouseCursor: SystemMouseCursors.click,
                    icon: const Icon(Icons.local_shipping_outlined,
                        size: 20, color: NovaColors.violet),
                    onPressed: () => onOrder(p),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SidePanels extends StatelessWidget {
  const _SidePanels({
    required this.lowStock,
    required this.txStream,
    required this.isTablet,
  });

  final List<Product> lowStock;
  final Stream<List<InventoryTransaction>> txStream;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final noticePanel = _StockNotificationsPanel(lowStock: lowStock);

    final alertsPanel = _PanelCard(
      title: 'Reorder Alerts',
      actionText: 'View all',
      onActionTap: lowStock.isEmpty
          ? null
          : () => _showAllReorderAlertsDialog(context, lowStock),
      child: lowStock.isEmpty
          ? const _MutedText(text: 'No reorder alerts right now.')
          : Column(
              children: lowStock.take(8).map((p) {
                return _ThinListItem(
                  icon: p.stockQty <= 0
                      ? Icons.error_outline
                      : Icons.warning_rounded,
                  iconBg: p.stockQty <= 0
                      ? const Color(0xFFFFEDE8)
                      : NovaColors.violetLight,
                  iconColor: p.stockQty <= 0
                      ? const Color(0xFFB54724)
                      : NovaColors.violetDeep,
                  title: p.name,
                  subtitle:
                      '${p.stockQty} units left · Min: ${p.lowStockThreshold}',
                  trailing: _ReorderButton(product: p, products: lowStock),
                );
              }).toList(),
            ),
    );

    final activityPanel = _PanelCard(
      title: 'Recent Activity',
      child: StreamBuilder<List<InventoryTransaction>>(
        stream: txStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MutedText(text: 'Error: ${snapshot.error}');
          }
          final txs = snapshot.data ?? const <InventoryTransaction>[];
          final cutoff = DateTime.now().subtract(const Duration(hours: 12));
          final recent = txs
              .where((tx) => tx.createdAt.toLocal().isAfter(cutoff))
              .toList();
          if (recent.isEmpty) {
            return const _MutedText(text: 'No recent inventory activity.');
          }
          return Column(
            children:
                recent.take(8).map((tx) => _ActivityItem(tx: tx)).toList(),
          );
        },
      ),
    );

    if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: alertsPanel),
              const SizedBox(width: 12),
              Expanded(child: noticePanel),
            ],
          ),
          const SizedBox(height: 12),
          activityPanel,
        ],
      );
    }

    return Column(
      children: [
        alertsPanel,
        const SizedBox(height: 12),
        noticePanel,
        const SizedBox(height: 12),
        activityPanel,
      ],
    );
  }
}

class _ReorderButton extends StatelessWidget {
  const _ReorderButton({required this.product, this.products});
  final Product product;
  final List<Product>? products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            NoAnimationPageRoute(
              builder: (_) => SupplierOrderScreen(
                product: product,
                products: products,
              ),
            ),
          );
        },
        icon: const Icon(Icons.local_shipping_outlined, size: 14),
        label: const Text('Order'),
        style: FilledButton.styleFrom(
          backgroundColor: NovaColors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ).copyWith(
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),
    );
  }
}

Future<void> _showAllReorderAlertsDialog(
  BuildContext context,
  List<Product> lowStock,
) async {
  final sorted = [...lowStock]
    ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NovaColors.bgPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'All Reorder Alerts',
        style: TextStyle(
          color: NovaColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: sorted.isEmpty
            ? const Text(
                'No reorder alerts right now.',
                style: TextStyle(color: NovaColors.textSecondary, fontSize: 12),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: NovaColors.borderTertiary),
                itemBuilder: (_, i) {
                  final p = sorted[i];
                  final out = p.stockQty <= 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      out
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: out
                          ? const Color(0xFFB54724)
                          : const Color(0xFFEF6C00),
                      size: 18,
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(
                        color: NovaColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${p.stockQty} left • Min ${p.lowStockThreshold}',
                      style: const TextStyle(
                        color: NovaColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    trailing: _ReorderButton(product: p, products: sorted),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: NovaColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class SupplierOrderScreen extends StatefulWidget {
  const SupplierOrderScreen({
    super.key,
    required this.product,
    this.products,
  });

  final Product product;
  final List<Product>? products;

  @override
  State<SupplierOrderScreen> createState() => _SupplierOrderScreenState();
}

class _SupplierOrderScreenState extends State<SupplierOrderScreen> {
  static const String _suppliersPrefsKey = 'supplier_order_suppliers_v1';
  static const Set<String> _starterSupplierNames = {
    'metro wholesale',
    'fresh stock traders',
    'daily goods supplier',
  };

  final _supplierFormKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();
  final _supplierContactController = TextEditingController();
  final _supplierEmailController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _supplierLeadTimeController = TextEditingController();
  final _supplierTermsController = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = {};
  final Set<String> _selectedProductIds = {};
  late List<_SupplierInfo> _suppliers;
  int _selectedSupplier = 0;
  int? _editingSupplierIndex;

  late final List<Product> _orderProducts;

  @override
  void initState() {
    super.initState();
    _suppliers = <_SupplierInfo>[];
    _loadSuppliers();
    final products = widget.products ?? [widget.product];
    final byId = <String, Product>{};
    for (final product in products) {
      byId[product.id] = product;
    }
    byId[widget.product.id] = widget.product;
    _orderProducts = byId.values.toList()
      ..sort((a, b) {
        if (a.id == widget.product.id) return -1;
        if (b.id == widget.product.id) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    for (final product in _orderProducts) {
      _qtyControllers[product.id] = TextEditingController(
        text: _suggestedOrderQty(product).toString(),
      );
    }
    _selectedProductIds.add(widget.product.id);
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    _supplierNameController.dispose();
    _supplierContactController.dispose();
    _supplierEmailController.dispose();
    _supplierAddressController.dispose();
    _supplierLeadTimeController.dispose();
    _supplierTermsController.dispose();
    super.dispose();
  }

  int _suggestedOrderQty(Product product) {
    final needed =
        (product.lowStockThreshold - product.stockQty).clamp(0, 999).toInt();
    return needed <= 0 ? 5 : needed + 5;
  }

  List<_SupplierOrderLine> _selectedOrderLines() {
    return _orderProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .map((product) {
          final qty =
              int.tryParse(_qtyControllers[product.id]?.text.trim() ?? '') ?? 0;
          return _SupplierOrderLine(product: product, qty: qty);
        })
        .where((line) => line.qty > 0)
        .toList();
  }

  int get _selectedItemCount => _selectedProductIds.length;

  void _selectAllOrderProducts() {
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(_orderProducts.map((product) => product.id));
    });
  }

  void _selectLowStockOrderProducts() {
    final lowStockIds = _orderProducts
        .where((product) => product.stockQty <= product.lowStockThreshold)
        .map((product) => product.id);
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(lowStockIds);
    });
  }

  void _clearOrderProducts() {
    setState(_selectedProductIds.clear);
  }

  void _addSupplier() {
    if (!_supplierFormKey.currentState!.validate()) return;

    final supplier = _SupplierInfo(
      name: _supplierNameController.text.trim(),
      contact: _supplierContactController.text.trim(),
      email: _supplierEmailController.text.trim(),
      address: _supplierAddressController.text.trim(),
      leadTime: _supplierLeadTimeController.text.trim().isEmpty
          ? 'Not set'
          : _supplierLeadTimeController.text.trim(),
      terms: _supplierTermsController.text.trim().isEmpty
          ? 'Not set'
          : _supplierTermsController.text.trim(),
    );

    setState(() {
      _suppliers.add(supplier);
      _selectedSupplier = _suppliers.length - 1;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
    _saveSuppliers();
  }

  void _startEditSupplier(int index) {
    final supplier = _suppliers[index];
    setState(() {
      _editingSupplierIndex = index;
      _supplierNameController.text = supplier.name;
      _supplierContactController.text = supplier.contact;
      _supplierEmailController.text = supplier.email;
      _supplierAddressController.text = supplier.address;
      _supplierLeadTimeController.text =
          supplier.leadTime == 'Not set' ? '' : supplier.leadTime;
      _supplierTermsController.text =
          supplier.terms == 'Not set' ? '' : supplier.terms;
    });
  }

  void _cancelEditSupplier() {
    setState(() {
      _editingSupplierIndex = null;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
  }

  void _submitSupplierForm() {
    if (_editingSupplierIndex != null) {
      _updateSupplier(_editingSupplierIndex!);
      return;
    }
    _addSupplier();
  }

  void _updateSupplier(int index) {
    if (!_supplierFormKey.currentState!.validate()) return;

    final updated = _SupplierInfo(
      name: _supplierNameController.text.trim(),
      contact: _supplierContactController.text.trim(),
      email: _supplierEmailController.text.trim(),
      address: _supplierAddressController.text.trim(),
      leadTime: _supplierLeadTimeController.text.trim().isEmpty
          ? 'Not set'
          : _supplierLeadTimeController.text.trim(),
      terms: _supplierTermsController.text.trim().isEmpty
          ? 'Not set'
          : _supplierTermsController.text.trim(),
    );

    setState(() {
      _suppliers[index] = updated;
      _selectedSupplier = index;
      _editingSupplierIndex = null;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
    _saveSuppliers();
  }

  void _deleteSupplier(int index) {
    setState(() {
      _suppliers.removeAt(index);
      if (_editingSupplierIndex == index) {
        _editingSupplierIndex = null;
        _supplierNameController.clear();
        _supplierContactController.clear();
        _supplierEmailController.clear();
        _supplierAddressController.clear();
        _supplierLeadTimeController.clear();
        _supplierTermsController.clear();
      } else if (_editingSupplierIndex != null &&
          _editingSupplierIndex! > index) {
        _editingSupplierIndex = _editingSupplierIndex! - 1;
      }
      _selectedSupplier = _suppliers.isEmpty
          ? 0
          : _selectedSupplier.clamp(0, _suppliers.length - 1);
    });
    _saveSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_suppliersPrefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      final loaded = parsed
          .whereType<Map>()
          .map((e) => _SupplierInfo.fromMap(Map<String, dynamic>.from(e)))
          .where((supplier) => !_starterSupplierNames.contains(
                supplier.name.trim().toLowerCase(),
              ))
          .toList();
      if (loaded.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _suppliers = loaded;
        _selectedSupplier = _selectedSupplier.clamp(0, _suppliers.length - 1);
      });
      if (loaded.length != parsed.length) {
        await _saveSuppliers();
      }
    } catch (_) {
      // Ignore malformed cached data and keep the supplier list empty.
    }
  }

  Future<void> _saveSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_suppliers.map((s) => s.toMap()).toList());
    await prefs.setString(_suppliersPrefsKey, payload);
  }

  Future<void> _prepareAndSendOrder() async {
    final lines = _selectedOrderLines();
    if (lines.isEmpty) {
      AppNotice.show(
        context,
        'Select at least one product and enter quantity.',
        type: AppNoticeType.error,
      );
      return;
    }

    final supplier = _suppliers[_selectedSupplier];
    final message = StringBuffer()
      ..writeln('Order Request')
      ..writeln('Items:');
    for (final line in lines) {
      message.writeln('- ${line.product.name}: ${line.qty}');
    }
    message.writeln('Total Items: ${lines.length}');
    message.writeln('Total Quantity: ${lines.fold<int>(
      0,
      (sum, line) => sum + line.qty,
    )}');

    final bodyText = message.toString().trim();
    final normalizedPhone = supplier.contact.replaceAll(RegExp(r'[^\d+]'), '');
    final whatsappPhone = normalizedPhone.startsWith('+')
        ? normalizedPhone.substring(1)
        : normalizedPhone;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Send Supplier Order',
          style: TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier.name,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bodyText,
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              mouseCursor: SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 18,
              ),
              title: Text(
                'WhatsApp ${supplier.contact}',
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final opened = await _openExternal(
                  Uri.parse(
                    'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(bodyText)}',
                  ),
                );
                if (opened) {
                  _showOrderPlacedNotification(
                    channel: 'WhatsApp',
                    lines: lines,
                    supplier: supplier,
                  );
                }
              },
            ),
            ListTile(
              mouseCursor: SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.commentSms,
                color: NovaColors.violet,
                size: 18,
              ),
              title: Text(
                'SMS ${supplier.contact}',
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final opened = await _openExternal(
                  Uri.parse(
                    'sms:$normalizedPhone?body=${Uri.encodeComponent(bodyText)}',
                  ),
                );
                if (opened) {
                  _showOrderPlacedNotification(
                    channel: 'SMS',
                    lines: lines,
                    supplier: supplier,
                  );
                }
              },
            ),
            ListTile(
              mouseCursor: supplier.email.isEmpty
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.google,
                color: Color(0xFFEA4335),
                size: 18,
              ),
              title: Text(
                supplier.email.isEmpty ? 'Email not provided' : supplier.email,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: supplier.email.isEmpty
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      final gmailUri = Uri.https(
                        'mail.google.com',
                        '/mail/',
                        {
                          'view': 'cm',
                          'fs': '1',
                          'to': supplier.email,
                          'su': 'Supplier order request',
                          'body': bodyText,
                        },
                      );
                      final opened = await _openExternal(
                        gmailUri,
                      );
                      if (opened) {
                        _showOrderPlacedNotification(
                          channel: 'Email',
                          lines: lines,
                          supplier: supplier,
                        );
                      }
                    },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: NovaColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _createOrderReference() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final tail = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'PO-$datePart-$timePart-$tail';
  }

  void _showOrderPlacedNotification({
    required String channel,
    required List<_SupplierOrderLine> lines,
    required _SupplierInfo supplier,
  }) {
    if (!mounted) return;
    final orderRef = _createOrderReference();
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.qty);
    AppNotice.show(
      context,
      'Order placed [$orderRef] via $channel: ${lines.length} item(s), $totalQty qty to ${supplier.name}.',
      type: AppNoticeType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<bool> _openExternal(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppNotice.show(
        context,
        'Could not open this app on device.',
        type: AppNoticeType.error,
      );
    }
    return opened;
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _suppliers.isEmpty ? null : _suppliers[_selectedSupplier];
    final lines = _selectedOrderLines();
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.qty);

    return Scaffold(
      backgroundColor: NovaColors.bgTertiary,
      appBar: AppBar(
        backgroundColor: NovaColors.violetDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Supplier Order',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white24),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OrderProductHeader(product: widget.product),
              const SizedBox(height: 14),
              _PanelCard(
                title: 'Products to Order',
                child: _SupplierOrderItemsList(
                  products: _orderProducts,
                  selectedProductIds: _selectedProductIds,
                  qtyControllers: _qtyControllers,
                  onSelectAll: _selectAllOrderProducts,
                  onSelectLowStock: _selectLowStockOrderProducts,
                  onClear: _clearOrderProducts,
                  onSelectionChanged: (product, selected) {
                    setState(() {
                      if (selected) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                      }
                    });
                  },
                  onQtyChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 14),
              _PanelCard(
                title: 'Supplier Details',
                child: _suppliers.isEmpty
                    ? const _MutedText(text: 'No suppliers yet. Add one below.')
                    : Column(
                        children: [
                          for (var i = 0; i < _suppliers.length; i++)
                            _SupplierOption(
                              supplier: _suppliers[i],
                              selected: i == _selectedSupplier,
                              onTap: () =>
                                  setState(() => _selectedSupplier = i),
                              onEdit: () => _startEditSupplier(i),
                              onDelete: () => _deleteSupplier(i),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _PanelCard(
                title: _editingSupplierIndex == null
                    ? 'Add Supplier'
                    : 'Edit Supplier',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _ManualSupplierForm(
                    formKey: _supplierFormKey,
                    nameController: _supplierNameController,
                    contactController: _supplierContactController,
                    emailController: _supplierEmailController,
                    addressController: _supplierAddressController,
                    leadTimeController: _supplierLeadTimeController,
                    termsController: _supplierTermsController,
                    onSubmit: _submitSupplierForm,
                    onCancel: _editingSupplierIndex == null
                        ? null
                        : _cancelEditSupplier,
                    submitLabel: _editingSupplierIndex == null
                        ? 'Add Supplier'
                        : 'Save Changes',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _PanelCard(
                title: 'Order',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    children: [
                      _OrderSummaryRow(
                        label: 'Supplier',
                        value: supplier?.name ?? 'None selected',
                      ),
                      _OrderSummaryRow(
                        label: 'Selected Items',
                        value: '$_selectedItemCount',
                      ),
                      _OrderSummaryRow(
                        label: 'Total Quantity',
                        value: '$totalQty',
                        strong: true,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: (lines.isEmpty || _suppliers.isEmpty)
                              ? null
                              : _prepareAndSendOrder,
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          label: const Text('Prepare Order'),
                          style: FilledButton.styleFrom(
                            backgroundColor: NovaColors.teal,
                            foregroundColor: Colors.white,
                          ).copyWith(
                            mouseCursor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.disabled)
                                  ? SystemMouseCursors.basic
                                  : SystemMouseCursors.click,
                            ),
                          ),
                        ),
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

class _SupplierInfo {
  const _SupplierInfo({
    required this.name,
    required this.contact,
    required this.email,
    required this.address,
    required this.leadTime,
    required this.terms,
  });

  final String name;
  final String contact;
  final String email;
  final String address;
  final String leadTime;
  final String terms;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'email': email,
      'address': address,
      'leadTime': leadTime,
      'terms': terms,
    };
  }

  factory _SupplierInfo.fromMap(Map<String, dynamic> data) {
    return _SupplierInfo(
      name: (data['name'] ?? '').toString(),
      contact: (data['contact'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      leadTime: (data['leadTime'] ?? 'Not set').toString(),
      terms: (data['terms'] ?? 'Not set').toString(),
    );
  }
}

class _SupplierOrderLine {
  const _SupplierOrderLine({
    required this.product,
    required this.qty,
  });

  final Product product;
  final int qty;
}

class _OrderProductHeader extends StatelessWidget {
  const _OrderProductHeader({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NovaColors.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(product.icon, color: NovaColors.tealDeep, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Stock ${product.stockQty} | Alert ${product.lowStockThreshold}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierOrderItemsList extends StatelessWidget {
  const _SupplierOrderItemsList({
    required this.products,
    required this.selectedProductIds,
    required this.qtyControllers,
    required this.onSelectAll,
    required this.onSelectLowStock,
    required this.onClear,
    required this.onSelectionChanged,
    required this.onQtyChanged,
  });

  final List<Product> products;
  final Set<String> selectedProductIds;
  final Map<String, TextEditingController> qtyControllers;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectLowStock;
  final VoidCallback onClear;
  final void Function(Product product, bool selected) onSelectionChanged;
  final VoidCallback onQtyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: LayoutBuilder(builder: (context, constraints) {
            final count = Text(
              '${selectedProductIds.length}/${products.length} selected',
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _SupplierBulkButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low stock',
                  color: NovaColors.amber,
                  onPressed: onSelectLowStock,
                ),
                _SupplierBulkButton(
                  icon: Icons.done_all_rounded,
                  label: 'All',
                  color: NovaColors.teal,
                  onPressed: onSelectAll,
                ),
                _SupplierBulkButton(
                  icon: Icons.clear_rounded,
                  label: 'Clear',
                  color: const Color(0xFFE53935),
                  onPressed: onClear,
                ),
              ],
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  count,
                  const SizedBox(height: 8),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                count,
                const SizedBox(width: 12),
                Expanded(child: actions),
              ],
            );
          }),
        ),
        for (var i = 0; i < products.length; i++) ...[
          _SupplierOrderItemRow(
            product: products[i],
            selected: selectedProductIds.contains(products[i].id),
            controller: qtyControllers[products[i].id]!,
            onSelected: (selected) =>
                onSelectionChanged(products[i], selected ?? false),
            onQtyChanged: onQtyChanged,
          ),
          if (i < products.length - 1)
            const Divider(height: 1, color: NovaColors.borderTertiary),
        ],
      ],
    );
  }
}

class _SupplierOrderItemRow extends StatelessWidget {
  const _SupplierOrderItemRow({
    required this.product,
    required this.selected,
    required this.controller,
    required this.onSelected,
    required this.onQtyChanged,
  });

  final Product product;
  final bool selected;
  final TextEditingController controller;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onQtyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: onSelected,
            mouseCursor: SystemMouseCursors.click,
            activeColor: NovaColors.teal,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stock ${product.stockQty} | Alert ${product.lowStockThreshold}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            height: 38,
            child: TextField(
              controller: controller,
              enabled: selected,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => onQtyChanged(),
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: _orderInputDecoration().copyWith(
                hintText: 'Qty',
                prefixIcon: null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierBulkButton extends StatelessWidget {
  const _SupplierBulkButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.08),
        side: BorderSide(color: color.withOpacity(0.32)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(74, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    );
  }
}

class _SupplierOption extends StatelessWidget {
  const _SupplierOption({
    required this.supplier,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final _SupplierInfo supplier;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? NovaColors.tealLight : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: NovaColors.borderTertiary),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? NovaColors.tealDeep : NovaColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${supplier.contact} | ${supplier.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supplier.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lead time: ${supplier.leadTime} | Terms: ${supplier.terms}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Edit supplier',
              mouseCursor: SystemMouseCursors.click,
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                color: NovaColors.textSecondary,
                size: 18,
              ),
            ),
            IconButton(
              tooltip: 'Delete supplier',
              mouseCursor: SystemMouseCursors.click,
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFB54724),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSupplierForm extends StatelessWidget {
  const _ManualSupplierForm({
    required this.formKey,
    required this.nameController,
    required this.contactController,
    required this.emailController,
    required this.addressController,
    required this.leadTimeController,
    required this.termsController,
    required this.onSubmit,
    this.onCancel,
    required this.submitLabel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController contactController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController leadTimeController;
  final TextEditingController termsController;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: LayoutBuilder(builder: (context, c) {
        final isCompact = c.maxWidth < AppBreakpoints.mobile;

        final fields = [
          _SupplierTextField(
            controller: nameController,
            label: 'Supplier Name',
            icon: Icons.storefront_outlined,
            requiredField: true,
          ),
          _SupplierTextField(
            controller: contactController,
            label: 'Contact Number',
            icon: Icons.phone_outlined,
            requiredField: true,
            keyboardType: TextInputType.phone,
          ),
          _SupplierTextField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return null;
              return email.contains('@') ? null : 'Enter a valid email';
            },
          ),
          _SupplierTextField(
            controller: addressController,
            label: 'Address',
            icon: Icons.location_on_outlined,
            requiredField: true,
          ),
          _SupplierTextField(
            controller: leadTimeController,
            label: 'Lead Time',
            icon: Icons.schedule_outlined,
          ),
          _SupplierTextField(
            controller: termsController,
            label: 'Payment Terms',
            icon: Icons.receipt_long_outlined,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isCompact)
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                fields[i],
              ]
            else ...[
              Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: fields[2]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[3]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: fields[4]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[5]),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCancel != null) ...[
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NovaColors.textSecondary,
                        side:
                            const BorderSide(color: NovaColors.borderSecondary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ).copyWith(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: Icon(
                      onCancel == null
                          ? Icons.add_business_outlined
                          : Icons.save_outlined,
                      size: 17,
                    ),
                    label: Text(submitLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: NovaColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ).copyWith(
                      mouseCursor:
                          WidgetStateProperty.all(SystemMouseCursors.click),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SupplierTextField extends StatelessWidget {
  const _SupplierTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.requiredField = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: NovaColors.textPrimary, fontSize: 13),
          validator: validator ??
              (requiredField
                  ? (value) => value == null || value.trim().isEmpty
                      ? '$label is required'
                      : null
                  : null),
          decoration: InputDecoration(
            hintText: label,
            hintStyle:
                const TextStyle(color: NovaColors.textTertiary, fontSize: 12),
            filled: true,
            fillColor: NovaColors.bgSecondary,
            prefixIcon: Icon(icon, color: NovaColors.textSecondary, size: 18),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: NovaColors.borderTertiary),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: NovaColors.teal),
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFD85A30)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFD85A30)),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _OrderSummaryRow extends StatelessWidget {
  const _OrderSummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: NovaColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: NovaColors.textPrimary,
                fontSize: strong ? 14 : 12,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _orderInputDecoration() => InputDecoration(
      hintText: 'Enter quantity',
      hintStyle: const TextStyle(color: NovaColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      prefixIcon: const Icon(Icons.inventory_2_outlined,
          color: NovaColors.textSecondary, size: 18),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.teal),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StockCell extends StatelessWidget {
  const _StockCell({required this.product, this.compact = false});
  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final threshold =
        product.lowStockThreshold <= 0 ? 1 : product.lowStockThreshold;
    final ratio = (product.stockQty / (threshold * 4)).clamp(0.0, 1.0);

    Color barColor;
    if (product.stockQty <= 0) {
      barColor = const Color(0xFFE53935); // red
    } else if (product.stockQty <= product.lowStockThreshold) {
      barColor = const Color(0xFFFB8C00); // orange
    } else {
      barColor = const Color(0xFF2E7D32); // green
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = compact ? 76.0 : 94.0;
        final cellWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : fallbackWidth;
        final qtyWidth = compact ? 34.0 : 40.0;
        final gap = compact ? 6.0 : 8.0;
        final barWidth = (cellWidth - qtyWidth - gap).clamp(20.0, 60.0);

        return SizedBox(
          width: constraints.hasBoundedWidth ? double.infinity : fallbackWidth,
          child: Row(
            children: [
              Container(
                width: barWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: NovaColors.bgSecondary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: qtyWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${product.stockQty}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      mouseCursor: SystemMouseCursors.click,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.value, this.emphasize = false});
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatMoney(value),
      style: TextStyle(
        color: emphasize && value < 0
            ? const Color(0xFFB54724)
            : emphasize
                ? NovaColors.tealDeep
                : NovaColors.textSecondary,
        fontSize: 12,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;

    if (product.stockQty <= 0) {
      label = 'Out of stock';
      bg = const Color(0xFFFFEDE8);
      fg = const Color(0xFFB54724);
    } else if (product.stockQty <= product.lowStockThreshold) {
      label = 'Low stock';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFEF6C00);
    } else {
      label = 'In stock';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 7, 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StockNotificationsPanel extends StatelessWidget {
  const _StockNotificationsPanel({required this.lowStock});
  final List<Product> lowStock;

  String _namesPreview(List<Product> items) {
    if (items.isEmpty) return '';
    final names = items.map((e) => e.name).toList();
    final shown = names.take(3).join(', ');
    final remaining = names.length - 3;
    if (remaining > 0) return '$shown +$remaining more';
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = lowStock.where((p) => p.stockQty <= 0).toList();
    final lowOnly = lowStock.where((p) => p.stockQty > 0).toList();

    return _PanelCard(
      title: 'Stock Notifications',
      child: lowStock.isEmpty
          ? const _MutedText(text: 'No stock notifications right now.')
          : Column(
              children: [
                if (outOfStock.isNotEmpty)
                  _ThinListItem(
                    icon: Icons.error_outline_rounded,
                    iconBg: const Color(0xFFFFEDE8),
                    iconColor: const Color(0xFFB54724),
                    title: 'Out of stock items',
                    subtitle:
                        '${outOfStock.length} product(s): ${_namesPreview(outOfStock)}',
                    trailing: Text(
                      '${outOfStock.length}',
                      style: const TextStyle(
                        color: Color(0xFFB54724),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (lowOnly.isNotEmpty)
                  _ThinListItem(
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFFFF3E0),
                    iconColor: const Color(0xFFEF6C00),
                    title: 'Low stock items',
                    subtitle:
                        '${lowOnly.length} product(s): ${_namesPreview(lowOnly)}',
                    trailing: Text(
                      '${lowOnly.length}',
                      style: const TextStyle(
                        color: Color(0xFFEF6C00),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.tx});
  final InventoryTransaction tx;

  @override
  Widget build(BuildContext context) {
    Color dot;
    switch (tx.type.toLowerCase()) {
      case 'sale':
        dot = const Color(0xFF378ADD);
        break;
      case 'adjustment':
        dot = NovaColors.amber;
        break;
      case 'restock':
      case 'purchase':
        dot = NovaColors.teal;
        break;
      case 'damage':
        dot = const Color(0xFFD85A30);
        break;
      default:
        dot = NovaColors.textTertiary;
    }

    final time =
        '${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tx.productName} • ${tx.type.toUpperCase()} • Qty ${tx.quantity}',
                  style: const TextStyle(
                      color: NovaColors.textPrimary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.previousStock} → ${tx.newStock} · $time',
                  style: const TextStyle(
                      color: NovaColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subText,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subText;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.actionText,
    this.onActionTap,
  });

  final String title;
  final Widget child;
  final String? actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actionText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: onActionTap,
                      mouseCursor: onActionTap == null
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        actionText!,
                        style: TextStyle(
                          color: onActionTap == null
                              ? NovaColors.textTertiary
                              : NovaColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: onActionTap == null
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: NovaColors.borderTertiary),
          child,
        ],
      ),
    );
  }
}

class _ThinListItem extends StatelessWidget {
  const _ThinListItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NovaColors.borderTertiary)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          trailing,
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NovaColors.bgTertiary,
      body: Center(
        child: CircularProgressIndicator(color: NovaColors.teal),
      ),
    );
  }
}
