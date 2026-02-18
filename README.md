# ClawApp 🦞

Native mobile client for [OpenClaw](https://github.com/openclaw/openclaw) — the open-source AI assistant gateway.

ClawApp connects directly to your OpenClaw Gateway via WebSocket, giving you a full-featured iOS-style interface to manage sessions, chat, and configure your gateway from anywhere.

## Features

### 💬 Chat & Sessions
- Session list with real-time updates
- Full chat interface with Markdown rendering
- Streaming responses with live token output
- Send messages, abort running tasks
- Start new conversations

### ⚙️ Full Settings Console
- **Channels** — WhatsApp, Telegram, Slack status & config
- **Models** — List available models, set defaults
- **Skills** — Enable/disable/install skills
- **Agents** — View agent profiles, edit workspace files (SOUL.md, AGENTS.md, etc.)
- **Cron Jobs** — List, enable/disable, trigger, delete scheduled tasks
- **Sessions Admin** — Reset, compact, delete, set model/thinking overrides, view usage
- **Nodes** — Connected devices, rename, describe
- **Devices** — Paired client management, approve/reject/revoke
- **Exec Permissions** — Security policy & allowlist viewer
- **Logs** — Live gateway log viewer with filtering
- **Configuration** — Raw JSON config editor with validation

### 🔐 Security
- Ed25519 device identity (auto-generated, stored in secure storage)
- Full OpenClaw device pairing protocol support
- Password or token authentication
- Credentials stored in platform secure storage (Keychain on iOS/macOS)

## Architecture

```
┌──────────────┐     WebSocket (RPC)     ┌──────────────────┐
│   ClawApp     │ ◄──────────────────────► │  OpenClaw Gateway │
│   (Flutter)   │   Ed25519 signed auth   │  (Node.js)        │
└──────────────┘                          └──────────────────┘
```

ClawApp speaks the same WebSocket RPC protocol as OpenClaw's built-in web dashboard. No additional server-side plugins or configuration needed — just point it at your gateway URL and authenticate.

### RPC Methods Used
- `chat.send`, `chat.history`, `chat.abort` — messaging
- `sessions.list`, `sessions.patch`, `sessions.reset`, `sessions.delete`, `sessions.compact`, `sessions.usage` — session management
- `config.get`, `config.set`, `config.patch`, `config.schema` — configuration
- `models.list`, `skills.status`, `skills.enable`, `skills.disable`, `skills.install` — AI & tools
- `cron.list`, `cron.update`, `cron.run`, `cron.remove` — automation
- `channels.status` — channel management
- `agents.list`, `agents.files.list`, `agents.files.get`, `agents.files.set` — agent management
- `node.list`, `node.describe`, `node.rename` — infrastructure
- `device.pair.list`, `device.pair.approve`, `device.pair.reject`, `device.token.revoke` — device management
- `exec.approvals.get` — security policy
- `logs.tail` — diagnostics

## Requirements

- Flutter 3.41+ / Dart 3.11+
- An OpenClaw Gateway instance (v2026.2+)
- Gateway URL + password or token

## Getting Started

```bash
# Clone
git clone https://github.com/rxrw/clawapp.git
cd clawapp

# Install deps
flutter pub get

# Run on iOS Simulator
flutter run -d ios

# Run on macOS
flutter run -d macos

# Run on Android
flutter run -d android
```

On first launch, enter your Gateway WebSocket URL (e.g. `ws://192.168.1.100:18789`) and password/token. If connecting from a new device remotely, you'll need to approve the pairing on your gateway host:

```bash
openclaw devices list
openclaw devices approve <requestId>
```

## Project Structure

```
lib/
├── core/                  # Gateway client, device identity, storage
│   ├── device_identity.dart   # Ed25519 key management
│   ├── gateway_client.dart    # WebSocket RPC client
│   └── storage.dart           # Secure credential storage
├── models/                # Data models
│   ├── message.dart
│   └── session.dart
├── providers/             # State management (Provider)
│   ├── chat_provider.dart
│   ├── gateway_provider.dart
│   └── sessions_provider.dart
├── screens/               # UI screens
│   ├── chat_screen.dart
│   ├── sessions_screen.dart
│   ├── setup_screen.dart
│   └── settings/
│       ├── settings_screen.dart
│       ├── agents_screen.dart
│       ├── channels_screen.dart
│       ├── config_screen.dart
│       ├── cron_screen.dart
│       ├── devices_screen.dart
│       ├── exec_approvals_screen.dart
│       ├── logs_screen.dart
│       ├── models_screen.dart
│       ├── nodes_screen.dart
│       ├── sessions_admin_screen.dart
│       ├── skills_screen.dart
│       └── about_screen.dart
├── widgets/               # Reusable widgets
├── app.dart
└── main.dart
```

## Design

- **iOS-native look** using Cupertino widgets throughout
- iMessage-style chat bubbles with assistant avatar
- Settings modeled after iOS Settings app (grouped list sections)
- Connection status indicator (green/orange/red dot)
- Pull-to-refresh on session list

## Roadmap

- [ ] Config schema form rendering (dynamic forms from `config.schema`)
- [ ] MCP server management page
- [ ] Dark mode theming
- [ ] Haptic feedback
- [ ] Swipe gestures on session list
- [ ] Push notifications via gateway events
- [ ] Bonjour/mDNS gateway auto-discovery

## License

MIT

## Credits

Built by [Claw](https://github.com/openclaw/openclaw) 🦞 — an AI that wrote its own mobile app.
