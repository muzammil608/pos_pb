import 'package:pocketbase/pocketbase.dart';

class InventoryTransaction {
  final String id;
  final String productId;
  final String productName;
  final String type; // 'sale' | 'restock' | 'adjustment' | 'damage'
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? note;
  final String? orderId;
  final DateTime createdAt;

  InventoryTransaction({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.note,
    this.orderId,
    required this.createdAt,
  });

  factory InventoryTransaction.fromRecord(RecordModel record) {
    return InventoryTransaction(
      id: record.id,
      productId: record.getStringValue('productId'),
      productName: record.getStringValue('productName'),
      type: record.getStringValue('type'),
      quantity: _readInt(record.data['quantity']) ?? 0,
      previousStock: _readInt(record.data['previousStock']) ?? 0,
      newStock: _readInt(record.data['newStock']) ?? 0,
      note: record.getStringValue('note').isEmpty
          ? null
          : record.getStringValue('note'),
      orderId: record.getStringValue('orderId').isEmpty
          ? null
          : record.getStringValue('orderId'),
      createdAt:
          DateTime.tryParse(record.getStringValue('created')) ?? DateTime.now(),
    );
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
