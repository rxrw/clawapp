import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../core/gateway_client.dart';
import '../models/session.dart';
import '../providers/gateway_provider.dart';
import '../providers/sessions_provider.dart';
import '../widgets/connection_banner.dart';
import 'chat_screen.dart';
import 'settings/settings_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  Widget build(BuildContext context) {
    final gw = context.watch<GatewayProvider>();
    final sessions = context.watch<SessionsProvider>();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: _ConnectionDot(state: gw.state),
        middle: const Text('Claw'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openNewChat(context),
              child: const Icon(CupertinoIcons.pencil),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openSettings(context),
              child: const Icon(CupertinoIcons.gear),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          if (gw.state == GatewayState.pairing)
            _PairingBanner(message: gw.pairingMessage ?? ''),
          if (gw.state == GatewayState.error)
            _ErrorBanner(message: gw.errorMessage ?? 'Connection error'),
          if (gw.state == GatewayState.connecting)
            const ConnectionBanner(message: 'Connecting...'),
          Expanded(
            child: _buildList(context, sessions),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, SessionsProvider sessions) {
    if (sessions.loading && sessions.sessions.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (sessions.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦞', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'No sessions yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: () => _openNewChat(context),
              child: const Text('Start a conversation'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => context.read<SessionsProvider>().loadSessions(),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _SessionTile(
              session: sessions.sessions[i],
              onTap: () => _openChat(context, sessions.sessions[i]),
            ),
            childCount: sessions.sessions.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  void _openChat(BuildContext context, Session session) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(session: session),
      ),
    );
  }

  void _openNewChat(BuildContext context) {
    // Navigate to main session (creates new chat)
    final sessions = context.read<SessionsProvider>();
    final mainKey = sessions.mainKey ?? 'main';
    final mainSession = sessions.sessions.firstWhere(
      (s) => s.isMain,
      orElse: () => Session(key: mainKey, displayName: 'Main'),
    );
    _openChat(context, mainSession);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final updatedAt = session.updatedAtDateTime;
    final timeText = updatedAt != null ? _formatTime(updatedAt) : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _avatarColor(session),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Center(
                child: Text(
                  session.kindEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: const TextStyle(
                            color: CupertinoColors.secondaryLabel,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (session.lastMessagePreview != null)
                    Text(
                      session.lastMessagePreview!,
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (session.channelName != null)
                    Text(
                      session.channelName!,
                      style: const TextStyle(
                        color: CupertinoColors.tertiaryLabel,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  static Color _avatarColor(Session s) {
    if (s.isMain) return const Color(0xFF007AFF).withValues(alpha: 0.15);
    if (s.key.contains('slack')) return const Color(0xFF4A154B).withValues(alpha: 0.15);
    if (s.key.contains('telegram')) return const Color(0xFF229ED9).withValues(alpha: 0.15);
    if (s.key.contains('whatsapp')) return const Color(0xFF25D366).withValues(alpha: 0.15);
    return const Color(0xFFAAAAAA).withValues(alpha: 0.15);
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}

class _ConnectionDot extends StatelessWidget {
  final GatewayState state;

  const _ConnectionDot({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case GatewayState.connected:
        color = CupertinoColors.systemGreen;
        break;
      case GatewayState.connecting:
        color = CupertinoColors.systemOrange;
        break;
      case GatewayState.pairing:
        color = CupertinoColors.systemYellow;
        break;
      default:
        color = CupertinoColors.systemRed;
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PairingBanner extends StatelessWidget {
  final String message;

  const _PairingBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Device Pairing Required',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '⛔ $message',
        style: const TextStyle(
          color: CupertinoColors.systemRed,
          fontSize: 13,
        ),
      ),
    );
  }
}
