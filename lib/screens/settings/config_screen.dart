import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  String? _rawConfig;
  String? _baseHash;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>('config.get', {});
      final config = result['config'] ?? result;
      final baseHash = result['baseHash'] as String?;
      final pretty = const JsonEncoder.withIndent('  ').convert(config);
      setState(() {
        _rawConfig = pretty;
        _baseHash = baseHash;
        _controller.text = pretty;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final text = _controller.text;
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>('config.set', {
        'config': parsed,
        if (_baseHash != null) 'baseHash': _baseHash,
      });
      setState(() { _saving = false; _isEditing = false; _rawConfig = text; });
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Config Saved'),
            content: const Text('Configuration has been applied. Gateway may restart.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Configuration'),
        trailing: _isEditing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CupertinoActivityIndicator()
                        : const Text('Save'),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _controller.text = _rawConfig ?? '';
                        _error = null;
                      });
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),
                ],
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _isEditing = true),
                child: const Text('Edit'),
              ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: CupertinoColors.systemRed.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 12,
                fontFamily: 'Menlo',
              ),
            ),
          ),
        Expanded(
          child: CupertinoTextField(
            controller: _controller,
            readOnly: !_isEditing,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 12,
            ),
            decoration: const BoxDecoration(
              color: CupertinoColors.systemGroupedBackground,
            ),
            padding: const EdgeInsets.all(16),
          ),
        ),
        if (_isEditing)
          Container(
            padding: const EdgeInsets.all(12),
            color: CupertinoColors.systemGroupedBackground,
            child: const Text(
              '⚠️ Edit carefully. Invalid JSON will be rejected. Gateway may restart on save.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
