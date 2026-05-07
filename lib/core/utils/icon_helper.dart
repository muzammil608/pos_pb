import 'package:flutter/material.dart';

class IconHelper {
  static const List<IconData> fastFoodIcons = [
    Icons.fastfood,
    Icons.local_pizza,
    Icons.lunch_dining,
    Icons.dinner_dining,
    Icons.bakery_dining,
    Icons.icecream,
    Icons.local_cafe,
    Icons.local_drink,
    Icons.emoji_food_beverage,
    Icons.coffee,
    Icons.brunch_dining,
    Icons.ramen_dining,
    Icons.takeout_dining,
    Icons.breakfast_dining,
    Icons.restaurant,
    Icons.restaurant_menu,
    Icons.set_meal,
  ];

  /// Map categories to default icons
  static IconData getDefaultIcon(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('pizza')) {
      return Icons.local_pizza;
    } else if (lower.contains('burger')) {
      return Icons.lunch_dining;
    } else if (lower.contains('drink') ||
        lower.contains('beverage') ||
        lower.contains('coffee') ||
        lower.contains('tea') ||
        lower.contains('juice')) {
      return Icons.local_cafe;
    } else if (lower.contains('dessert') ||
        lower.contains('ice cream') ||
        lower.contains('sweet')) {
      return Icons.icecream;
    } else if (lower.contains('bakery') ||
        lower.contains('bread') ||
        lower.contains('cake')) {
      return Icons.bakery_dining;
    } else if (lower.contains('rice') ||
        lower.contains('biryani') ||
        lower.contains('curry')) {
      return Icons.ramen_dining;
    } else if (lower.contains('chicken') || lower.contains('meat')) {
      return Icons.dinner_dining;
    } else if (lower.contains('breakfast')) {
      return Icons.breakfast_dining;
    } else if (lower.contains('snack')) {
      return Icons.fastfood;
    }

    return Icons.fastfood;
  }

  static IconData fromCodePoint(int codePoint) {
    return Icons.fastfood;
  }
}
