import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/gateway_provider.dart';
import 'screens/setup_screen.dart';
import 'screens/sessions_screen.dart';

class ClawApp extends StatelessWidget {
  const ClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'ClawApp',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: _RootRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final gw = context.watch<GatewayProvider>();

    if (!gw.initialized) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (gw.credentials == null) {
      return const SetupScreen();
    }

    return const SessionsScreen();
  }
}
