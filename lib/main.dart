import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_system/core/keyboard/pos_keyboard_system.dart';

import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';

import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/landing_screen.dart';

import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PosHotkeyRegistry.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrderProvider>(
          create: (_) => OrderProvider(""),
          update: (_, auth, previous) {
            if (previous == null || previous.ownerId != auth.ownerId) {
              return OrderProvider(auth.ownerId);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (_) => ProductProvider(""),
          update: (_, auth, previous) {
            if (previous == null || previous.ownerId != auth.ownerId) {
              return ProductProvider(auth.ownerId);
            }
            return previous;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppEntry(),
        routes: AppRoutes.routes,
      ),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    debugPrint(
      'MAIN: roleLoaded=${auth.isRoleLoaded}, user=${auth.user?.id}',
    );

    if (!auth.isRoleLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    return const LandingScreen();
  }
}
