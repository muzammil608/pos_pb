import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class PosHeaderSlide {
  final String id;
  final String ownerId;
  final String badge;
  final String title;
  final String subtitle;
  final Color startColor;
  final Color middleColor;
  final Color endColor;
  final int sortOrder;
  final bool isActive;

  const PosHeaderSlide({
    this.id = '',
    required this.ownerId,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.startColor,
    required this.middleColor,
    required this.endColor,
    required this.sortOrder,
    this.isActive = true,
  });

  factory PosHeaderSlide.fromRecord(RecordModel record) {
    return PosHeaderSlide(
      id: record.id,
      ownerId: record.getStringValue('ownerId'),
      badge: record.getStringValue('badge'),
      title: record.getStringValue('title'),
      subtitle: record.getStringValue('subtitle'),
      startColor: colorFromHex(record.getStringValue('startColor'), 0xFF3A1C00),
      middleColor:
          colorFromHex(record.getStringValue('middleColor'), 0xFF7A3300),
      endColor: colorFromHex(record.getStringValue('endColor'), 0xFFC45C00),
      sortOrder: record.getIntValue('sortOrder'),
      isActive: record.data.containsKey('isActive')
          ? record.getBoolValue('isActive')
          : true,
    );
  }

  factory PosHeaderSlide.fromMap(Map<String, dynamic> data) {
    return PosHeaderSlide(
      id: _readString(data['id']),
      ownerId: _readString(data['ownerId']),
      badge: _readString(data['badge']),
      title: _readString(data['title']),
      subtitle: _readString(data['subtitle']),
      startColor: colorFromHex(_readString(data['startColor']), 0xFF3A1C00),
      middleColor: colorFromHex(_readString(data['middleColor']), 0xFF7A3300),
      endColor: colorFromHex(_readString(data['endColor']), 0xFFC45C00),
      sortOrder: _readInt(data['sortOrder']),
      isActive: _readBool(data['isActive'], fallback: true),
    );
  }

  static List<PosHeaderSlide> defaults(String ownerId) {
    return [
      PosHeaderSlide(
        ownerId: ownerId,
        badge: "TODAY'S SPECIAL",
        title: 'Grilled Chicken Platter',
        subtitle: 'Served with garlic bread & fresh salad',
        startColor: const Color(0xFF3A1C00),
        middleColor: const Color(0xFF7A3300),
        endColor: const Color(0xFFC45C00),
        sortOrder: 0,
      ),
      PosHeaderSlide(
        ownerId: ownerId,
        badge: 'NEW ARRIVAL',
        title: 'Signature Pasta Bowl',
        subtitle: 'Creamy alfredo with sun-dried tomatoes',
        startColor: const Color(0xFF002244),
        middleColor: const Color(0xFF004488),
        endColor: const Color(0xFF006699),
        sortOrder: 1,
      ),
      PosHeaderSlide(
        ownerId: ownerId,
        badge: 'HAPPY HOUR',
        title: 'Fresh Juices & Mocktails',
        subtitle: '30% off from 3 PM - 6 PM daily',
        startColor: const Color(0xFF1A3A00),
        middleColor: const Color(0xFF2D6600),
        endColor: const Color(0xFF3D8C00),
        sortOrder: 2,
      ),
      PosHeaderSlide(
        ownerId: ownerId,
        badge: 'DESSERT',
        title: 'Chocolate Lava Cake',
        subtitle: 'Warm, gooey & made fresh - limited stock',
        startColor: const Color(0xFF3A0020),
        middleColor: const Color(0xFF7A003A),
        endColor: const Color(0xFFC4005C),
        sortOrder: 3,
      ),
    ];
  }

  PosHeaderSlide copyWith({
    String? id,
    String? ownerId,
    String? badge,
    String? title,
    String? subtitle,
    Color? startColor,
    Color? middleColor,
    Color? endColor,
    int? sortOrder,
    bool? isActive,
  }) {
    return PosHeaderSlide(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      badge: badge ?? this.badge,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      startColor: startColor ?? this.startColor,
      middleColor: middleColor ?? this.middleColor,
      endColor: endColor ?? this.endColor,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toBody() {
    return {
      'ownerId': ownerId,
      'badge': badge,
      'title': title,
      'subtitle': subtitle,
      'startColor': colorToHex(startColor),
      'middleColor': colorToHex(middleColor),
      'endColor': colorToHex(endColor),
      'sortOrder': sortOrder.toInt(),
      'isActive': isActive,
    };
  }
}

Color colorFromHex(String value, int fallback) {
  final normalized = value.replaceAll('#', '').trim();
  if (normalized.length != 6 && normalized.length != 8) {
    return Color(fallback);
  }

  final parsed = int.tryParse(
    normalized.length == 6 ? 'FF$normalized' : normalized,
    radix: 16,
  );
  return Color(parsed ?? fallback);
}

String colorToHex(Color color) {
  final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${value.substring(2)}';
}

String _readString(dynamic value) => value?.toString() ?? '';

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase().trim();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}
