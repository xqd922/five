# Five · 五子棋

全平台无禁手五子棋，Flutter + Material 3 构建。

一套代码，覆盖 **Android / iOS / Windows / macOS / Linux** 五端，附带自研 **WebSocket 对战服务端**。

## 特性

- 🎮 **三种模式**：人机对战（三档难度）/ 本地双人 / 在线联机（房间码制）
- 🧠 **竞技级 AI 引擎**：Alpha-Beta 剪枝 + 迭代加深 + 棋型评估，Isolate 后台计算零卡顿
- 🌐 **在线对战**：自建 WebSocket 服务端权威判定，断线重连、超时判负、再战互换黑白
- ✋ **完整辅助**：AI 提示、复盘回放、SGF 棋谱导出、手数标记
- 📊 **战绩统计**：人机胜负记录本地持久化
- 🎨 **Material 3**：种子色派生明暗双主题，棋盘配色随主题自适应，落子弹入动画
- ⌨️ **桌面体验**：窗口尺寸管理、Ctrl+Z 悔棋 / Ctrl+R 重开 / Ctrl+H 提示
- 🌐 **中英双语**，系统语言自动切换
- 💾 **纯本地数据**，无账号无追踪；联机模式无需注册，房号即入场券

## 开发路线

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | 规则引擎 + 本地双人 + 手绘棋盘 | ✅ |
| M2 | AI 引擎（Isolate 后台搜索）+ 难度分级 | ✅ |
| M3 | 辅助功能（提示/复盘/SGF/手数） | ✅ |
| M4 | 桌面端打磨（窗口管理、快捷键）+ Android 验证 | ✅ |
| M5 | 在线对战（服务端 + 客户端全链路） | ✅ |

## 从源码构建

```bash
# 客户端
flutter pub get
flutter test          # 34+ 单元测试
flutter run -d windows

# 本地发布包（可选——正式发版走 CI，见下）
flutter build apk --release          # Android
flutter build windows --release      # Windows

# 服务端（见下节）
```

## 发版（全自动）

推送 `v*` 标签即触发 GitHub Actions 双平台构建，产物自动挂到 Release：

```bash
git tag v1.x.y && git push origin v1.x.y
```

日常推送由 CI 自动执行：分析 + 测试（客户端与服务端）+ Windows/APK 打包，
产物可在 Actions 页面的 Artifacts 下载。

> Android APK 使用 debug 签名（自用/侧载足够；上架商店需配置正式签名）。

> Windows 桌面构建需要 Visual Studio 2022「使用 C++ 的桌面开发」工作负载；
> 插件构建需要开启 Windows 开发者模式。

## 对战服务器

服务端是纯 Dart 程序，与客户端共享同一份规则引擎（`packages/five_core`），
胜负判定权威在服务端。

```bash
cd server
dart pub get
dart test                        # 房间生命周期测试
PORT=8080 dart run bin/server.dart
```

客户端在「在线对战 → 对战服务器」填入 `ws://<你的服务器>:8080` 即可。

**部署**：任何能跑 Dart 的环境均可（VPS / Docker / 云函数容器）。
健康检查端点：`GET /health`。

## 目录结构

```
lib/                  # Flutter 客户端
├── engine/           # AI 引擎：评估、候选、搜索、Isolate 调度
├── state/            # Riverpod 状态：对局/在线/主题/设置/战绩
├── network/          # WebSocket 客户端封装
├── ui/               # CustomPainter 棋盘 + 页面
└── l10n/             # 中英文案
packages/five_core/   # 共享核心：棋盘、规则、SGF、通信协议
server/               # WebSocket 对战服务端
tool/                 # 开发脚本（图标生成等）
```

## License

MIT
