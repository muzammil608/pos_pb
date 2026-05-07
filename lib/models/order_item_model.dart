class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}
