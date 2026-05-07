import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_login_result.dart';
import '../models/user_model.dart';
import '../services/pocketbase/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? user;
  Map<String, dynamic>? userData;
  bool isLoading = false;
  bool _roleLoaded = false;
  Future<String?>? _googleSignInOperation;

  bool get isRoleLoaded => _roleLoaded;
  String get role => userData?['role']?.toString() ?? 'cashier';
  String? get currentUid => user?.id;
  String get ownerId => user?.effectiveAdminId ?? currentUid ?? '';
  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';
  bool get isKitchen => role == 'kitchen';

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    debugPrint('AUTH-PROVIDER-INIT: Starting PocketBase auth...');
    _roleLoaded = false;
    notifyListeners();

    try {
      user = await _authService.refreshAuth();
      debugPrint('AUTH-PROVIDER-INIT: refreshAuth user=${user?.id ?? 'null'}');

      await _loadUserRole(user);
      debugPrint('AUTH-PROVIDER-INIT: Complete user=${user?.id ?? 'null'}');
    } catch (e, st) {
      debugPrint('🔴 AUTH-PROVIDER-INIT FAILED: $e');
      debugPrint('$st');

      // Fail-safe: unblock UI even if auth init fails.
      user = null;
      userData = null;
      _roleLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _loadUserRole(UserModel? pbUser) async {
    debugPrint('LOAD-ROLE-START: uid=${pbUser?.id}');

    if (pbUser == null) {
      userData = null;
      _roleLoaded = true;
      notifyListeners();
      return;
    }

    if (!pbUser.isActive) {
      await logout();
      return;
    }

    userData = pbUser.toMap()
      ..addAll({
        'id': pbUser.id,
        'adminId': pbUser.effectiveAdminId,
      });
    _roleLoaded = true;
    notifyListeners();
  }

  Future<AuthLoginResult?> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      isLoading = false;
      notifyListeners();
      return AuthLoginResult(
        emailError:
            trimmedEmail.isEmpty ? 'Please fill out required field!' : null,
        passwordError:
            trimmedPassword.isEmpty ? 'Please fill out required field!' : null,
      );
    }

    try {
      final loggedInUser =
          await _authService.login(trimmedEmail, trimmedPassword);
      user = loggedInUser;
      await _loadUserRole(loggedInUser);

      if (!(userData?['isActive'] ?? true)) {
        await logout();
        return AuthLoginResult(
          emailError: 'This account has been deactivated.',
          passwordError: 'This account has been deactivated.',
        );
      }

      return null;
    } catch (e) {
      debugPrint('🔴 LOGIN ERROR: $e');
      debugPrint('🔴 LOGIN ERROR TYPE: ${e.runtimeType}');

      final message = e.toString().replaceFirst('Exception: ', '');
      debugPrint('🔴 LOGIN MESSAGE: $message');

      final isCredentialError =
          message.toLowerCase().contains('invalid email or password') ||
              message.toLowerCase().contains('invalid credentials');

      return AuthLoginResult(
        emailError: isCredentialError ? 'Wrong credentials!' : message,
        passwordError: isCredentialError ? 'Wrong credentials!' : message,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithGoogle() {
    _googleSignInOperation ??= _runGoogleSignIn().whenComplete(() {
      _googleSignInOperation = null;
    });

    return _googleSignInOperation!;
  }

  Future<String?> _runGoogleSignIn() async {
    isLoading = true;
    notifyListeners();

    try {
      final loggedInUser =
          await _authService.loginWithGoogle(provider: 'google');

      user = loggedInUser;
      await _loadUserRole(loggedInUser);

      final refreshed = await _authService.currentUser;
      if (refreshed != null && refreshed.id != loggedInUser.id) {
        user = refreshed;
        await _loadUserRole(refreshed);
      }

      if (!(userData?['isActive'] ?? true)) {
        await logout();
        return 'This account has been deactivated.';
      }

      return null;
    } catch (e) {
      debugPrint('📣 GOOGLE LOGIN ERROR: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      return message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.logout();
      user = null;
      userData = null;
      _roleLoaded = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createEmployee({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (!isAdmin || currentUid == null) {
      return {'success': false, 'error': 'Admin only'};
    }

    try {
      await _authService.createStaff(
        email: email.trim(),
        password: password,
        adminId: currentUid!,
        role: role,
        name: name.trim(),
      );

      return {
        'success': true,
        'email': email.trim(),
        'password': password,
      };
    } catch (e) {
      debugPrint('Error creating employee: $e');
      return {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  Future<bool> updateUserRole(String userId, String newRole) async {
    if (!isAdmin) return false;

    try {
      await _authService.updateUser(userId, {'role': newRole});
      return true;
    } catch (e) {
      debugPrint('Error updating role: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String userId) async {
    if (!isAdmin) return false;

    try {
      await _authService.deleteUser(userId);
      return true;
    } catch (e) {
      debugPrint('Error deleting employee: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getEmployees() {
    if (!isAdmin || currentUid == null) return Stream.value([]);
    return _authService.getStaffStream(currentUid!);
  }
}
