import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<Map<String, dynamic>> _agents = [];
  String? _defaultId;
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
      final result = await gw.request<Map<String, dynamic>>('agents.list', {});
      final agents = (result['agents'] as List? ?? [])
          .map((a) => (a as Map).cast<String, dynamic>())
          .toList();
      setState(() {
        _agents = agents;
        _defaultId = result['defaultId'] as String?;
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
        middle: const Text('Agents'),
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
    if (_agents.isEmpty) {
      return const Center(child: Text('No agents'));
    }

    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: Text('${_agents.length} AGENT${_agents.length == 1 ? '' : 'S'}'),
          children: _agents.map(_buildAgentTile).toList(),
        ),
      ],
    );
  }

  Widget _buildAgentTile(Map<String, dynamic> agent) {
    final id = agent['id'] as String? ?? '';
    final name = agent['name'] as String? ?? id;
    final identity = (agent['identity'] as Map?)?.cast<String, dynamic>();
    final emoji = identity?['emoji'] as String? ?? '🤖';
    final isDefault = id == _defaultId;

    return CupertinoListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Text(name),
          if (isDefault) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'default',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(id, style: const TextStyle(fontFamily: 'Menlo', fontSize: 11)),
      trailing: const CupertinoListTileChevron(),
      onTap: () => _openAgentFiles(id, name),
    );
  }

  Future<void> _openAgentFiles(String agentId, String name) async {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _AgentFilesScreen(agentId: agentId, agentName: name),
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

/// Agent workspace files viewer/editor
class _AgentFilesScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const _AgentFilesScreen({required this.agentId, required this.agentName});

  @override
  State<_AgentFilesScreen> createState() => _AgentFilesScreenState();
}

class _AgentFilesScreenState extends State<_AgentFilesScreen> {
  List<Map<String, dynamic>> _files = [];
  String? _workspace;
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
        'agents.files.list',
        {'agentId': widget.agentId},
      );
      setState(() {
        _files = (result['files'] as List? ?? [])
            .map((f) => (f as Map).cast<String, dynamic>())
            .toList();
        _workspace = result['workspace'] as String?;
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
        middle: Text(widget.agentName),
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
                ? Center(child: Text(_error!))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      children: [
        if (_workspace != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              _workspace!,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        CupertinoListSection.insetGrouped(
          header: const Text('WORKSPACE FILES'),
          children: _files.isEmpty
              ? [const CupertinoListTile(title: Text('No files'))]
              : _files.map(_buildFileTile).toList(),
        ),
      ],
    );
  }

  Widget _buildFileTile(Map<String, dynamic> file) {
    final name = file['name'] as String? ?? '?';
    final missing = file['missing'] as bool? ?? false;
    final size = file['size'] as int?;

    return CupertinoListTile(
      leading: Icon(
        missing ? CupertinoIcons.doc : CupertinoIcons.doc_text_fill,
        color: missing ? CupertinoColors.systemGrey : CupertinoColors.systemBlue,
        size: 22,
      ),
      title: Text(name),
      subtitle: missing
          ? const Text('Missing', style: TextStyle(color: CupertinoColors.systemRed))
          : size != null
              ? Text('${(size / 1024).toStringAsFixed(1)} KB')
              : null,
      trailing: const CupertinoListTileChevron(),
      onTap: () => _viewFile(name),
    );
  }

  Future<void> _viewFile(String name) async {
    try {
      final gw = context.read<GatewayProvider>();
      final result = await gw.request<Map<String, dynamic>>(
        'agents.files.get',
        {'agentId': widget.agentId, 'name': name},
      );
      final file = (result['file'] as Map?)?.cast<String, dynamic>() ?? {};
      final content = file['content'] as String? ?? '';
      if (!mounted) return;

      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => _FileEditorScreen(
            agentId: widget.agentId,
            fileName: name,
            initialContent: content,
          ),
        ),
      );
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
}

/// In-app file editor for agent workspace files (SOUL.md, AGENTS.md, etc.)
class _FileEditorScreen extends StatefulWidget {
  final String agentId;
  final String fileName;
  final String initialContent;

  const _FileEditorScreen({
    required this.agentId,
    required this.fileName,
    required this.initialContent,
  });

  @override
  State<_FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<_FileEditorScreen> {
  late TextEditingController _controller;
  bool _saving = false;
  bool _modified = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      final changed = _controller.text != widget.initialContent;
      if (changed != _modified) setState(() => _modified = changed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>(
        'agents.files.set',
        {
          'agentId': widget.agentId,
          'name': widget.fileName,
          'content': _controller.text,
        },
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _modified = false;
        });
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Saved'),
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
      setState(() => _saving = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Save Failed'),
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
        middle: Text(widget.fileName),
        trailing: _modified
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              )
            : null,
      ),
      child: SafeArea(
        child: CupertinoTextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
          decoration: const BoxDecoration(
            color: CupertinoColors.systemGroupedBackground,
          ),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
