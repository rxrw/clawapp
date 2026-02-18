import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class CronScreen extends StatefulWidget {
  const CronScreen({super.key});

  @override
  State<CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen> {
  List<Map<String, dynamic>> _jobs = [];
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
      final result = await gw.request<Map<String, dynamic>>('cron.list', {
        'includeDisabled': true,
      });
      final jobs = (result['jobs'] as List? ?? [])
          .map((j) => (j as Map).cast<String, dynamic>())
          .toList();
      setState(() { _jobs = jobs; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleJob(String jobId, bool enabled) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>('cron.update', {
        'jobId': jobId,
        'patch': {'enabled': enabled},
      });
      await _load();
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _runJob(String jobId) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>('cron.run', {'jobId': jobId});
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Job Triggered'),
            content: const Text('Job has been triggered manually.'),
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
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteJob(String jobId, String name) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Job'),
        content: Text('Delete "$name"?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final gw = context.read<GatewayProvider>();
        await gw.request<Map<String, dynamic>>('cron.remove', {'jobId': jobId});
        await _load();
      } catch (e) {
        if (mounted) _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
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
        middle: const Text('Cron Jobs'),
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
    if (_jobs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⏱️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No cron jobs'),
          ],
        ),
      );
    }

    return CupertinoListSection.insetGrouped(
      header: Text('${_jobs.length} Job${_jobs.length == 1 ? '' : 's'}'),
      children: _jobs.map(_buildJobTile).toList(),
    );
  }

  Widget _buildJobTile(Map<String, dynamic> job) {
    final jobId = job['id'] as String? ?? job['jobId'] as String? ?? '';
    final name = job['name'] as String? ?? 'Unnamed Job';
    final enabled = job['enabled'] as bool? ?? true;
    final schedule = job['schedule'] as Map?;
    final scheduleDesc = _describeSchedule(schedule?.cast<String, dynamic>());

    return CupertinoListTile(
      title: Text(name),
      subtitle: Text(scheduleDesc),
      additionalInfo: CupertinoSwitch(
        value: enabled,
        onChanged: (v) => _toggleJob(jobId, v),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        onPressed: () => _showJobActions(jobId, name),
      ),
    );
  }

  void _showJobActions(String jobId, String name) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _runJob(jobId);
            },
            child: const Text('▶ Run Now'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _deleteJob(jobId, name);
            },
            child: const Text('Delete'),
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

  static String _describeSchedule(Map<String, dynamic>? schedule) {
    if (schedule == null) return 'Unknown schedule';
    final kind = schedule['kind'] as String?;
    switch (kind) {
      case 'cron':
        return 'cron: ${schedule['expr'] ?? '?'}';
      case 'every':
        final ms = schedule['everyMs'] as num?;
        if (ms == null) return 'every: ?';
        final secs = ms.toInt() ~/ 1000;
        if (secs < 60) return 'every ${secs}s';
        if (secs < 3600) return 'every ${secs ~/ 60}m';
        return 'every ${secs ~/ 3600}h';
      case 'at':
        return 'at: ${schedule['at'] ?? '?'}';
      default:
        return kind ?? 'unknown';
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
