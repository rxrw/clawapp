import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../providers/gateway_provider.dart';
import '../../providers/sessions_provider.dart';

class SessionsAdminScreen extends StatefulWidget {
  const SessionsAdminScreen({super.key});

  @override
  State<SessionsAdminScreen> createState() => _SessionsAdminScreenState();
}

class _SessionsAdminScreenState extends State<SessionsAdminScreen> {
  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionsProvider>();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sessions'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: sessions.loadSessions,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: sessions.loading && sessions.sessions.isEmpty
            ? const Center(child: CupertinoActivityIndicator())
            : sessions.sessions.isEmpty
                ? const Center(child: Text('No sessions'))
                : _buildList(sessions.sessions),
      ),
    );
  }

  Widget _buildList(List<Session> sessions) {
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (ctx, i) {
        final s = sessions[i];
        return _SessionAdminTile(session: s);
      },
    );
  }
}

class _SessionAdminTile extends StatelessWidget {
  final Session session;

  const _SessionAdminTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: Text(session.kindEmoji, style: const TextStyle(fontSize: 20)),
      title: Text(session.title, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.key,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 11,
              color: CupertinoColors.tertiaryLabel,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (session.model != null)
            Text(session.model!, style: const TextStyle(fontSize: 11)),
        ],
      ),
      additionalInfo: session.totalTokens != null
          ? Text(
              '${_formatK(session.totalTokens!)}k',
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        onPressed: () => _showActions(context),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(session.title),
        message: Text(session.key),
        actions: [
          // Model override
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showModelPicker(context);
            },
            child: const Text('🧠 Set Model Override'),
          ),
          // Thinking level
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showThinkingPicker(context);
            },
            child: const Text('💭 Set Thinking Level'),
          ),
          // Reset session
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _resetSession(context);
            },
            child: const Text('🔄 Reset Session'),
          ),
          // Compact
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _compactSession(context);
            },
            child: const Text('📦 Compact'),
          ),
          // Usage
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showUsage(context);
            },
            child: const Text('📊 View Usage'),
          ),
          // Delete
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSession(context);
            },
            child: const Text('🗑️ Delete Session'),
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

  void _showThinkingPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Thinking Level'),
        actions: [
          for (final level in [null, 'none', 'low', 'medium', 'high'])
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                _patchSession(context, {'thinkingLevel': level});
              },
              child: Text(level ?? 'Default (inherit)'),
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

  void _showModelPicker(BuildContext context) {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Model Override'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'e.g. sonnet or anthropic/claude-sonnet-4-5',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              final model = controller.text.trim();
              _patchSession(context, {'model': model.isEmpty ? null : model});
              controller.dispose();
            },
            child: const Text('Set'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              controller.dispose();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSession(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Reset Session'),
        content: Text('Reset "${session.title}"? This clears the conversation.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'sessions.reset',
        {'key': session.key, 'reason': 'reset'},
      );
      if (context.mounted) context.read<SessionsProvider>().loadSessions();
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _compactSession(BuildContext context) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'sessions.compact',
        {'key': session.key},
      );
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Compacted'),
            content: const Text('Session transcript has been compacted.'),
            actions: [
              CupertinoDialogAction(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _showUsage(BuildContext context) async {
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>(
        'sessions.usage' ,
        {'key': session.key},
      );
      if (!context.mounted) return;

      final input = result['inputTokens'] as int? ?? 0;
      final output = result['outputTokens'] as int? ?? 0;
      final total = result['totalTokens'] as int? ?? input + output;
      final cost = result['estimatedCostUsd'] as num?;

      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Session Usage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text('Input: ${_formatK(input)}k tokens'),
              Text('Output: ${_formatK(output)}k tokens'),
              Text('Total: ${_formatK(total)}k tokens'),
              if (cost != null)
                Text('Est. Cost: \$${cost.toStringAsFixed(4)}'),
            ],
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
      _showError(context, e.toString());
    }
  }

  Future<void> _deleteSession(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: Text('Delete "${session.title}" and its transcript?'),
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
    if (confirmed != true || !context.mounted) return;
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'sessions.delete',
        {'key': session.key, 'deleteTranscript': true},
      );
      if (context.mounted) context.read<SessionsProvider>().loadSessions();
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _patchSession(
    BuildContext context,
    Map<String, dynamic> patch,
  ) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'sessions.patch',
        {'key': session.key, ...patch},
      );
      if (context.mounted) context.read<SessionsProvider>().loadSessions();
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String msg) {
    if (!context.mounted) return;
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

  static String _formatK(int n) => (n / 1000).toStringAsFixed(1);
}
