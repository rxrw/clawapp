import 'package:flutter/cupertino.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('About ClawApp'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            SizedBox(height: 24),
            Center(child: Text('🦞', style: TextStyle(fontSize: 56))),
            SizedBox(height: 8),
            Center(
              child: Text(
                'ClawApp',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 4),
            Center(
              child: Text(
                'OpenClaw Mobile Client',
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
            SizedBox(height: 24),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: Text('Version'),
                  trailing: Text('1.0.0'),
                ),
                CupertinoListTile(
                  title: Text('Design'),
                  trailing: Text('iOS Native (Cupertino)'),
                ),
                CupertinoListTile(
                  title: Text('Backend'),
                  trailing: Text('OpenClaw Gateway RPC'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
