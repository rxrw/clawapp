import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'device_identity.dart';

const _uuid = Uuid();

enum GatewayState {
  disconnected,
  connecting,
  pairing, // waiting for admin approval
  connected,
  error,
}

class GatewayEvent {
  final String event;
  final dynamic payload;
  final int? seq;

  const GatewayEvent({required this.event, this.payload, this.seq});
}

class GatewayError {
  final String code;
  final String message;

  const GatewayError({required this.code, required this.message});

  @override
  String toString() => '[$code] $message';
}

/// Low-level WebSocket RPC client for OpenClaw Gateway.
/// Mirrors the Node.js GatewayClient in gateway/client.ts
class GatewayClient extends ChangeNotifier {
  final String url;
  final String? token;
  final String? password;
  final DeviceIdentity deviceIdentity;

  GatewayState _state = GatewayState.disconnected;
  String? _errorMessage;
  String? _pairingMessage;
  Map<String, dynamic>? _helloResult;

  GatewayState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get pairingMessage => _pairingMessage;
  Map<String, dynamic>? get helloResult => _helloResult;
  bool get isConnected => _state == GatewayState.connected;

  final _eventController = StreamController<GatewayEvent>.broadcast();
  Stream<GatewayEvent> get events => _eventController.stream;

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _pending = <String, Completer<dynamic>>{};

  String? _connectNonce;
  bool _closed = false;
  Timer? _reconnectTimer;
  int _backoffMs = 1000;
  final String _instanceId = _uuid.v4();

  GatewayClient({
    required this.url,
    required this.deviceIdentity,
    this.token,
    this.password,
  });

  void _setState(GatewayState s, {String? error, String? pairing}) {
    _state = s;
    _errorMessage = error;
    _pairingMessage = pairing;
    notifyListeners();
  }

  void start() {
    _closed = false;
    _connect();
  }

  void stop() {
    _closed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub?.cancel();
    _sub = null;
    _flushErrors('Gateway client stopped');
    _setState(GatewayState.disconnected);
  }

  void _connect() {
    if (_closed) return;
    _setState(GatewayState.connecting);
    try {
      final wsUrl = _normalizeUrl(url);
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: const Duration(seconds: 30),
      );
      _sub = _channel!.stream.listen(
        _handleMessage,
        onError: (err) {
          debugPrint('[GW] WS error: $err');
          _handleDisconnect('Connection error: $err');
        },
        onDone: () {
          debugPrint('[GW] WS closed');
          _handleDisconnect('Connection closed');
        },
      );
    } catch (e) {
      _handleDisconnect('Failed to connect: $e');
    }
  }

  void _handleMessage(dynamic raw) {
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Event frame: has "event" key
    if (msg.containsKey('event')) {
      final event = msg['event'] as String;
      final payload = msg['payload'];
      final seq = msg['seq'] as int?;

      if (event == 'connect.challenge') {
        final nonce = (payload as Map?)?['nonce'] as String?;
        if (nonce != null) {
          _connectNonce = nonce;
          _sendConnect();
        }
        return;
      }

      if (event == 'hello.ok') {
        _helloResult = (payload as Map?)?.cast<String, dynamic>();
        _backoffMs = 1000;
        _setState(GatewayState.connected);
        _eventController.add(GatewayEvent(event: event, payload: payload));
        return;
      }

      if (event == 'hello.error') {
        final errorPayload = (payload as Map?)?.cast<String, dynamic>();
        final code = errorPayload?['code'] as String? ?? 'unknown';
        final message = errorPayload?['message'] as String? ?? 'Unknown error';

        if (code == 'pairing_required' || code == 'device_unknown') {
          _setState(
            GatewayState.pairing,
            pairing: 'Pairing required. Run on your server:\n  openclaw devices approve\n\nDevice ID: ${deviceIdentity.deviceId.substring(0, 16)}...',
          );
        } else {
          _setState(GatewayState.error, error: '[$code] $message');
        }
        return;
      }

      _eventController.add(GatewayEvent(event: event, payload: payload, seq: seq));
      return;
    }

    // Response frame: has "id" key
    if (msg.containsKey('id')) {
      final id = msg['id'] as String;
      final completer = _pending.remove(id);
      if (completer == null) return;

      if (msg.containsKey('error')) {
        final err = (msg['error'] as Map).cast<String, dynamic>();
        completer.completeError(
          GatewayError(
            code: err['code']?.toString() ?? 'error',
            message: err['message']?.toString() ?? 'Unknown error',
          ),
        );
      } else {
        completer.complete(msg['result']);
      }
    }
  }

  void _sendConnect() {
    final signedAtMs = DateTime.now().millisecondsSinceEpoch;
    final nonce = _connectNonce;
    final role = 'operator';
    final scopes = ['operator.admin'];

    // Prefer explicit token, then fall back to password auth
    final authToken = token;
    final auth = (authToken != null || password != null)
        ? {'token': authToken, 'password': password}
        : null;

    final payload = deviceIdentity.buildPayload(
      clientId: 'clawapp',
      clientMode: 'ui',
      role: role,
      scopes: scopes,
      signedAtMs: signedAtMs,
      token: authToken,
      nonce: nonce,
    );
    final signature = deviceIdentity.sign(payload);

    final connectMsg = {
      'id': _uuid.v4(),
      'method': 'connect',
      'params': {
        'minProtocol': 2,
        'maxProtocol': 2,
        'auth': auth,
        'clientName': 'clawapp',
        'clientDisplayName': 'ClawApp',
        'clientVersion': '1.0.0',
        'platform': defaultTargetPlatform.name,
        'mode': 'ui',
        'instanceId': _instanceId,
        'caps': ['tool_events'],
        'device': {
          'id': deviceIdentity.deviceId,
          'publicKey': deviceIdentity.publicKeyBase64Url,
          'signature': signature,
          'signedAt': signedAtMs,
          'nonce': nonce,
        },
      },
    };

    _send(connectMsg);
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  /// Send an RPC request and await the response
  Future<T> request<T>(String method, [Map<String, dynamic>? params]) async {
    if (!isConnected && method != 'connect') {
      throw GatewayError(code: 'not_connected', message: 'Gateway not connected');
    }
    final id = _uuid.v4();
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _send({'id': id, 'method': method, 'params': params ?? {}});
    final result = await completer.future;
    return result as T;
  }

  void _handleDisconnect(String reason) {
    _flushErrors(reason);
    if (!_closed) {
      _setState(GatewayState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    final delay = _backoffMs;
    _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
    _reconnectTimer = Timer(Duration(milliseconds: delay), _connect);
  }

  void _flushErrors(String reason) {
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(GatewayError(code: 'disconnected', message: reason));
      }
    }
    _pending.clear();
  }

  static String _normalizeUrl(String url) {
    if (url.startsWith('ws://') || url.startsWith('wss://')) return url;
    if (url.startsWith('https://')) return url.replaceFirst('https://', 'wss://');
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'ws://');
    return 'ws://$url';
  }

  @override
  void dispose() {
    stop();
    _eventController.close();
    super.dispose();
  }
}
