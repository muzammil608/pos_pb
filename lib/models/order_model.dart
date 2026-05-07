import 'package:pocketbase/pocketbase.dart';

class Order {
  final String id;
  final int orderNumber;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final DateTime createdAt;
  final String orderType;
  final String? tableNumber;
  final String? ownerId;
  final String? customerName;
  final String? paymentMethod;
  final double tenderedAmount;
  final double change;
  final String? createdBy;

  Order({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.orderType,
    this.tableNumber,
    this.ownerId,
    this.customerName,
    this.paymentMethod = 'cash',
    this.tenderedAmount = 0.0,
    this.change = 0.0,
    this.createdBy,
  });

  factory Order.fromRecord(RecordModel record) {
    // Items stored as JSON array in PocketBase
    List<Map<String, dynamic>> items = [];
    final rawItems = record.data['items'];
    if (rawItems is List) {
      items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return Order(
      id: record.id,
      orderNumber: (record.data['orderNumber'] as num?)?.toInt() ?? 0,
      items: items,
      total: record.getDoubleValue('total'),
      status: record.getStringValue('status').isEmpty
          ? 'pending'
          : record.getStringValue('status'),
      createdAt:
          DateTime.tryParse(record.getStringValue('created')) ?? DateTime.now(),
      orderType: record.getStringValue('orderType').isEmpty
          ? 'takeaway'
          : record.getStringValue('orderType'),
      tableNumber: record.getStringValue('tableNumber').isEmpty
          ? null
          : record.getStringValue('tableNumber'),
      ownerId: record.getStringValue('ownerId').isEmpty
          ? null
          : record.getStringValue('ownerId'),
      customerName: record.getStringValue('customerName').isEmpty
          ? null
          : record.getStringValue('customerName'),
      paymentMethod: record.getStringValue('paymentMethod').isEmpty
          ? 'cash'
          : record.getStringValue('paymentMethod'),
      tenderedAmount: record.getDoubleValue('tenderedAmount'),
      change: record.getDoubleValue('change'),
      createdBy: record.getStringValue('createdBy').isEmpty
          ? null
          : record.getStringValue('createdBy'),
    );
  }

  factory Order.fromMap(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      orderNumber: (data['orderNumber'] as num?)?.toInt() ?? 0,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      orderType: data['orderType']?.toString() ?? 'takeaway',
      tableNumber: data['tableNumber']?.toString(),
      ownerId: data['ownerId'],
      customerName: data['customerName'],
      paymentMethod: data['paymentMethod'] ?? 'cash',
      tenderedAmount: (data['tenderedAmount'] as num?)?.toDouble() ?? 0.0,
      change: (data['change'] as num?)?.toDouble() ?? 0.0,
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'orderType': orderType,
      'orderNumber': orderNumber,
      'paymentMethod': paymentMethod ?? 'cash',
      'tenderedAmount': tenderedAmount,
      'change': change,
      if (tableNumber != null) 'tableNumber': tableNumber,
      if (ownerId != null) 'ownerId': ownerId,
      if (customerName != null) 'customerName': customerName,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}

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
