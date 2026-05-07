import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (_, i) {
              final item = cart.items[i];

              return ListTile(
                title: Text(item['name'].toString()),
                subtitle: Text("Rs ${item['unitPrice'] ?? item['price']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    final id = item['cartDocId'];
                    if (id != null) {
                      cart.removeItem(id);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const Divider(),
        Text(
          "Total: Rs ${cart.total.toStringAsFixed(0)}",
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}
