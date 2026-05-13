import 'package:flutter/material.dart';
import '../services/pocketbase/order_service.dart';
import 'cart_provider.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService;
  final String ownerId;

  OrderProvider(this.ownerId) : _orderService = OrderService(ownerId);

  Future<void> placeOrder({
    required CartProvider cart,
    String orderType = 'takeaway',
    String? tableNumber,
  }) async {
    await _orderService.createOrder(
      items: cart.items,
      total: cart.total,
      orderType: orderType,
      tableNumber: tableNumber,
    );

    cart.clear();
  }
}
