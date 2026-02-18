import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  Map<String, dynamic>? _status;
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
      final result = await gw.request<Map<String, dynamic>>('channels.status', {});
      setState(() { _status = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Channels'),
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
                ? _ErrorView(error: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_status == null) return const Center(child: Text('No data'));

    final channels = (_status!['channels'] as List? ?? []);

    if (channels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📡', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No channels configured'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (ctx, i) {
        final ch = (channels[i] as Map).cast<String, dynamic>();
        return _ChannelTile(channel: ch, onRefresh: _load);
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channel;
  final VoidCallback onRefresh;

  const _ChannelTile({required this.channel, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final name = channel['name'] as String? ?? channel['id'] as String? ?? 'Unknown';
    final status = channel['status'] as String? ?? 'unknown';
    final connected = status == 'connected' || status == 'ready';
    final qrRequired = status == 'qr_required' || status == 'login_required';

    return CupertinoListSection.insetGrouped(
      header: Text(name.toUpperCase()),
      children: [
        CupertinoListTile(
          title: const Text('Status'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected
                      ? CupertinoColors.systemGreen
                      : qrRequired
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (channel['phone'] != null)
          CupertinoListTile(
            title: const Text('Phone'),
            trailing: Text(
              channel['phone'] as String,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
        if (channel['username'] != null)
          CupertinoListTile(
            title: const Text('Username'),
            trailing: Text(
              channel['username'] as String,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
        if (qrRequired)
          CupertinoListTile(
            title: const Text('Scan QR to login'),
            trailing: const Text(
              'Open web dashboard',
              style: TextStyle(color: CupertinoColors.systemBlue, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⛔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CupertinoButton.filled(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
