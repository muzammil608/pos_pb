import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CartProvider with ChangeNotifier {
  final _uuid = const Uuid();
  final List<Map<String, dynamic>> _items = [];

  bool _disposed = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  double get total => _items.fold(
        0.0,
        (sum, item) {
          final qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          return sum + (qty * price);
        },
      );

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> addItem(Map<String, dynamic> product) async {
    if (_disposed) return;

    final qty = (product['qty'] as num?)?.toInt() ?? 1;
    final productId = product['id']?.toString() ?? _uuid.v4();

    final existingIndex =
        _items.indexWhere((item) => item['productId'] == productId);

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];

      final newQty = ((existing['qty'] as num?)?.toInt() ?? 1) + qty;

      final price = (existing['price'] as num?)?.toDouble() ?? 0.0;

      _items[existingIndex] = {
        ...existing,
        'qty': newQty,
        'quantity': newQty,
        'lineTotal': price * newQty,
      };
    } else {
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;

      _items.add({
        'cartDocId': _uuid.v4(),
        'productId': productId,
        'name': product['name'] as String? ?? 'Unknown',
        'price': price,
        'unitPrice': price,
        'qty': qty,
        'quantity': qty,
        'lineTotal': price * qty,
      });
    }

    _safeNotify();
  }

  Future<void> removeItem(String cartDocId) async {
    if (_disposed) return;

    _items.removeWhere((item) => item['cartDocId'] == cartDocId);

    _safeNotify();
  }

  Future<void> updateItemQuantity(String cartDocId, int qty) async {
    if (_disposed) return;

    if (qty <= 0) {
      await removeItem(cartDocId);
      return;
    }

    final index = _items.indexWhere((item) => item['cartDocId'] == cartDocId);

    if (index < 0) return;

    final item = _items[index];

    final price = (item['price'] as num?)?.toDouble() ?? 0.0;

    _items[index] = {
      ...item,
      'qty': qty,
      'quantity': qty,
      'lineTotal': price * qty,
    };

    _safeNotify();
  }

  Future<void> clear() async {
    if (_disposed) return;

    _items.clear();

    _safeNotify();
  }

  bool get isLoggedIn => true;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clearCart() {}
}
