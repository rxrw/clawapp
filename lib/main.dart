import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/gateway_provider.dart';
import 'providers/sessions_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final gatewayProvider = GatewayProvider();
  await gatewayProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gatewayProvider),
        ChangeNotifierProxyProvider<GatewayProvider, SessionsProvider>(
          create: (ctx) => SessionsProvider(gatewayProvider),
          update: (ctx, gw, prev) => prev ?? SessionsProvider(gw),
        ),
      ],
      child: const ClawApp(),
    ),
  );
}
