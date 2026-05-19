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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Future<bool> _hasProducts(PocketBase pb) async {
    final existing = await pb.collection('products').getList(
          perPage: 1,
          filter: 'ownerId = "$ownerId"',
        );
    return existing.totalItems > 0;
  }

  Future<int> seed() async {
    try {
      final PocketBase pb = await _authService.initPb();

      if (await _hasProducts(pb)) {
        debugPrint('[Seeder] Products already exist — skipping.');
        return 0;
      }

      final raw = await rootBundle.loadString('assets/products.json');
      final List<dynamic> items = jsonDecode(raw);

      int count = 0;
      for (final item in items) {
        final name = item['title']?.toString().trim().isNotEmpty == true
            ? item['title'].toString().trim()
            : 'Unknown';
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        await pb.collection('products').create(body: {
          'name': name,
          'price': price,
          'category': _capitalize(item['type']?.toString() ?? 'Other'),
          'iconCodePoint': null,
          'imageUrl': '',
          'ownerId': ownerId,
        });
        count++;
        debugPrint(
          '[Seeder] ($count/${items.length}) $name (${_capitalize(item['type']?.toString() ?? 'Other')})',
        );
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
