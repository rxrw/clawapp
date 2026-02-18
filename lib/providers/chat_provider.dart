import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/gateway_client.dart';
import '../models/message.dart';
import 'gateway_provider.dart';

const _uuid = Uuid();

class ChatProvider extends ChangeNotifier {
  final GatewayProvider _gateway;
  final String sessionKey;

  StreamSubscription? _eventSub;

  List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  String? _activeRunId;
  String? _streamingMessageId;
  String _streamBuffer = '';

  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;
  bool get isRunning => _activeRunId != null;

  ChatProvider(this._gateway, this.sessionKey) {
    _gateway.addListener(_onGatewayChange);
    _subscribeEvents();
    if (_gateway.isConnected) loadHistory();
  }

  void _onGatewayChange() {
    if (_gateway.isConnected) {
      _subscribeEvents();
      if (_messages.isEmpty) loadHistory();
    }
  }

  void _subscribeEvents() {
    _eventSub?.cancel();
    _eventSub = _gateway.events.listen(_handleEvent);
  }

  void _handleEvent(GatewayEvent evt) {
    if (evt.event != 'chat') return;
    final payload = evt.payload;
    if (payload == null) return;

    final data = (payload as Map).cast<String, dynamic>();
    final evtSessionKey = data['sessionKey'] as String?;

    // Only process events for our session
    if (evtSessionKey != null && evtSessionKey != sessionKey) return;

    final type = data['type'] as String?;
    final runId = data['runId'] as String?;

    switch (type) {
      case 'start':
        _activeRunId = runId;
        _streamingMessageId = 'stream_${runId ?? _uuid.v4()}';
        _streamBuffer = '';
        // Add placeholder assistant message
        _messages = [
          ..._messages,
          ChatMessage(
            id: _streamingMessageId!,
            role: MessageRole.assistant,
            content: '',
            isStreaming: true,
          ),
        ];
        notifyListeners();
        break;

      case 'delta':
        final delta = data['delta'] as String? ?? '';
        _streamBuffer += delta;
        if (_streamingMessageId != null) {
          _messages = _messages.map((m) {
            if (m.id == _streamingMessageId) {
              return m.copyWith(content: _streamBuffer, isStreaming: true);
            }
            return m;
          }).toList();
          notifyListeners();
        }
        break;

      case 'end':
        if (_streamingMessageId != null) {
          _messages = _messages.map((m) {
            if (m.id == _streamingMessageId) {
              return m.copyWith(content: _streamBuffer, isStreaming: false);
            }
            return m;
          }).toList();
        }
        _activeRunId = null;
        _streamingMessageId = null;
        _streamBuffer = '';
        _sending = false;
        notifyListeners();
        break;

      case 'error':
        final errMsg = data['message'] as String? ?? 'Unknown error';
        _error = errMsg;
        _activeRunId = null;
        _streamingMessageId = null;
        _sending = false;
        // Replace streaming placeholder with error note
        if (_streamingMessageId != null) {
          _messages = _messages
              .where((m) => m.id != _streamingMessageId)
              .toList();
        }
        notifyListeners();
        break;

      case 'message':
        // Full message from history sync
        _loadHistoryIfNeeded();
        break;
    }
  }

  void _loadHistoryIfNeeded() {
    // Debounce
    Future.delayed(const Duration(milliseconds: 300), loadHistory);
  }

  Future<void> loadHistory({int limit = 50}) async {
    if (!_gateway.isConnected) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _gateway.request<Map<String, dynamic>>(
        'chat.history',
        {'sessionKey': sessionKey, 'limit': limit},
      );

      final rawMessages = (result['messages'] as List?) ?? [];
      final loaded = rawMessages
          .map((m) => ChatMessage.fromJson((m as Map).cast<String, dynamic>()))
          .where((m) => m.content.isNotEmpty || m.isSystem)
          .toList();

      _messages = loaded;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || !_gateway.isConnected) return;

    final runId = _uuid.v4();
    _sending = true;
    _error = null;

    // Optimistically add user message
    final userMsg = ChatMessage(
      id: 'user_$runId',
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    _messages = [..._messages, userMsg];
    notifyListeners();

    try {
      await _gateway.request<Map<String, dynamic>>(
        'chat.send',
        {
          'sessionKey': sessionKey,
          'message': text.trim(),
          'idempotencyKey': runId,
        },
      );
      _activeRunId = runId;
      // Response comes via streaming events
    } catch (e) {
      _sending = false;
      _error = e.toString();
      // Remove optimistic message on error
      _messages = _messages.where((m) => m.id != 'user_$runId').toList();
      notifyListeners();
    }
  }

  Future<void> abortCurrent() async {
    if (_activeRunId == null || !_gateway.isConnected) return;
    try {
      await _gateway.request<Map<String, dynamic>>(
        'chat.abort',
        {'sessionKey': sessionKey, 'runId': _activeRunId},
      );
    } catch (_) {}
    _activeRunId = null;
    _sending = false;
    // Remove streaming placeholder
    if (_streamingMessageId != null) {
      _messages = _messages
          .where((m) => m.id != _streamingMessageId)
          .toList();
      _streamingMessageId = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _gateway.removeListener(_onGatewayChange);
    super.dispose();
  }
}
