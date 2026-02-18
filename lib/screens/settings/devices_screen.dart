import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _pending = [];
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
      final result = await gw.request<Map<String, dynamic>>(
        'device.pair.list',
        {},
      );
      final all = (result['devices'] as List? ?? [])
          .map((d) => (d as Map).cast<String, dynamic>())
          .toList();
      _pending = all.where((d) => d['status'] == 'pending').toList();
      _devices = all.where((d) => d['status'] != 'pending').toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approve(String requestId) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'device.pair.approve',
        {'requestId': requestId},
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _reject(String requestId) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'device.pair.reject',
        {'requestId': requestId},
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _revoke(String deviceId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Revoke Device'),
        content: Text('Revoke access for device ${deviceId.substring(0, 12)}…?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'device.token.revoke',
        {'deviceId': deviceId},
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Devices'),
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
    return ListView(
      children: [
        if (_pending.isNotEmpty)
          CupertinoListSection.insetGrouped(
            header: const Text('PENDING APPROVAL'),
            children: _pending.map(_buildPendingTile).toList(),
          ),
        if (_devices.isNotEmpty)
          CupertinoListSection.insetGrouped(
            header: const Text('PAIRED DEVICES'),
            children: _devices.map(_buildDeviceTile).toList(),
          ),
        if (_pending.isEmpty && _devices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Text('📱', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('No devices'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> d) {
    final id = d['requestId'] as String? ?? d['id'] as String? ?? '';
    final clientName = d['clientName'] as String? ?? 'Unknown';
    final ip = d['ip'] as String? ?? '';

    return CupertinoListTile(
      leading: const Icon(CupertinoIcons.device_phone_portrait,
          color: CupertinoColors.systemOrange),
      title: Text(clientName),
      subtitle: Text('$ip\n${id.substring(0, 12.clamp(0, id.length))}…'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _approve(id),
            child: const Icon(CupertinoIcons.checkmark_circle,
                color: CupertinoColors.systemGreen),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _reject(id),
            child: const Icon(CupertinoIcons.xmark_circle,
                color: CupertinoColors.systemRed),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> d) {
    final deviceId = d['deviceId'] as String? ?? d['id'] as String? ?? '';
    final clientName = d['clientName'] as String? ?? d['clientDisplayName'] as String? ?? 'Device';
    final role = d['role'] as String? ?? '';
    final lastSeen = d['lastSeenAt'] as int?;

    return CupertinoListTile(
      leading: const Icon(CupertinoIcons.device_phone_portrait,
          color: CupertinoColors.systemGreen),
      title: Text(clientName),
      subtitle: Text('$role ${lastSeen != null ? '• last seen ${_timeAgo(lastSeen)}' : ''}\n${deviceId.substring(0, 12.clamp(0, deviceId.length))}…'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _revoke(deviceId),
        child: const Text(
          'Revoke',
          style: TextStyle(color: CupertinoColors.systemRed, fontSize: 14),
        ),
      ),
    );
  }

  static String _timeAgo(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
