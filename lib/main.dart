import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';

import 'routes/app_routes.dart';
import 'screens/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          debugPrint(
              'MAIN: roleLoaded=${auth.isRoleLoaded}, user=${auth.user?.id}');

          return KeyedSubtree(
            key: ValueKey(auth.currentUid),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => CartProvider(),
                ),
                ChangeNotifierProvider(
                  create: (_) => OrderProvider(auth.ownerId),
                ),
                ChangeNotifierProvider(
                  create: (_) => ProductProvider(auth.ownerId),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: _homeFor(auth),
                routes: AppRoutes.routes,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _homeFor(AuthProvider auth) {
    if (!auth.isRoleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    return const LandingScreen();
  }
}
