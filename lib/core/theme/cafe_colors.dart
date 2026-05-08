import 'package:flutter/material.dart';

class CafeColors {
  static const Color flame = Color(0xFF534AB7);
  static const Color amber = Color(0xFFBA7517);
  static const Color espresso = Color(0xFF111118);
  static const Color latte = Color(0xFFF0F0F2);
  static const Color steam = Color(0xFFFFFFFF);
  static const Color creme = Color(0xFFEEEDFE);
  static const Color olive = Color(0xFF1D9E75);
  static const Color oliveLight = Color(0xFFE1F5EE);
  static const Color charcoal = Color(0xFF111118);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF534AB7), Color(0xFF6E64D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bottomBarGradient = LinearGradient(
    colors: [Color(0xFF534AB7), Color(0xFF3C3489)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
