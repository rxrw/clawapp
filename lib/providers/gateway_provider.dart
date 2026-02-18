import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/device_identity.dart';
import '../core/gateway_client.dart';
import '../core/storage.dart';

/// Top-level gateway connection provider
class GatewayProvider extends ChangeNotifier {
  GatewayClient? _client;
  GatewayCredentials? _credentials;
  bool _initialized = false;

  GatewayClient? get client => _client;
  GatewayCredentials? get credentials => _credentials;
  bool get initialized => _initialized;
  bool get isConnected => _client?.isConnected ?? false;
  GatewayState get state => _client?.state ?? GatewayState.disconnected;
  String? get errorMessage => _client?.errorMessage;
  String? get pairingMessage => _client?.pairingMessage;

  Future<void> init() async {
    await AppPrefs.init();
    final creds = await GatewayStorage.load();
    _credentials = creds;
    _initialized = true;

    if (creds != null) {
      await _connect(creds);
    }

    notifyListeners();
  }

  Future<void> connect(GatewayCredentials creds) async {
    await GatewayStorage.save(creds);
    _credentials = creds;
    await _connect(creds);
    notifyListeners();
  }

  Future<void> _connect(GatewayCredentials creds) async {
    _client?.stop();
    _client?.removeListener(_onClientChange);

    final identity = await DeviceIdentityStore.loadOrCreate();
    final newClient = GatewayClient(
      url: creds.wsUrl,
      deviceIdentity: identity,
      token: creds.token,
      password: creds.password,
    );
    newClient.addListener(_onClientChange);
    _client = newClient;
    newClient.start();
  }

  void _onClientChange() {
    notifyListeners();
  }

  Future<void> disconnect() async {
    _client?.stop();
    _client?.removeListener(_onClientChange);
    _client = null;
    await GatewayStorage.clear();
    await DeviceIdentityStore.clear();
    _credentials = null;
    notifyListeners();
  }

  /// Convenience wrapper for RPC calls
  Future<T> request<T>(String method, [Map<String, dynamic>? params]) async {
    final c = _client;
    if (c == null) throw GatewayError(code: 'no_client', message: 'Not connected');
    return c.request<T>(method, params);
  }

  Stream<GatewayEvent> get events => _client?.events ?? const Stream.empty();

  @override
  void dispose() {
    _client?.stop();
    _client?.dispose();
    super.dispose();
  }
}
