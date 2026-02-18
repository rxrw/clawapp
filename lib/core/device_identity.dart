import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ed25519 device identity — mirrors OpenClaw's Node.js device-identity.ts
class DeviceIdentity {
  final String deviceId;
  final Uint8List publicKeyBytes;
  final ed.PrivateKey privateKey;
  final ed.PublicKey publicKey;

  DeviceIdentity._({
    required this.deviceId,
    required this.publicKeyBytes,
    required this.privateKey,
    required this.publicKey,
  });

  static DeviceIdentity generate() {
    final kp = ed.generateKey();
    final pubBytes = Uint8List.fromList(kp.publicKey.bytes);
    final deviceId = _fingerprint(pubBytes);
    return DeviceIdentity._(
      deviceId: deviceId,
      publicKeyBytes: pubBytes,
      privateKey: kp.privateKey,
      publicKey: kp.publicKey,
    );
  }

  static DeviceIdentity fromJson(Map<String, dynamic> json) {
    final pubBytes = base64Decode(json['publicKey'] as String);
    final privBytes = base64Decode(json['privateKey'] as String);
    return DeviceIdentity._(
      deviceId: json['deviceId'] as String,
      publicKeyBytes: Uint8List.fromList(pubBytes),
      publicKey: ed.PublicKey(pubBytes),
      privateKey: ed.PrivateKey(privBytes),
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'publicKey': base64Encode(publicKeyBytes),
        'privateKey': base64Encode(privateKey.bytes),
      };

  static String _fingerprint(Uint8List pubBytes) {
    final digest = sha256.convert(pubBytes);
    return digest.toString();
  }

  /// Build the signing payload (v2 format when nonce present)
  String buildPayload({
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required int signedAtMs,
    String? token,
    String? nonce,
  }) {
    final version = nonce != null ? 'v2' : 'v1';
    final scopeStr = scopes.join(',');
    final tokenStr = token ?? '';
    final parts = [
      version,
      deviceId,
      clientId,
      clientMode,
      role,
      scopeStr,
      signedAtMs.toString(),
      tokenStr,
    ];
    if (nonce != null) parts.add(nonce);
    return parts.join('|');
  }

  /// Sign the payload with Ed25519
  String sign(String payload) {
    final bytes = utf8.encode(payload);
    final sig = ed.sign(privateKey, Uint8List.fromList(bytes));
    return _base64UrlEncode(Uint8List.fromList(sig));
  }

  /// Base64url-encode (no padding)
  static String _base64UrlEncode(Uint8List data) {
    return base64Url
        .encode(data)
        .replaceAll('=', '');
  }

  String get publicKeyBase64Url => _base64UrlEncode(publicKeyBytes);
}

class DeviceIdentityStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'device_identity_v1';

  static DeviceIdentity? _cached;

  static Future<DeviceIdentity> loadOrCreate() async {
    if (_cached != null) return _cached!;

    final raw = await _storage.read(key: _key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _cached = DeviceIdentity.fromJson(json);
        return _cached!;
      } catch (_) {
        // corrupted, regenerate
      }
    }

    final identity = DeviceIdentity.generate();
    await _storage.write(key: _key, value: jsonEncode(identity.toJson()));
    _cached = identity;
    return identity;
  }

  static Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
