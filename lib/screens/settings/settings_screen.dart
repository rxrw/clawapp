import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import 'channels_screen.dart';
import 'skills_screen.dart';
import 'models_screen.dart';
import 'cron_screen.dart';
import 'config_screen.dart';
import 'sessions_admin_screen.dart';
import 'devices_screen.dart';
import 'exec_approvals_screen.dart';
import 'nodes_screen.dart';
import 'logs_screen.dart';
import 'agents_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gw = context.watch<GatewayProvider>();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _GatewayCard(gw: gw),

            CupertinoListSection.insetGrouped(
              header: const Text('COMMUNICATION'),
              children: [
                _NavTile(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  iconColor: CupertinoColors.systemGreen,
                  title: 'Channels',
                  subtitle: 'WhatsApp, Telegram, Slack…',
                  onTap: () => _push(context, const ChannelsScreen()),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              header: const Text('AI & TOOLS'),
              children: [
                _NavTile(
                  icon: CupertinoIcons.sparkles,
                  iconColor: CupertinoColors.systemPurple,
                  title: 'Models',
                  subtitle: 'Providers, default model',
                  onTap: () => _push(context, const ModelsScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.wrench,
                  iconColor: CupertinoColors.systemOrange,
                  title: 'Skills',
                  subtitle: 'Install & manage skills',
                  onTap: () => _push(context, const SkillsScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.person_crop_rectangle,
                  iconColor: CupertinoColors.systemIndigo,
                  title: 'Agents',
                  subtitle: 'Manage agent profiles & files',
                  onTap: () => _push(context, const AgentsScreen()),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              header: const Text('AUTOMATION'),
              children: [
                _NavTile(
                  icon: CupertinoIcons.clock,
                  iconColor: CupertinoColors.systemBlue,
                  title: 'Cron Jobs',
                  subtitle: 'Scheduled tasks & reminders',
                  onTap: () => _push(context, const CronScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.bubble_left_bubble_right,
                  iconColor: CupertinoColors.systemTeal,
                  title: 'Sessions',
                  subtitle: 'View & manage all sessions',
                  onTap: () => _push(context, const SessionsAdminScreen()),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              header: const Text('INFRASTRUCTURE'),
              children: [
                _NavTile(
                  icon: CupertinoIcons.desktopcomputer,
                  iconColor: CupertinoColors.systemCyan,
                  title: 'Nodes',
                  subtitle: 'Connected devices',
                  onTap: () => _push(context, const NodesScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.device_phone_portrait,
                  iconColor: CupertinoColors.systemMint,
                  title: 'Devices',
                  subtitle: 'Paired clients & approvals',
                  onTap: () => _push(context, const DevicesScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.shield,
                  iconColor: CupertinoColors.systemRed,
                  title: 'Exec Permissions',
                  subtitle: 'Allowlists & security policy',
                  onTap: () => _push(context, const ExecApprovalsScreen()),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              header: const Text('ADVANCED'),
              children: [
                _NavTile(
                  icon: CupertinoIcons.doc_text,
                  iconColor: CupertinoColors.systemGrey,
                  title: 'Configuration',
                  subtitle: 'Raw JSON config editor',
                  onTap: () => _push(context, const ConfigScreen()),
                ),
                _NavTile(
                  icon: CupertinoIcons.text_alignleft,
                  iconColor: CupertinoColors.systemBrown,
                  title: 'Logs',
                  subtitle: 'Gateway log viewer',
                  onTap: () => _push(context, const LogsScreen()),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              children: [
                _NavTile(
                  icon: CupertinoIcons.info_circle,
                  iconColor: CupertinoColors.systemBlue,
                  title: 'About',
                  onTap: () => _push(context, const AboutScreen()),
                ),
                CupertinoListTile(
                  leading: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      CupertinoIcons.power,
                      color: CupertinoColors.white,
                      size: 18,
                    ),
                  ),
                  title: const Text(
                    'Disconnect',
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
                  onTap: () => _confirmDisconnect(context),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => screen),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Remove gateway connection and device identity?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await context.read<GatewayProvider>().disconnect();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            child: const Text('Disconnect'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  final GatewayProvider gw;

  const _GatewayCard({required this.gw});

  @override
  Widget build(BuildContext context) {
    final url = gw.credentials?.url ?? 'Not connected';
    final hello = gw.client?.helloResult;
    final version = hello?['version'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🦞', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                'OpenClaw Gateway',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const Spacer(),
              _StatusPill(connected: gw.isConnected),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            url,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 13,
              fontFamily: 'Menlo',
            ),
          ),
          if (version != null)
            Text(
              'v$version',
              style: const TextStyle(
                color: CupertinoColors.tertiaryLabel,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool connected;

  const _StatusPill({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: connected
            ? CupertinoColors.systemGreen.withValues(alpha: 0.15)
            : CupertinoColors.systemRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: connected ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            connected ? 'Connected' : 'Offline',
            style: TextStyle(
              color: connected ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: iconColor,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: CupertinoColors.white, size: 18),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
