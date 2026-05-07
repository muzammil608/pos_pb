import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  static PocketBase? _instance;

  static const String _configuredUrl = String.fromEnvironment('POCKETBASE_URL');

  static String get _baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;

    // Fallback to local dev for quick running.
    // (127.0.0.1 works for Android emulator; on physical devices you must
    // pass POCKETBASE_URL.)
    return 'http://127.0.0.1:8090';
  }

  static Future<PocketBase> get instance async {
    if (_instance != null) return _instance!;

    final prefs = await SharedPreferences.getInstance();

    final store = AsyncAuthStore(
      save: (data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );

    _instance = PocketBase(_baseUrl, authStore: store);
    debugPrint('PocketBase URL: $_baseUrl');
    return _instance!;
  }

  static void reset() {
    _instance = null;
  }
}
