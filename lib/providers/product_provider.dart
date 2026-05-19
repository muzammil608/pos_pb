import 'package:flutter/foundation.dart';
import '../services/pocketbase/product_service.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  late final ProductService _service;
  final List<Product> _products = [];
  bool _isLoading = false;
  final String ownerId;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  Stream<List<Product>> get productsStream => _service.streamProducts;

  ProductProvider(this.ownerId) {
    _service = ProductService(ownerId);
  }

  Future<String?> createProduct({
    required String name,
    required double price,
    required String category,
    int? iconCodePoint,
    int stockQty = 0,
    int lowStockThreshold = 5,
    int damagedQty = 0,
    String barcode = '',
  }) async {
    setLoading(true);
    try {
      final result = await _service.createProduct(
        name: name,
        price: price,
        category: category,
        iconCodePoint: iconCodePoint,
        stockQty: stockQty,
        lowStockThreshold: lowStockThreshold,
        damagedQty: damagedQty,
        barcode: barcode,
      );
      notifyListeners();
      return result;
    } finally {
      setLoading(false);
    }
  }

  Future<String?> updateProduct({
    required String id,
    required String name,
    required double price,
    required String category,
    int? iconCodePoint,
    int? stockQty,
    int? lowStockThreshold,
    int? damagedQty,
    String? barcode,
  }) async {
    setLoading(true);
    try {
      final result = await _service.updateProduct(
        id: id,
        name: name,
        price: price,
        category: category,
        iconCodePoint: iconCodePoint,
        stockQty: stockQty,
        lowStockThreshold: lowStockThreshold,
        damagedQty: damagedQty,
        barcode: barcode,
      );
      notifyListeners();
      return result;
    } finally {
      setLoading(false);
    }
  }

  Future<String?> deleteProduct(String id) async {
    setLoading(true);
    try {
      final result = await _service.deleteProduct(id);
      notifyListeners();
      return result;
    } finally {
      setLoading(false);
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
