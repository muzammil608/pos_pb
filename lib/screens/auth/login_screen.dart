import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/auth_login_result.dart';

class _LoginColors {
  static const Color flame = Color(0xFFFF4D1C);
  static const Color espresso = Color(0xFF1E0F00);
  static const Color charcoal = Color(0xFF2C2C2C);
  static const Color error = Color(0xFFD32F2F);

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFFF4D1C), Color(0xFFFF6B35), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _Breakpoint {
  static const double xs = 360;
  static const double sm = 480;
  static const double md = 768;
  static const double lg = 1024;
}

class _ResponsiveLayout {
  _ResponsiveLayout(double screenWidth, double screenHeight) {
    if (screenWidth < _Breakpoint.xs) {
      cardMaxWidth = screenWidth - 32;
    } else if (screenWidth < _Breakpoint.sm) {
      cardMaxWidth = screenWidth - 48;
    } else if (screenWidth < _Breakpoint.md) {
      cardMaxWidth = 420;
    } else if (screenWidth < _Breakpoint.lg) {
      cardMaxWidth = 460;
    } else {
      cardMaxWidth = 480;
    }

    horizontalPadding = screenWidth < _Breakpoint.xs ? 12.0 : 24.0;
    verticalPadding = screenHeight < 600 ? 20.0 : 40.0;

    // Clamp cardMaxWidth to the screen width minus padding on both sides so
    // the card never overflows on narrow mobile screens.
    cardMaxWidth = cardMaxWidth.clamp(0, screenWidth - horizontalPadding * 2);

    if (screenWidth < _Breakpoint.xs || screenHeight < 600) {
      logoSize = 72.0;
      logoIconSize = 52.0;
    } else if (screenWidth < _Breakpoint.sm) {
      logoSize = 90.0;
      logoIconSize = 62.0;
    } else {
      logoSize = 118.0;
      logoIconSize = 74.0;
    }

    if (screenWidth < _Breakpoint.xs || screenHeight < 600) {
      titleFontSize = 36.0;
    } else if (screenWidth < _Breakpoint.sm) {
      titleFontSize = 46.0;
    } else {
      titleFontSize = 58.0;
    }

    final bool isCompact = screenHeight < 680;
    spacingAfterLogo = isCompact ? 6.0 : 12.0;
    spacingAfterTitle = isCompact ? 6.0 : 10.0;
    spacingBeforeCard = isCompact ? 20.0 : 36.0;
    spacingAfterCard = isCompact ? 20.0 : 36.0;

    cardPadding = screenWidth < _Breakpoint.xs
        ? const EdgeInsets.fromLTRB(14, 22, 14, 20)
        : const EdgeInsets.fromLTRB(24, 28, 24, 24);

    // FIX: Always allow scroll. On mobile web the keyboard shrinks the
    // viewport and without scrolling the content gets clipped. The old
    // `!kIsWeb` condition disabled scrolling on all web targets, which
    // prevented the page from adjusting when the soft keyboard appeared.
    allowScroll = true;
  }

  late double cardMaxWidth;
  late double horizontalPadding;
  late double verticalPadding;
  late double logoSize;
  late double logoIconSize;
  late double titleFontSize;
  late double spacingAfterLogo;
  late double spacingAfterTitle;
  late double spacingBeforeCard;
  late double spacingAfterCard;
  late EdgeInsets cardPadding;
  late bool allowScroll;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishSuccessfulLogin(AuthProvider auth) async {
    for (var attempt = 0; attempt < 10 && !auth.isRoleLoaded; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!auth.isRoleLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account role is still loading.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login did not complete. Please retry.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (auth.role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Role not configured. Please contact admin.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleEmailLogin() async {
    if (_isLoading) return;

    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final AuthLoginResult? result = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (result == null) {
      await _finishSuccessfulLogin(auth);
    } else {
      setState(() {
        _emailError = result.emailError;
        _passwordError = result.passwordError;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;

    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String? error = await auth.signInWithGoogle();

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: _LoginColors.error),
      );
    } else {
      await _finishSuccessfulLogin(auth);
    }
  }

  Widget _buildEmailField() {
    final bool hasError = _emailError != null;
    final bool isEmptyError = _emailError == 'Please fill out required field!';
    return TextField(
      controller: _emailController,
      // FIX: Explicitly set keyboard type and enable interactive selection
      // so the virtual keyboard opens reliably on mobile web browsers.
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        fontSize: 15,
        color: _LoginColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        hint: 'Email address',
        icon: Icons.email_outlined,
        hasError: hasError,
        isEmptyError: isEmptyError,
        errorText: isEmptyError ? null : _emailError,
        suffixIcon: null,
      ),
    );
  }

  Widget _buildPasswordField() {
    final bool hasError = _passwordError != null;
    final bool isEmptyError =
        _passwordError == 'Please fill out required field!';
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      // FIX: Explicit keyboard type keeps the default keyboard on mobile web
      // and ensures the field is focusable / tappable on all browsers.
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _isLoading ? null : _handleEmailLogin(),
      style: const TextStyle(
        fontSize: 15,
        color: _LoginColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        hint: 'Password',
        icon: Icons.lock_outline_rounded,
        hasError: hasError,
        isEmptyError: isEmptyError,
        errorText: isEmptyError ? null : _passwordError,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _LoginColors.charcoal.withOpacity(0.4),
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    required bool hasError,
    required bool isEmptyError,
    required String? errorText,
    required Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.78),
      hintText: isEmptyError ? 'Please fill out required field!' : hint,
      hintStyle: TextStyle(
        color: isEmptyError
            ? _LoginColors.error
            : _LoginColors.charcoal.withOpacity(0.45),
        fontSize: 14,
        fontWeight: isEmptyError ? FontWeight.w700 : FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: hasError
            ? _LoginColors.error
            : _LoginColors.charcoal.withOpacity(0.55),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: _LoginColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: hasError ? _LoginColors.error : Colors.transparent,
          width: hasError ? 1.5 : 0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: hasError
              ? _LoginColors.error
              : _LoginColors.flame.withOpacity(0.6),
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Set to true so Flutter resizes the body when the keyboard
      // appears. Combined with SingleChildScrollView this lets the user
      // scroll to see the focused field without any content being hidden.
      resizeToAvoidBottomInset: true,
      backgroundColor: _LoginColors.espresso,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ResponsiveLayout(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          // FIX: Always wrap in SingleChildScrollView so the content can
          // scroll up when the soft keyboard appears on mobile web.
          // Use keyboardDismissBehavior so tapping outside a field hides
          // the keyboard naturally on touch devices.
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              // FIX: minHeight ensures the content fills the screen when the
              // keyboard is hidden, while allowing it to grow taller when the
              // keyboard is shown (unlike the old fixed-height Container).
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Container(
                  decoration:
                      const BoxDecoration(gradient: _LoginColors.bgGradient),
                  child: CustomPaint(
                    painter: _FoodPatternPainter(),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.horizontalPadding,
                          vertical: layout.verticalPadding,
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: layout.cardMaxWidth),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BrandMark(
                                outerSize: layout.logoSize,
                                iconSize: layout.logoIconSize,
                              ),
                              SizedBox(height: layout.spacingAfterLogo),
                              Text(
                                'ORION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: layout.titleFontSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  height: 0.95,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x44000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: layout.spacingAfterTitle),
                              _buildDividerRow('PIZZA RESTAURANT'),
                              SizedBox(height: layout.spacingBeforeCard),
                              _buildLoginCard(layout),
                              SizedBox(height: layout.spacingAfterCard),
                              _buildFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginCard(_ResponsiveLayout layout) {
    return Container(
      width: double.infinity,
      padding: layout.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.espresso.withOpacity(0.20),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.18),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          _buildEmailField(),
          const SizedBox(height: 12),
          _buildPasswordField(),
          const SizedBox(height: 20),
          _buildLoginButton(),
          const SizedBox(height: 18),
          _buildOrDivider(),
          const SizedBox(height: 14),
          _buildGoogleButton(),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _LoginColors.espresso,
          foregroundColor: Colors.white,
          shadowColor: _LoginColors.espresso.withOpacity(0.45),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'LOGIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.35))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.78),
          side: BorderSide(color: Colors.white.withOpacity(0.80), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 22, width: 22),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                color: _LoginColors.charcoal.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerRow(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
            width: 42, child: Divider(color: Colors.white54, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(
            width: 42, child: Divider(color: Colors.white54, thickness: 1.5)),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 72,
                child: Divider(
                    color: Colors.white.withOpacity(0.35), thickness: 1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.local_pizza_rounded,
                  color: Colors.white70, size: 18),
            ),
            SizedBox(
                width: 72,
                child: Divider(
                    color: Colors.white.withOpacity(0.35), thickness: 1)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Software By Orion Solutions',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.outerSize = 118, this.iconSize = 74});

  final double outerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final double innerSize = outerSize * 0.815;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: innerSize + 16,
            height: innerSize + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _LoginColors.flame.withOpacity(0.05),
            ),
          ),
          // Glass circle
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Top gloss on circle
          Positioned(
            top: innerSize * 0.08,
            left: innerSize * 0.22,
            child: Container(
              width: innerSize * 0.35,
              height: innerSize * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),
          // Pizza icon
          Transform.rotate(
            angle: -0.18,
            child: Icon(Icons.local_pizza_rounded,
                color: Colors.white, size: iconSize),
          ),
        ],
      ),
    );
  }
}

class _FoodPatternPainter extends CustomPainter {
  const _FoodPatternPainter();

  static const List<_PatternIcon> _icons = [
    _PatternIcon(Icons.local_pizza, Offset(0.08, 0.08), 60, -0.45),
    _PatternIcon(Icons.eco_outlined, Offset(0.68, 0.06), 48, 0.30),
    _PatternIcon(Icons.local_pizza, Offset(0.86, 0.12), 62, 0.42),
    _PatternIcon(Icons.circle_outlined, Offset(0.26, 0.17), 44, -0.25),
    _PatternIcon(Icons.local_dining, Offset(0.08, 0.28), 42, 0.15),
    _PatternIcon(Icons.eco_outlined, Offset(0.86, 0.30), 44, -0.12),
    _PatternIcon(Icons.local_pizza, Offset(0.14, 0.43), 60, -0.52),
    _PatternIcon(Icons.circle_outlined, Offset(0.72, 0.39), 42, 0.20),
    _PatternIcon(Icons.local_pizza, Offset(0.82, 0.61), 64, 0.42),
    _PatternIcon(Icons.eco_outlined, Offset(0.58, 0.65), 54, -0.24),
    _PatternIcon(Icons.circle_outlined, Offset(0.20, 0.71), 38, 0.18),
    _PatternIcon(Icons.local_pizza, Offset(0.08, 0.90), 58, -0.50),
    _PatternIcon(Icons.circle_outlined, Offset(0.75, 0.88), 40, 0.12),
    _PatternIcon(Icons.eco_outlined, Offset(0.88, 0.78), 44, 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0x18FFFFFF);
    for (final icon in _icons) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.icon.codePoint),
          style: TextStyle(
            color: color,
            fontSize: icon.size,
            fontFamily: icon.icon.fontFamily,
            package: icon.icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final position = Offset(
        size.width * icon.position.dx,
        size.height * icon.position.dy,
      );

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(icon.rotation);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatternIcon {
  const _PatternIcon(this.icon, this.position, this.size, this.rotation);
  final IconData icon;
  final Offset position;
  final double size;
  final double rotation;
}
