import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../core/utils/icon_helper.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String? imageUrl;
  final int? iconCodePoint;
  final String? ownerId;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.iconCodePoint,
    this.ownerId,
  });

  /// Get the icon for this product (custom or default based on category)
  IconData get icon {
    if (iconCodePoint != null) {
      return IconHelper.fromCodePoint(iconCodePoint!);
    }
    return IconHelper.getDefaultIcon(category);
  }

  /// Create from PocketBase RecordModel
  factory Product.fromRecord(RecordModel record, {String? pbBaseUrl}) {
    final rawName = record.getStringValue('name');
    final rawCategory = record.getStringValue('category');

    final String name =
        rawName.trim().isEmpty ? 'Unnamed Product' : rawName.trim();
    final double price = record.getDoubleValue('price');
    final String category =
        rawCategory.trim().isEmpty ? 'Other' : rawCategory.trim();

    // Handle icon code point
    int? parsedIconCodePoint;
    final iconRaw = record.data['iconCodePoint'];
    if (iconRaw != null) {
      if (iconRaw is int) {
        parsedIconCodePoint = iconRaw;
      } else if (iconRaw is String) {
        parsedIconCodePoint = int.tryParse(iconRaw);
      }
    }

    // Build image URL from PocketBase file field
    String? imageUrl;
    final imageField = record.getStringValue('image');
    if (imageField.isNotEmpty && pbBaseUrl != null) {
      imageUrl =
          '$pbBaseUrl/api/files/${record.collectionId}/${record.id}/$imageField';
    } else if (record.data['imageUrl'] != null) {
      imageUrl = record.data['imageUrl']?.toString();
    }

    return Product(
      id: record.id,
      name: name,
      price: price,
      category: category,
      imageUrl: imageUrl,
      iconCodePoint: parsedIconCodePoint,
      ownerId: record.getStringValue('ownerId'),
    );
  }

  /// Legacy: Create from plain Map (kept for compatibility)
  factory Product.fromMap(Map<String, dynamic> data, String id) {
    final rawName = data['name'] ?? data['productName'] ?? data['title'];
    final rawPrice = data['price'] ?? data['unitPrice'] ?? data['amount'];
    final rawCategory = data['category'] ?? data['type'];

    final parsedName = rawName?.toString().trim() ?? '';
    final parsedCategory = rawCategory?.toString().trim() ?? '';

    final double? numericPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');

    final String name = parsedName.isEmpty ? 'Unnamed Product' : parsedName;
    final double price = numericPrice ?? 0.0;
    final String category = parsedCategory.isEmpty ? 'Other' : parsedCategory;

    int? parsedIconCodePoint;
    if (data['iconCodePoint'] != null) {
      if (data['iconCodePoint'] is int) {
        parsedIconCodePoint = data['iconCodePoint'] as int;
      } else if (data['iconCodePoint'] is String) {
        parsedIconCodePoint = int.tryParse(data['iconCodePoint'] as String);
      }
    }

    return Product(
      id: id,
      name: name,
      price: price,
      category: category,
      imageUrl: data['imageUrl']?.toString(),
      iconCodePoint: parsedIconCodePoint,
      ownerId: data['ownerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
      if (ownerId != null) 'ownerId': ownerId,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    String? imageUrl,
    int? iconCodePoint,
    String? ownerId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}
