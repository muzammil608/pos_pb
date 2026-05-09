import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/auth_login_result.dart';
import '../models/user_model.dart';
import '../services/pocketbase/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isRoleLoaded = false;
  bool _isLoading = false;

  UserModel? _user;
  UserModel? _userData;

  String _role = '';
  String _currentUid = 'guest';
  String _ownerId = '';

  // Used by ProductSeeder (expects synchronous PocketBase access).
  PocketBase? _pb;

  AuthProvider() {
    _init();
  }

  bool get isRoleLoaded => _isRoleLoaded;
  bool get isLoading => _isLoading;

  UserModel? get user => _user;
  UserModel? get userData => _userData;

  String get role => _role;
  String get currentUid => _currentUid;
  String get ownerId => _ownerId;

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';
  bool get isKitchen => role == 'kitchen';

  /// PocketBase instance for services that need direct access.
  /// Must only be accessed after initialization completes.
  PocketBase get pb {
    final value = _pb;
    if (value == null) {
      throw StateError('PocketBase client not initialized yet.');
    }
    return value;
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize PocketBase client (so `pb` is usable synchronously later).
      _pb = await _authService.initPb();

      final current = await _authService.currentUser;
      _user = current;

      // Role-derived fields
      _role = current?.role ?? '';
      _currentUid = current?.uid ?? 'guest';
      _ownerId = current?.effectiveAdminId ?? '';

      // Optional: keep a copy of userData if some screens expect it.
      _userData = current;

      _isRoleLoaded = true;
    } catch (e) {
      debugPrint('[AuthProvider] init error: $e');
      _isRoleLoaded = true; // allow app to show LoginScreen
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthLoginResult?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _initMaybe(); // ensures pb is ready
      final user = await _authService.login(email, password);
      _setUser(user);
      return null; // success => no errors
    } catch (e) {
      // Map provider/POCKETBASE errors to AuthLoginResult if needed.
      // Current UI only checks for null vs non-null.
      return AuthLoginResult(
        emailError: 'Login failed.',
        passwordError: e.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _initMaybe();
      final user = await _authService.loginWithGoogle();
      _setUser(user);
      return null; // success
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _userData = null;
    _role = '';
    _currentUid = 'guest';
    _ownerId = '';
    notifyListeners();
  }

  // Used by some admin screens.
  bool _started = false;
  Future<void> _initMaybe() async {
    if (_started) return;
    _started = true;
    // Wait for init to complete.
    while (!_isRoleLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _setUser(UserModel user) {
    _user = user;
    _userData = user;

    _role = user.role;
    _currentUid = user.uid;
    _ownerId = user.effectiveAdminId;
  }

  Future<Map<String, dynamic>> createEmployee({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      if (_ownerId.isEmpty) {
        return {'success': false, 'error': 'Missing owner/admin id.'};
      }

      await _authService.createStaff(
        email: email,
        password: password,
        adminId: _ownerId,
        role: role,
        name: name,
      );

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deleteEmployee(String userId) async {
    try {
      await _authService.deleteUser(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String role) async {
    try {
      await _authService.updateUser(userId, {'role': role});
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getEmployees() {
    return _authService.getStaffStream(_ownerId);
  }
}
