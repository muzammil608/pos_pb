// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/cafe_colors.dart';
import '../providers/auth_provider.dart';

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.photoUrl,
    required this.userName,
    this.radius = 20,
    this.fontSize = 16,
  });

  final String? photoUrl;
  final String userName;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    String? resolvedUrl;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      resolvedUrl = photoUrl!.contains('googleusercontent.com')
          ? '${photoUrl!.split('=').first}=s400'
          : photoUrl;
    }

    if (resolvedUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: CafeColors.flame,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _InitialAvatar(
              userName: userName,
              radius: radius,
              fontSize: fontSize,
            ),
            errorWidget: (context, url, error) => _InitialAvatar(
              userName: userName,
              radius: radius,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    return _InitialAvatar(
      userName: userName,
      radius: radius,
      fontSize: fontSize,
    );
  }
}

class AppDrawerAvatarButton extends StatelessWidget {
  const AppDrawerAvatarButton({
    super.key,
    required this.photoUrl,
    required this.userName,
  });

  final String? photoUrl;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => Scaffold.of(builderContext).openDrawer(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppUserAvatar(
              photoUrl: photoUrl,
              userName: userName,
              radius: 18,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.auth,
    required this.currentRoute,
  });

  final AuthProvider auth;
  final String currentRoute;

  // Role badge colors
  Color _roleBgColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return CafeColors.creme;
      case 'kitchen':
        return CafeColors.oliveLight;
      default:
        return CafeColors.creme;
    }
  }

  Color _roleTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'kitchen':
        return CafeColors.olive;
      default:
        return CafeColors.flame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final userEmail = user?.email ?? 'No Email';
    final userName = user?.displayName ??
        (userEmail.contains('@') ? userEmail.split('@').first : userEmail);
    final photoUrl = user?.photoURL;

    return Drawer(
      backgroundColor: CafeColors.steam,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: CafeColors.headerGradient,
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Orion POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Restaurant POS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              children: [
                if (auth.isAdmin || auth.isCashier)
                  _DrawerItem(
                    icon: Icons.storefront_rounded,
                    title: 'Order Station',
                    route: '/pos',
                    currentRoute: currentRoute,
                  ),
                if (auth.isAdmin)
                  _DrawerItem(
                    icon: Icons.analytics_rounded,
                    title: 'Admin Dashboard',
                    route: '/admin',
                    currentRoute: currentRoute,
                  ),
                if (auth.isAdmin)
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Orders Report',
                    route: '/orders',
                    currentRoute: currentRoute,
                  ),
                if (auth.isAdmin)
                  _DrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Products',
                    route: '/products',
                    currentRoute: currentRoute,
                  ),
                if (auth.isAdmin)
                  _DrawerItem(
                    icon: Icons.people_rounded,
                    title: 'Employee Manager',
                    route: '/employees',
                    currentRoute: currentRoute,
                  ),
                if (auth.isAdmin || auth.isKitchen)
                  _DrawerItem(
                    icon: Icons.kitchen_rounded,
                    title: 'Kitchen',
                    route: '/kitchen',
                    currentRoute: currentRoute,
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + info row
                Row(
                  children: [
                    AppUserAvatar(
                      photoUrl: photoUrl,
                      userName: userName,
                      radius: 24,
                      fontSize: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CafeColors.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 11,
                              color: CafeColors.charcoal.withOpacity(0.45),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Role chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleBgColor(auth.role),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _roleTextColor(auth.role),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Logout button
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3B3B), Color(0xFFFF6B6B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Provider.of<AuthProvider>(context, listen: false)
                          .logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({
    super.key,
    required this.auth,
    required this.currentRoute,
    required this.child,
  });

  final AuthProvider auth;
  final String currentRoute;
  final Widget child;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) return child;

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: AppNavigationDrawer(
            auth: auth,
            currentRoute: currentRoute,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
  });

  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final selected = route == currentRoute;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: selected ? CafeColors.headerGradient : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          color: selected ? Colors.white : CafeColors.charcoal.withOpacity(0.5),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color:
                selected ? Colors.white : CafeColors.charcoal.withOpacity(0.75),
          ),
        ),
        trailing: selected
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          if (!selected) {
            Navigator.pushNamed(context, route);
          }
        },
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.userName,
    required this.radius,
    required this.fontSize,
  });

  final String userName;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: CafeColors.headerGradient,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
