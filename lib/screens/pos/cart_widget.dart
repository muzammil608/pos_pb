import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cart.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Cart is empty',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.items.length,
            itemBuilder: (_, i) {
              final item = cart.items[i];
              final price =
                  (item['unitPrice'] ?? item['price'])?.toString() ?? '0';
              final qty = (item['qty'] as num?)?.toInt() ?? 1;

              return ListTile(
                title: Text(item['name']?.toString() ?? 'Item'),
                subtitle: Text('Rs $price  ×$qty'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final id = item['cartDocId']?.toString();
                    if (id != null && id.isNotEmpty) {
                      cart.removeItem(id);
                    }
                  },
                ),
              );
            },
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'Rs ${cart.total.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
