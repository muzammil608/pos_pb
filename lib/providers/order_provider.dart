import 'package:flutter/material.dart';
import '../services/pocketbase/order_service.dart';
import 'cart_provider.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService;
  final String ownerId;

  OrderProvider(this.ownerId) : _orderService = OrderService(ownerId);

  Future<void> placeOrder({
    required CartProvider cart,
    String orderType = 'dine_in',
    String? tableNumber,
  }) async {
    await _orderService.createOrder(
      items: cart.items,
      total: cart.total,
      status: 'ready',
      orderType: orderType,
      tableNumber: tableNumber,
    );

    cart.clear();
    notifyListeners();
  }
}
