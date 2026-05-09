// lib/core/utils/product_seeder.dart
//
// ONE-TIME USE: Seeds products from assets/products.json into PocketBase.
// Safe to leave in — skips automatically if products already exist.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pocketbase/auth_service.dart';

class ProductSeeder {
  final AuthService _authService;
  final String ownerId;

  ProductSeeder({required AuthService authService, required this.ownerId})
      : _authService = authService;

  static int _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'dairy' => 0xe25a,
      'fruit' => 0xe7ec,
      'vegetable' => 0xe7ec,
      'bakery' => 0xe1c7,
      'meat' => 0xe57a,
      'vegan' => 0xe408,
      _ => 0xe57a,
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Future<int> seed() async {
    try {
      final PocketBase pb = await _authService.initPb();

      // 1. Skip if already seeded — uses 'ownerId' to match ProductService filter
      final existing = await pb.collection('products').getList(
            filter: 'ownerId = "$ownerId"',
            perPage: 1,
          );
      if (existing.totalItems > 0) {
        debugPrint(
            '[Seeder] Already seeded (${existing.totalItems} found) — skipping.');
        return 0;
      }

      // 2. Load JSON from assets
      final raw = await rootBundle.loadString('assets/products.json');
      final List<dynamic> items = jsonDecode(raw);

      // 3. Insert using 'ownerId' — matches ProductService filter
      int count = 0;
      for (final item in items) {
        await pb.collection('products').create(body: {
          'name': item['title'] ?? 'Unknown',
          'price': (item['price'] as num).toDouble(),
          'category': _capitalize(item['type']?.toString() ?? 'Other'),
          'iconCodePoint': _iconForType(item['type']?.toString() ?? ''),
          'ownerId': ownerId, // ✅ matches ProductService filter
          'description': item['description'] ?? '',
        });
        count++;
        debugPrint('[Seeder] ($count/${items.length}) ${item['title']}');
      }

      debugPrint('[Seeder] ✅ Done — $count products inserted.');
      return count;
    } catch (e, st) {
      debugPrint('[Seeder] ❌ Error: $e');
      debugPrint('$st');
      return 0;
    }
  }
}
