import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  List<Map<String, dynamic>> _models = [];
  Map<String, dynamic>? _currentConfig;
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

      final modelsResult = await gw.request<Map<String, dynamic>>('models.list', {});
      final configResult = await gw.request<Map<String, dynamic>>('config.get', {});

      final models = (modelsResult['models'] as List? ?? [])
          .map((m) => (m as Map).cast<String, dynamic>())
          .toList();

      setState(() {
        _models = models;
        _currentConfig = configResult;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String? get _defaultModel {
    final agents = _currentConfig?['agents'] as Map?;
    final defaults = agents?['defaults'] as Map?;
    return defaults?['model'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Models'),
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CupertinoListSection.insetGrouped(
            header: const Text('Current Default'),
            children: [
              CupertinoListTile(
                title: const Text('Model'),
                trailing: Text(
                  _defaultModel ?? 'Not set',
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              ),
            ],
          ),
        ),
        if (_models.isNotEmpty)
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: const Text('Available Models'),
              children: _models.map(_buildModelTile).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildModelTile(Map<String, dynamic> model) {
    final id = model['id'] as String? ?? 'unknown';
    final name = model['name'] as String? ?? id;
    final provider = model['provider'] as String? ?? '';
    final contextWindow = model['contextWindow'] as int?;
    final isReasoning = model['reasoning'] as bool? ?? false;
    final isDefault = id == _defaultModel;

    return CupertinoListTile(
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
          if (isReasoning) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.systemPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '🧠 reasoning',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('$provider${contextWindow != null ? ' · ${_formatK(contextWindow)}k ctx' : ''}'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _setDefault(id),
        child: const Text('Set default'),
      ),
    );
  }

  Future<void> _setDefault(String modelId) async {
    try {
      final gw = context.read<GatewayProvider>();
      await gw.request<Map<String, dynamic>>('config.patch', {
        'patch': {
          'agents': {
            'defaults': {'model': modelId}
          }
        },
      });
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Default Model Updated'),
            content: Text('Set to: $modelId'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  _load();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
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

  static String _formatK(int n) => (n / 1000).toStringAsFixed(0);

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
