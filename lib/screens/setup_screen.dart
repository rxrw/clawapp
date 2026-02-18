import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../core/storage.dart';
import '../providers/gateway_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController(text: 'ws://192.168.6.6:18789');
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _useToken = false;
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a gateway URL');
      return;
    }

    final creds = GatewayCredentials(
      url: url,
      password: _useToken ? null : _passwordController.text.trim().nullIfEmpty,
      token: _useToken ? _tokenController.text.trim().nullIfEmpty : null,
    );

    setState(() {
      _connecting = true;
      _error = null;
    });

    await context.read<GatewayProvider>().connect(creds);
    setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Connect to Gateway'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo / header
              const Center(
                child: Column(
                  children: [
                    Text('🦞', style: TextStyle(fontSize: 72)),
                    SizedBox(height: 8),
                    Text(
                      'ClawApp',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'OpenClaw Mobile Client',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Gateway URL
              CupertinoListSection.insetGrouped(
                header: const Text('Gateway'),
                children: [
                  CupertinoListTile(
                    title: const Text('URL'),
                    trailing: SizedBox(
                      width: 200,
                      child: CupertinoTextField(
                        controller: _urlController,
                        placeholder: 'ws://192.168.x.x:18789',
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 15),
                        decoration: const BoxDecoration(),
                      ),
                    ),
                  ),
                ],
              ),

              // Auth type toggle
              CupertinoListSection.insetGrouped(
                header: const Text('Authentication'),
                children: [
                  CupertinoListTile(
                    title: const Text('Use Token'),
                    trailing: CupertinoSwitch(
                      value: _useToken,
                      onChanged: (v) => setState(() => _useToken = v),
                    ),
                  ),
                  if (!_useToken)
                    CupertinoListTile(
                      title: const Text('Password'),
                      trailing: SizedBox(
                        width: 200,
                        child: CupertinoTextField(
                          controller: _passwordController,
                          placeholder: 'gateway password',
                          obscureText: true,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 15),
                          decoration: const BoxDecoration(),
                        ),
                      ),
                    ),
                  if (_useToken)
                    CupertinoListTile(
                      title: const Text('Token'),
                      trailing: SizedBox(
                        width: 200,
                        child: CupertinoTextField(
                          controller: _tokenController,
                          placeholder: 'gateway token',
                          obscureText: true,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 15),
                          decoration: const BoxDecoration(),
                        ),
                      ),
                    ),
                ],
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton.filled(
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Connect'),
                ),
              ),

              const SizedBox(height: 32),

              // Pairing hint
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'First connection from a new device requires pairing approval on the gateway host:\n  openclaw devices list\n  openclaw devices approve <id>',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
