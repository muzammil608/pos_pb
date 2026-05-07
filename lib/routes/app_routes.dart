import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/unauthorized_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/kitchen/kitchen_screen.dart';
import '../screens/reports/report_screen.dart';
import '../screens/reports/admin_dashboard_screen.dart';
import '../screens/reports/orders_report_screen.dart';
import '../screens/cart/checkout_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/admin/employee_manager_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        '/login': (_) => const LoginScreen(),
        '/pos': (_) => const PosScreen(),
        '/checkout': (_) => const CheckoutScreen(),
        '/kitchen': (_) => const KitchenScreen(),
        '/reports': (_) => const ReportScreen(),
        '/admin': (_) => const AdminDashboardScreen(),
        '/orders': (_) => const OrdersReportScreen(),
        '/products': (_) => const ProductsScreen(),
        '/employees': (_) => const EmployeeManagerScreen(),
        '/unauthorized': (_) => const UnauthorizedScreen(),
      };
}
