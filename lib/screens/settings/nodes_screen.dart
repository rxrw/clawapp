import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  List<Map<String, dynamic>> _nodes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>('node.list', {});
      final nodes = (result['nodes'] as List? ?? [])
          .map((n) => (n as Map).cast<String, dynamic>())
          .toList();
      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Nodes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_nodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🖥️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No nodes connected'),
            SizedBox(height: 8),
            Text(
              'Pair a device with\nopenclaw node pair',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 13,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: Text('${_nodes.length} NODE${_nodes.length == 1 ? '' : 'S'}'),
          children: _nodes.map(_buildNodeTile).toList(),
        ),
      ],
    );
  }

  Widget _buildNodeTile(Map<String, dynamic> node) {
    final name = node['name'] as String? ??
        node['displayName'] as String? ??
        node['nodeId'] as String? ??
        'Unknown';
    final platform = node['platform'] as String? ?? '';
    final connected = node['connected'] as bool? ?? false;
    final caps = (node['caps'] as List?)?.cast<String>() ?? [];

    return CupertinoListTile(
      leading: Icon(
        connected
            ? CupertinoIcons.circle_fill
            : CupertinoIcons.circle,
        color: connected
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemGrey,
        size: 14,
      ),
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (platform.isNotEmpty)
            Text(platform, style: const TextStyle(fontSize: 12)),
          if (caps.isNotEmpty)
            Text(
              caps.join(', '),
              style: const TextStyle(fontSize: 11, color: CupertinoColors.tertiaryLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        onPressed: () => _showNodeActions(node),
      ),
    );
  }

  void _showNodeActions(Map<String, dynamic> node) {
    final nodeId = node['nodeId'] as String? ?? '';
    final name = node['name'] as String? ?? 'Node';

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _describeNode(nodeId);
            },
            child: const Text('Describe'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _renameNode(nodeId, name);
            },
            child: const Text('Rename'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _describeNode(String nodeId) async {
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>(
        'node.describe',
        {'nodeId': nodeId},
      );
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Node Details'),
          content: SingleChildScrollView(
            child: Text(
              const JsonEncoder.withIndent('  ').convert(result),
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
              textAlign: TextAlign.left,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: Navigator.of(context).pop,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _renameNode(String nodeId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename Node'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'New name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'node.rename',
        {'nodeId': nodeId, 'name': newName},
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: Navigator.of(context).pop,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⛔', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          CupertinoButton.filled(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}
