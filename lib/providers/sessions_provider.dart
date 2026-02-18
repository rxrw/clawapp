import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import 'gateway_provider.dart';

class SessionsProvider extends ChangeNotifier {
  final GatewayProvider _gateway;
  StreamSubscription? _eventSub;

  List<Session> _sessions = [];
  bool _loading = false;
  String? _error;
  String? _defaultAgentId;
  String? _mainKey;

  List<Session> get sessions => _sessions;
  bool get loading => _loading;
  String? get error => _error;
  String? get defaultAgentId => _defaultAgentId;
  String? get mainKey => _mainKey;

  SessionsProvider(this._gateway) {
    _gateway.addListener(_onGatewayChange);
    _subscribeEvents();
  }

  void _onGatewayChange() {
    if (_gateway.isConnected) {
      _subscribeEvents();
      loadSessions();
    } else {
      _sessions = [];
      notifyListeners();
    }
  }

  void _subscribeEvents() {
    _eventSub?.cancel();
    final events = _gateway.events;
    _eventSub = events.listen((evt) {
      // Refresh sessions on relevant events
      if (evt.event == 'sessions.update' ||
          evt.event == 'chat' ||
          evt.event == 'hello.ok') {
        loadSessions();
      }
    });
  }

  Future<void> loadSessions() async {
    if (!_gateway.isConnected) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _gateway.request<Map<String, dynamic>>(
        'sessions.list',
        {
          'includeDerivedTitles': true,
          'includeLastMessage': true,
          'limit': 100,
        },
      );

      final sessionsList = (result['sessions'] as List?)
          ?.map((s) => Session.fromJson((s as Map).cast<String, dynamic>()))
          .toList() ?? [];

      // Sort: main first, then by updatedAt desc
      sessionsList.sort((a, b) {
        if (a.isMain && !b.isMain) return -1;
        if (!a.isMain && b.isMain) return 1;
        final aTime = a.updatedAt ?? 0;
        final bTime = b.updatedAt ?? 0;
        return bTime.compareTo(aTime);
      });

      _sessions = sessionsList;
      _defaultAgentId = result['defaults']?['agentId'] as String?;
      _mainKey = result['path'] as String?;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> newChat({String? agentId}) async {
    // Creating a new chat is just navigating to "main" key or a fresh key
    // The gateway creates sessions lazily on first message
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _gateway.removeListener(_onGatewayChange);
    super.dispose();
  }
}
