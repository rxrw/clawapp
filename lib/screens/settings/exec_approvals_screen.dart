import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class ExecApprovalsScreen extends StatefulWidget {
  const ExecApprovalsScreen({super.key});

  @override
  State<ExecApprovalsScreen> createState() => _ExecApprovalsScreenState();
}

class _ExecApprovalsScreenState extends State<ExecApprovalsScreen> {
  Map<String, dynamic>? _snapshot;
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
        'exec.approvals.get',
        {},
      );
      setState(() {
        _snapshot = result;
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
        middle: const Text('Exec Permissions'),
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
    if (_snapshot == null) return const Center(child: Text('No data'));

    final file = (_snapshot!['file'] as Map?)?.cast<String, dynamic>() ?? {};
    final defaults =
        (file['defaults'] as Map?)?.cast<String, dynamic>() ?? {};
    final agents =
        (file['agents'] as Map?)?.cast<String, dynamic>() ?? {};
    final path = _snapshot!['path'] as String? ?? '';

    return ListView(
      children: [
        // File path
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            path,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),

        // Defaults section
        CupertinoListSection.insetGrouped(
          header: const Text('DEFAULTS'),
          children: [
            CupertinoListTile(
              title: const Text('Security'),
              trailing: Text(
                defaults['security'] as String? ?? 'not set',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
            CupertinoListTile(
              title: const Text('Ask Mode'),
              trailing: Text(
                defaults['ask'] as String? ?? 'not set',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
            CupertinoListTile(
              title: const Text('Auto-Allow Skills'),
              trailing: Text(
                (defaults['autoAllowSkills'] as bool? ?? false) ? 'Yes' : 'No',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
          ],
        ),

        // Per-agent allowlists
        for (final entry in agents.entries)
          _buildAgentSection(entry.key, (entry.value as Map).cast<String, dynamic>()),
      ],
    );
  }

  Widget _buildAgentSection(String agentId, Map<String, dynamic> agent) {
    final security = agent['security'] as String?;
    final ask = agent['ask'] as String?;
    final allowlist = (agent['allowlist'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    return CupertinoListSection.insetGrouped(
      header: Text('AGENT: $agentId'),
      children: [
        if (security != null)
          CupertinoListTile(
            title: const Text('Security'),
            trailing: Text(security,
                style: const TextStyle(color: CupertinoColors.secondaryLabel)),
          ),
        if (ask != null)
          CupertinoListTile(
            title: const Text('Ask'),
            trailing: Text(ask,
                style: const TextStyle(color: CupertinoColors.secondaryLabel)),
          ),
        if (allowlist.isEmpty)
          const CupertinoListTile(
            title: Text('No allowlist entries'),
          ),
        for (final entry in allowlist)
          CupertinoListTile(
            title: Text(
              entry['pattern'] as String? ?? '?',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
            subtitle: _buildAllowlistSubtitle(entry),
          ),
      ],
    );
  }

  Widget? _buildAllowlistSubtitle(Map<String, dynamic> entry) {
    final lastCmd = entry['lastUsedCommand'] as String?;
    final lastUsed = entry['lastUsedAt'] as int?;
    if (lastCmd == null && lastUsed == null) return null;
    final parts = <String>[];
    if (lastCmd != null) parts.add(lastCmd);
    if (lastUsed != null) {
      final ago = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastUsed));
      if (ago.inDays > 0) {
        parts.add('${ago.inDays}d ago');
      } else if (ago.inHours > 0) {
        parts.add('${ago.inHours}h ago');
      } else {
        parts.add('${ago.inMinutes}m ago');
      }
    }
    return Text(
      parts.join(' • '),
      style: const TextStyle(fontSize: 11),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
