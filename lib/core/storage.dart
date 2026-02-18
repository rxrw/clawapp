import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage for gateway credentials
class GatewayStorage {
  static const _secure = FlutterSecureStorage();

  static const _keyUrl = 'gateway_url';
  static const _keyPassword = 'gateway_password';
  static const _keyToken = 'gateway_token';
  static const _keyDeviceAuthToken = 'device_auth_token';
  static Future<GatewayCredentials?> load() async {
    final url = await _secure.read(key: _keyUrl);
    if (url == null) return null;
    return GatewayCredentials(
      url: url,
      password: await _secure.read(key: _keyPassword),
      token: await _secure.read(key: _keyToken),
    );
  }

  static Future<void> save(GatewayCredentials creds) async {
    await _secure.write(key: _keyUrl, value: creds.url);
    if (creds.password != null) {
      await _secure.write(key: _keyPassword, value: creds.password!);
    } else {
      await _secure.delete(key: _keyPassword);
    }
    if (creds.token != null) {
      await _secure.write(key: _keyToken, value: creds.token!);
    } else {
      await _secure.delete(key: _keyToken);
    }
  }

  static Future<void> saveDeviceAuthToken(String token) async {
    await _secure.write(key: _keyDeviceAuthToken, value: token);
  }

  static Future<String?> loadDeviceAuthToken() async {
    return _secure.read(key: _keyDeviceAuthToken);
  }

  static Future<void> clear() async {
    await _secure.deleteAll();
  }
}

class GatewayCredentials {
  final String url;
  final String? password;
  final String? token;

  const GatewayCredentials({
    required this.url,
    this.password,
    this.token,
  });

  /// Convert ws://host to http://host for display
  String get displayUrl => url.replaceFirst(RegExp(r'^ws'), 'http');

  /// Ensure ws:// scheme
  String get wsUrl {
    if (url.startsWith('ws://') || url.startsWith('wss://')) return url;
    if (url.startsWith('https://')) return url.replaceFirst('https://', 'wss://');
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'ws://');
    return 'ws://$url';
  }
}

/// App preferences (non-sensitive)
class AppPrefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String get activeSessionKey =>
      _prefs?.getString('active_session_key') ?? '';

  static Future<void> setActiveSessionKey(String key) async {
    await _prefs?.setString('active_session_key', key);
  }

  static bool get showTimestamps => _prefs?.getBool('show_timestamps') ?? true;

  static Future<void> setShowTimestamps(bool v) async {
    await _prefs?.setBool('show_timestamps', v);
  }

  static String get activeAgentId => _prefs?.getString('active_agent_id') ?? '';

  static Future<void> setActiveAgentId(String id) async {
    await _prefs?.setString('active_agent_id', id);
  }
}
