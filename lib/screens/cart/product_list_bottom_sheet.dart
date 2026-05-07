import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/pocketbase/product_service.dart';

class _CafeColors {
  static const Color flame = Color(0xFFFF4D1C);
  // static const Color amber = Color(0xFFFFA724);
  static const Color espresso = Color(0xFF1E0F00);
  // static const Color latte = Color(0xFFFFF3E8);
  static const Color creme = Color(0xFFFFE4C4);
  static const Color charcoal = Color(0xFF2C2C2C);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFFF4D1C), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProductListBottomSheet extends StatelessWidget {
  const ProductListBottomSheet({super.key});

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
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final productService = ProductService(auth.ownerId);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: _CafeColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _CafeColors.flame.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Add Items',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: StreamBuilder(
              stream: productService.streamProducts,
              builder: (context, snapshot) {
                // Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _CafeColors.flame,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }

                // Empty / error
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: _CafeColors.creme,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                size: 36, color: _CafeColors.flame),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No products available',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _CafeColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data!;

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final name = product.name;

                    return GestureDetector(
                      onTap: () {
                        cart.addItem({
                          'id': product.id,
                          ...product.toMap(),
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _CafeColors.flame.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _CafeColors.flame.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _itemAccentGradient(name),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  _itemEmoji(name),
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _CafeColors.espresso,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: _CafeColors.headerGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Rs ${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
            ),
          ),
        ],
      ),
    );
  }
}
