<p align="center">
  <img src="docs/screenshots/Chat.png" alt="CoralDesk" />
</p>

<h1 align="center">CoralDesk 🦀</h1>

<p align="center">
  <strong>The native desktop GUI for <a href="https://github.com/zeroclaw-labs/zeroclaw">ZeroClaw</a> — fast, small, and fully autonomous AI assistant infrastructure.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Rust-1.x-CE422B?logo=rust&logoColor=white" alt="Rust" />
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platforms" />
  <img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License" />
</p>

<p align="center">
  🌐 <a href="README.md"><b>English</b></a> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="#getting-started">Getting Started</a> · <a href="#features">Features</a> · <a href="#architecture">Architecture</a>
</p>

---

## Overview

[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) is a lean, fully autonomous AI agent runtime written in Rust — zero overhead, provider-agnostic, and deployable anywhere from a $10 microboard to a cloud VM. It ships as a single binary with <5 MB RAM footprint, supporting swappable providers, channels, tools, memory backends, and tunnels.

**CoralDesk** wraps the ZeroClaw runtime in a polished, cross-platform desktop application built with Flutter. The ZeroClaw Rust library is embedded **in-process** via [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) (FFI) — there is no HTTP server, no subprocess, no daemon to manage. You get the full power of the ZeroClaw agent engine with a native, responsive UI.

> Deploy anywhere. Swap anything. — now with a face.

---

## Features

### 💬 Chat
- Streaming AI responses with real-time display
- Markdown rendering (code blocks, lists, bold/italic, etc.)
- Multi-session management — create, rename, and switch between chat sessions
- Auto-titled sessions based on the first message
- File attachment support
- Task plan overlay for visualizing agent steps

### 📁 Projects
- Create, edit, and manage projects with templates
- Per-project status tracking and filtering
- Drill into project details from a master list

### 📡 Channels
- View and manage all active communication channels (Telegram, etc.)
- GUI-based per-channel configuration — no config file editing needed
- Start/stop channel listeners from within the app

### 👥 Sessions
- Browse all active and historical agent sessions
- Inspect session state and message history

### ⏰ Cron Jobs
- Schedule recurring tasks with cron expressions
- View run history per job
- Manually trigger jobs and monitor execution

### 🧠 Knowledge Base
- Manage the agent's long-term memory entries
- Search, browse, add, and delete knowledge entries by category

### 🎯 Skills
- Browse and install community (open) skills
- Enable/disable individual skills
- Manage custom skill configurations

### 🔌 MCP (Model Context Protocol)
- Add, edit, and remove MCP tool servers
- Test server connectivity and discover available tools in-app
- Per-server connection status display

### 🤖 Agents & Workspaces
- Configure delegate/sub-agents with custom roles and provider overrides
- Manage multiple agent workspaces with independent root paths

### ⚙️ Configuration
- Autonomy level controls (supervised ↔ autonomous)
- Per-tool permission management (allow / deny / confirm)
- Agent loop parameters (max iterations, tool call limits)
- Cost budgeting and limits

### 🤖 Models & Providers
- Configure AI providers: **OpenRouter**, **OpenAI**, **Anthropic**, **Ollama**, **OpenAI-compatible endpoints**, and more
- Per-provider API key and base URL management
- Model selection with free-text input for flexible model names
- Adjustable temperature slider

### 🌐 Proxy
- Global outbound proxy configuration
- Granular per-service proxy rules (provider, channel, tool, memory, tunnel)
- HTTP / HTTPS / SOCKS proxy support

### 🌓 Preferences
- Light and dark mode with system-follow support
- Language selection (English / 简体中文)
- In-app update checker
- Clean, modern UI using Google Fonts and Lucide Icons

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                Flutter (Dart)                   │
│  Riverpod state · go_router · Material 3 UI    │
│                                                 │
│  Chat  ·  Models  ·  Channels  ·  Workspace    │
│         Configuration  ·  Settings             │
└───────────────────┬─────────────────────────────┘
                    │ flutter_rust_bridge (FFI)
┌───────────────────▼─────────────────────────────┐
│              Rust (rust_lib_coraldesk)           │
│                                                 │
│   agent_api · config_api · workspace_api       │
│                                                 │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│           ZeroClaw Runtime (Rust crate)         │
│  Providers · Channels · Tools · Memory · Tunnels│
└─────────────────────────────────────────────────┘
```

The Flutter UI communicates with the ZeroClaw Rust runtime through a generated FFI bridge, meaning **all AI logic runs natively in-process** — no HTTP server, no subprocess.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.x (`sdk: ^3.9.2`) |
| Rust toolchain | stable (latest recommended) |
| Dart | included with Flutter |

For platform-specific build toolchains (Xcode, Android SDK, etc.) see the [Flutter install docs](https://docs.flutter.dev/get-started/install).

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-org/coraldesk.git
cd coraldesk
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Build the Rust bridge code (if needed)

```bash
flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
```

### 4. Configure CoralDesk

CoralDesk reads the config from `~/.coraldesk/config.toml` at startup. Create the file if it does not exist:

```toml
# ~/.coraldesk/config.toml
provider  = "openrouter"
model     = "anthropic/claude-sonnet-4-20250514"
api_key   = "sk-or-..."
temperature = 0.7
max_tool_iterations = 10
```

You can also configure everything from within the app's **Models** settings page.

### 5. Run the app

```bash
# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Windows
flutter run -d windows

```

### 6. Rust logging (debugging)

Rust logs are now initialized at app startup and default to `info` level.

```bash
# Default (already enabled by the app)
flutter run -d macos

# More verbose logs (recommended while debugging)
RUST_LOG=debug flutter run -d macos

# Very verbose logs for Rust internals
RUST_LOG=trace flutter run -d macos
```

If you launch from VS Code, set `RUST_LOG` in your debug configuration `env` to see the same behavior.

---

## Screenshots

| Chat | Channels |
|------|----------|
| ![Chat](docs/screenshots/Chat.png) | ![Channels](docs/screenshots/Channels.png) |

| Skills | MCP |
|--------|-----|
| ![Skills](docs/screenshots/Skills.png) | ![MCP](docs/screenshots/MCP.png) |

<p align="center">
  <img src="docs/screenshots/Preferences.png" alt="Preferences" width="70%" />
</p>

---

## Project Structure

```
lib/
├── main.dart              # App entry point, ZeroClaw runtime init
├── constants.dart         # App-wide constants
├── models/                # Freezed data models (ChatMessage, ChatSession, Project…)
├── providers/             # Riverpod providers (chat, sessions, theme, projects…)
├── services/              # UpdateService, MCP test client, etc.
├── theme/                 # Light / dark AppTheme
├── views/
│   ├── shell/             # Root layout shell (sidebar + panels)
│   ├── sidebar/           # Collapsible navigation sidebar
│   ├── chat/              # Chat list, chat view, input bar, message bubble
│   ├── project/           # Projects list and detail view
│   ├── notification/      # Notification panel
│   └── settings/          # All settings pages:
│       ├── channels_page.dart
│       ├── sessions_page.dart
│       ├── cron_jobs_page.dart
│       ├── knowledge_page.dart
│       ├── skills_page.dart
│       ├── mcp_page.dart
│       ├── agents_page.dart
│       ├── agent_workspaces_page.dart
│       ├── configuration_page.dart
│       ├── models_page.dart
│       ├── proxy_page.dart
│       ├── llm_debug_page.dart
│       └── app_settings_page.dart
rust/
└── src/
    └── api/               # flutter_rust_bridge API definitions
zeroclaw/                  # ZeroClaw Rust crate (git submodule / local path dep)
```

---

## Contributing

Contributions are welcome! Please open an issue or pull request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit your changes: `git commit -m "feat: add my feature"`
4. Push and open a PR

---

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)** — see [LICENSE](LICENSE) for details.
