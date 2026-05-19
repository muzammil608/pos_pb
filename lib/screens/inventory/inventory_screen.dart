// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
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
        if (auth.user == null) {
          return const _LoadingScaffold();
        }

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
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: NovaColors.bgPrimary,
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme:
                      const IconThemeData(color: NovaColors.textSecondary),
                  titleSpacing: 8,
                  title: const Text(
                    'Inventory Dashboard',
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0.5),
                    child: Container(
                        height: 0.5, color: NovaColors.borderTertiary),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded,
                          color: NovaColors.textSecondary, size: 20),
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
          body: Center(
            child: Container(
              width: double.infinity,
              alignment: Alignment.topCenter,
              child: AppNavigationShell(
                auth: auth,
                currentRoute: '/inventory',
                child: ResponsiveCenter(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: _InventoryBody(
                    service: _service!,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _InventoryBody extends StatefulWidget {
  const _InventoryBody({required this.service});

  final InventoryService service;

  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody> {
  late Future<List<dynamic>> _future;

  Future<List<dynamic>> _loadData() => Future.wait([
        widget.service.getSummary(),
        widget.service.getProducts(),
      ]);

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  void _refresh() {
    final next = _loadData();
    if (!mounted) return;
    setState(() {
      _future = next;
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
            child: CircularProgressIndicator(color: NovaColors.teal),
          );
        }

        final summary = snapshot.data![0] as InventorySummary;
        final products = snapshot.data![1] as List<Product>;

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
              _MetricsGrid(summary: summary, products: products),
              const SizedBox(height: 14),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _InventoryTablePanel(
                        products: products,
                        categories: categories,
                        service: widget.service,
                        onMutated: _refresh,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SidePanels(
                        lowStock: lowStock,
                        txStream: widget.service.streamTransactions(),
                        service: widget.service,
                        onMutated: _refresh,
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                )
              else if (isTablet)
                Column(
                  children: [
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
                      service: widget.service,
                      onMutated: _refresh,
                      isTablet: true,
                    ),
                  ],
                )
              else
                Column(
                  children: [
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
                      service: widget.service,
                      onMutated: _refresh,
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

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.totalProducts,
    required this.onRefresh,
  });

  final int totalProducts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < AppBreakpoints.mobile;

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
            ),
          ),
          const SizedBox(width: 8),
          _HeaderGhostButton(icon: Icons.download_rounded, label: 'Export'),
        ],
      );

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleCol,
            const SizedBox(height: 10),
            actions,
          ],
        );
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [titleCol, actions],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics Grid
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary, required this.products});

  final InventorySummary summary;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final out = products.where((p) => p.stockQty <= 0).length;

    final cards = [
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

    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;

      final columns = width >= AppBreakpoints.desktop
          ? 4
          : width >= AppBreakpoints.mobile
              ? 2
              : 2;

      final aspectRatio = width >= AppBreakpoints.desktop
          ? 2.25
          : width >= AppBreakpoints.mobile
              ? 2.0
              : 1.8;

      return GridView.count(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspectRatio,
        children: cards,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inventory Table Panel
// ─────────────────────────────────────────────────────────────────────────────

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

  // ── NEW: search query ──
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    // ── CHANGED: removed .take(20) — show ALL filtered products ──
    final visible = _filtered;

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < AppBreakpoints.mobile;

      // ── CHANGED: no hard cap — height scales with all rows, max 600 ──
      final double contentHeight = (visible.length * 60.0).clamp(200.0, 600.0);

      return Container(
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Panel header ──
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

            // ── NEW: Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                      color: NovaColors.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, barcode or category…',
                    hintStyle: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: NovaColors.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close_rounded,
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

            // ── Content ──
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
                  ),
                ),
              )
            else
              SizedBox(
                height: contentHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      // Ensure table fills the panel width on wide screens
                      constraints: BoxConstraints(minWidth: c.maxWidth - 2),
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 60,
                        columnSpacing: 24,
                        horizontalMargin: 14,
                        headingTextStyle: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        columns: const [
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('Reorder At')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: visible.map((p) {
                          return DataRow(cells: [
                            DataCell(
                              SizedBox(
                                width: 180,
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
                                width: 100,
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
                            DataCell(_StockCell(product: p)),
                            DataCell(Text(
                              '${p.lowStockThreshold}',
                              style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  fontSize: 12),
                            )),
                            DataCell(_StatusPill(product: p)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Restock',
                                  icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 18,
                                      color: NovaColors.teal),
                                  onPressed: () =>
                                      _showRestockDialog(context, p),
                                ),
                                IconButton(
                                  tooltip: 'Adjust stock',
                                  icon: const Icon(Icons.tune_rounded,
                                      size: 18,
                                      color: NovaColors.textSecondary),
                                  onPressed: () =>
                                      _showAdjustDialog(context, p),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Footer ──
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

  // ── Restock dialog ──────────────────────────────────────────────────────

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
              Text(
                'Current stock: ${p.stockQty}',
                style: const TextStyle(
                    color: NovaColors.textSecondary, fontSize: 12),
              ),
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
                foregroundColor: Colors.white),
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
        if (mounted) widget.onMutated();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restock failed: $e')),
          );
        }
      }
    }
  }

  // ── Adjust dialog ───────────────────────────────────────────────────────

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
              Text(
                'Current stock: ${p.stockQty}',
                style: const TextStyle(
                    color: NovaColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter +10 to add, -5 to remove.',
                style: TextStyle(color: NovaColors.textTertiary, fontSize: 11),
              ),
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
                foregroundColor: Colors.white),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Adjustment failed: $e')),
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

// ─────────────────────────────────────────────────────────────────────────────
// Mobile product card list
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCardList extends StatelessWidget {
  const _ProductCardList({
    required this.products,
    required this.onRestock,
    required this.onAdjust,
  });

  final List<Product> products;
  final void Function(Product) onRestock;
  final void Function(Product) onAdjust;

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
              // Left: name + barcode + status + stock
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(product: p),
                        const SizedBox(width: 8),
                        _StockCell(product: p),
                      ],
                    ),
                  ],
                ),
              ),
              // Right: action buttons — vertically centered
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Restock',
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 20, color: NovaColors.teal),
                    onPressed: () => onRestock(p),
                  ),
                  IconButton(
                    tooltip: 'Adjust',
                    icon: const Icon(Icons.tune_rounded,
                        size: 20, color: NovaColors.textSecondary),
                    onPressed: () => onAdjust(p),
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

// ─────────────────────────────────────────────────────────────────────────────
// Side Panels
// ─────────────────────────────────────────────────────────────────────────────

class _SidePanels extends StatelessWidget {
  const _SidePanels({
    required this.lowStock,
    required this.txStream,
    required this.service,
    required this.onMutated,
    required this.isTablet,
  });

  final List<Product> lowStock;
  final Stream<List<InventoryTransaction>> txStream;
  final InventoryService service;
  final VoidCallback onMutated;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final alertsPanel = _PanelCard(
      title: 'Reorder Alerts',
      actionText: 'View all',
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
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await service.restock(
                          productId: p.id,
                          productName: p.name,
                          quantity: 1,
                          note: 'Quick reorder from alert',
                        );
                        onMutated();
                      } catch (_) {}
                    },
                    child: const Text('Order', style: TextStyle(fontSize: 11)),
                  ),
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
          if (txs.isEmpty) {
            return const _MutedText(text: 'No recent inventory activity.');
          }
          return Column(
            children: txs.take(8).map((tx) => _ActivityItem(tx: tx)).toList(),
          );
        },
      ),
    );

    if (isTablet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: alertsPanel),
          const SizedBox(width: 12),
          Expanded(child: activityPanel),
        ],
      );
    }

    return Column(
      children: [
        alertsPanel,
        const SizedBox(height: 12),
        activityPanel,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StockCell extends StatelessWidget {
  const _StockCell({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final threshold =
        product.lowStockThreshold <= 0 ? 1 : product.lowStockThreshold;
    final ratio = (product.stockQty / (threshold * 4)).clamp(0.0, 1.0);

    Color barColor;
    if (product.stockQty <= 0) {
      barColor = const Color(0xFFD85A30);
    } else if (product.stockQty <= product.lowStockThreshold) {
      barColor = NovaColors.violet;
    } else {
      barColor = NovaColors.teal;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
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
        const SizedBox(width: 8),
        Text(
          '${product.stockQty}',
          style: const TextStyle(color: NovaColors.textPrimary, fontSize: 12),
        ),
      ],
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
      bg = NovaColors.violetLight;
      fg = NovaColors.violetDeep;
    } else {
      label = 'In stock';
      bg = NovaColors.tealLight;
      fg = NovaColors.tealDeep;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
        mainAxisAlignment: MainAxisAlignment.center,
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

class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: NovaColors.borderSecondary),
        foregroundColor: NovaColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.actionText,
  });

  final String title;
  final Widget child;
  final String? actionText;

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
                    child: Text(
                      actionText!,
                      style: const TextStyle(
                        color: NovaColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
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
