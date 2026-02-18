import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<String> _lines = [];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _autoScroll = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>(
        'logs.tail',
        {'limit': 200},
      );
      final lines = (result['lines'] as List? ?? [])
          .map((l) => l.toString())
          .toList();
      setState(() {
        _lines
          ..clear()
          ..addAll(lines);
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  List<String> get _filteredLines {
    if (_filter.isEmpty) return _lines;
    final lower = _filter.toLowerCase();
    return _lines.where((l) => l.toLowerCase().contains(lower)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Logs'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
              child: Icon(
                _autoScroll
                    ? CupertinoIcons.arrow_down_to_line
                    : CupertinoIcons.arrow_down_to_line,
                color: _autoScroll
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _load,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Filter bar
            Padding(
              padding: const EdgeInsets.all(8),
              child: CupertinoTextField(
                placeholder: 'Filter logs…',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.search, size: 16,
                      color: CupertinoColors.secondaryLabel),
                ),
                onChanged: (v) => setState(() => _filter = v),
                clearButtonMode: OverlayVisibilityMode.editing,
                style: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),

            // Log content
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _buildLogView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogView() {
    final lines = _filteredLines;
    if (lines.isEmpty) {
      return const Center(child: Text('No log lines'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: lines.length,
      itemBuilder: (ctx, i) {
        final line = lines[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Text(
            line,
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 11,
              color: _logColor(line),
            ),
          ),
        );
      },
    );
  }

  static Color _logColor(String line) {
    if (line.contains('ERROR') || line.contains('error')) {
      return CupertinoColors.systemRed;
    }
    if (line.contains('WARN') || line.contains('warn')) {
      return CupertinoColors.systemOrange;
    }
    if (line.contains('DEBUG') || line.contains('debug')) {
      return CupertinoColors.systemGrey;
    }
    return CupertinoColors.label;
  }
}
