import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>('skills.list', {});
      final skills = (result['skills'] as List? ?? [])
          .map((s) => (s as Map).cast<String, dynamic>())
          .toList();
      skills.sort((a, b) {
        final aEnabled = a['enabled'] as bool? ?? false;
        final bEnabled = b['enabled'] as bool? ?? false;
        if (aEnabled != bEnabled) return aEnabled ? -1 : 1;
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
      setState(() { _skills = skills; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleSkill(String name, bool enabled) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        enabled ? 'skills.enable' : 'skills.disable',
        {'name': name},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Skills'),
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
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_skills.isEmpty) {
      return const Center(child: Text('No skills found'));
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CupertinoListSection.insetGrouped(
            header: const Text('Installed Skills'),
            children: _skills.map(_buildSkillTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillTile(Map<String, dynamic> skill) {
    final name = skill['name'] as String? ?? 'unknown';
    final enabled = skill['enabled'] as bool? ?? false;
    final description = skill['description'] as String?;
    final version = skill['version'] as String?;
    final installed = skill['installed'] as bool? ?? true;

    return CupertinoListTile(
      title: Text(name),
      subtitle: description != null
          ? Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      additionalInfo: version != null ? Text('v$version') : null,
      trailing: installed
          ? CupertinoSwitch(
              value: enabled,
              onChanged: (v) => _toggleSkill(name, v),
            )
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _installSkill(name),
              child: const Text('Install'),
            ),
    );
  }

  Future<void> _installSkill(String name) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>('skills.install', {'name': name});
      await _load();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Install Failed'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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
