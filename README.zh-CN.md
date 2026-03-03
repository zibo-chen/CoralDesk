<p align="center">
  <!-- 替换为你的 App Logo/截图 -->
  <!-- <img src="docs/screenshots/logo.png" alt="CoralDesk" width="120" /> -->
</p>

<h1 align="center">CoralDesk 🦀</h1>

<p align="center">
  <strong><a href="https://github.com/zeroclaw-labs/zeroclaw">ZeroClaw</a> 的原生桌面客户端——快速、轻量、完全自主的 AI 助手基础设施，现在拥有了图形界面。</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Rust-1.x-CE422B?logo=rust&logoColor=white" alt="Rust" />
  <img src="https://img.shields.io/badge/平台-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="平台" />
  <img src="https://img.shields.io/badge/许可证-AGPL--3.0-blue" alt="License" />
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-CN.md"><b>简体中文</b></a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> · <a href="#功能特性">功能特性</a> · <a href="#架构">架构</a>
</p>

---

## 项目简介

[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) 是一个用 Rust 编写的轻量级、完全自主的 AI Agent 运行时——零额外开销、不绑定任何 AI 提供商，可部署在从 10 美元微型开发板到云服务器的任何环境中。它以单一二进制文件交付，运行时内存占用不足 5 MB，支持按需替换 AI 提供商、通信渠道、工具、记忆后端和网络穿透组件。

**CoralDesk** 将 ZeroClaw 运行时包装进一个基于 Flutter 构建的、跨平台的原生桌面应用。ZeroClaw 的 Rust 库通过 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)（FFI）**直接嵌入进程内**——无需 HTTP 服务进程，无需子进程，无需守护程序。你可以获得 ZeroClaw Agent 引擎的完整能力，同时拥有流畅、原生的图形界面。

> 随处部署，随意替换。——现在有了界面。

<!-- 截图占位符 -->
<!-- ![CoralDesk 主界面](docs/screenshots/main.png) -->

---

## 功能特性

### 💬 对话
- AI 响应流式实时显示
- Markdown 渲染（代码块、列表、粗体/斜体等）
- 多会话管理——创建、重命名、自由切换
- 根据首条消息自动为会话生成标题

### 🤖 模型与提供商
- 支持多家 AI 提供商：**OpenRouter**、**OpenAI**、**Anthropic**、**Ollama** 及兼容 OpenAI 协议的自定义端点
- 每个提供商独立配置 API Key 和 Base URL
- 自由输入模型名称，灵活选用任意可用模型
- 可调节 Temperature 参数

### 📡 通信渠道
- 查看并管理所有活跃通信渠道
- 支持单独启用/禁用各渠道

### 🏗️ 工作空间与 Agent
- 配置文件系统工具的工作空间根目录
- 设置 Agent 循环参数（最大迭代次数、工具调用次数上限）
- 记忆模块配置
- 成本预算与用量上限控制

### ⚙️ 配置管理
- 自主级别调节（监督模式 ↔ 完全自主模式）
- 逐工具权限控制（允许 / 拒绝 / 每次确认）

### 🌓 主题
- 明暗模式，支持跟随系统设置自动切换
- 基于 Google Fonts 与 Lucide Icons 的简洁现代 UI

### 规划中 / 开发中
- 会话历史查看器
- 定时任务 / Cron 调度
- 技能与自定义提示词管理
- MCP（Model Context Protocol）服务器配置
- 环境变量配置文件

---

## 架构

```
┌─────────────────────────────────────────────────┐
│              Flutter（Dart）界面层               │
│  Riverpod 状态管理 · go_router · Material 3 UI  │
│                                                 │
│  对话  ·  模型  ·  渠道  ·  工作空间  ·  设置   │
└───────────────────┬─────────────────────────────┘
                    │ flutter_rust_bridge（FFI）
┌───────────────────▼─────────────────────────────┐
│          Rust 桥接层（rust_lib_coraldesk）         │
│                                                 │
│   agent_api · config_api · workspace_api        │
│                                                 │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│           ZeroClaw 运行时（Rust crate）           │
│  Providers · Channels · Tools · Memory · Tunnels│
└─────────────────────────────────────────────────┘
```

Flutter UI 通过生成的 FFI 桥直接与 ZeroClaw Rust 运行时通信，意味着**所有 AI 逻辑在本进程内原生运行**——无 HTTP 服务器，无子进程。

---

## 环境要求

| 工具 | 版本要求 |
|------|---------|
| Flutter SDK | ≥ 3.x（`sdk: ^3.9.2`） |
| Rust 工具链 | stable（推荐最新版） |
| Dart | 随 Flutter 附带 |

各平台特定构建工具链（Xcode、Android SDK 等）请参阅 [Flutter 安装文档](https://docs.flutter.dev/get-started/install)。

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/zibo-chen/coraldesk.git
cd coraldesk
```

### 2. 安装 Flutter 依赖

```bash
flutter pub get
```

### 3. 生成 Rust 桥接代码（如需）

```bash
flutter_rust_bridge_codegen generate
```

### 4. 配置 ZeroClaw

CoralDesk 启动时从 `~/.zeroclaw/config.toml` 读取配置，若文件不存在请手动创建：

```toml
# ~/.zeroclaw/config.toml
provider     = "openrouter"
model        = "anthropic/claude-sonnet-4-20250514"
api_key      = "sk-or-..."
temperature  = 0.7
max_tool_iterations = 10
```

也可以在应用的**模型**设置页面内完成全部配置。

### 5. 运行应用

```bash
# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Windows
flutter run -d windows
```

### 6. Rust 日志（调试）

应用启动时会自动初始化 Rust 日志，默认级别为 `info`。

```bash
# 默认（应用已自动开启）
flutter run -d macos

# 调试时建议使用更详细日志
RUST_LOG=debug flutter run -d macos

# 查看最详细的 Rust 内部日志
RUST_LOG=trace flutter run -d macos
```

如果你使用 VS Code 启动，请在调试配置的 `env` 里设置 `RUST_LOG`，即可获得相同行为。

---

## 截图

![对话界面](docs/screenshots/chat.jpg)

---

## 项目结构

```
lib/
├── main.dart              # 应用入口，ZeroClaw 运行时初始化
├── constants.dart         # 全局常量
├── models/                # Freezed 数据模型（ChatMessage、ChatSession 等）
├── providers/             # Riverpod 状态提供者（对话、会话、主题等）
├── theme/                 # 明/暗主题定义
├── views/
│   ├── shell/             # 根布局（侧边栏 + 面板）
│   ├── sidebar/           # 图标导航侧边栏
│   ├── chat/              # 对话列表、对话视图、输入栏、消息气泡
│   └── settings/          # 模型、渠道、工作空间、配置设置页
rust/
└── src/
    └── api/               # flutter_rust_bridge API 定义
zeroclaw/                  # ZeroClaw Rust crate（Git 子模块 / 本地路径依赖）
```

---

## 贡献

欢迎提交 Issue 或 Pull Request！

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feat/my-feature`
3. 提交更改：`git commit -m "feat: 添加新功能"`
4. 推送并创建 PR

---

## 许可证

本项目采用 **GNU Affero 通用公共许可证第 3 版（AGPL-3.0）**，详见 [LICENSE](LICENSE)。

内嵌的 [ZeroClaw](zeroclaw/) 运行时采用 MIT / Apache-2.0 双重许可证。
