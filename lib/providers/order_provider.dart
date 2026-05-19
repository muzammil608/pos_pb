import 'package:flutter/material.dart';
import '../services/pocketbase/inventory_service.dart';
import '../services/pocketbase/order_service.dart';
import 'cart_provider.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService;
  final InventoryService _inventoryService;
  final String ownerId;

  OrderProvider(this.ownerId)
      : _orderService = OrderService(ownerId),
        _inventoryService = InventoryService(ownerId);

  Future<void> placeOrder({
    required CartProvider cart,
    String orderType = 'takeaway',
    String? tableNumber,
  }) async {
    final order = await _orderService.createOrder(
      items: cart.items,
      total: cart.total,
      orderType: orderType,
      tableNumber: tableNumber,
    );

    await _inventoryService.applySaleDeductions(
      orderId: order.id,
      items: cart.items,
    );

    cart.clear();
    notifyListeners();
  }
}
