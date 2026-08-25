# Five · 五子棋

全平台无禁手五子棋，Flutter + Material 3 构建。

一套代码，覆盖 **Android / iOS / Windows / macOS / Linux** 五端。

## 特性

- 🎮 人机对战（竞技级 AI 引擎）与本地双人对战
- 🧠 AI：Alpha-Beta 剪枝 + 迭代加深 + Zobrist 置换表 + VCF/VCT 算杀（开发中）
- ✋ 悔棋、AI 提示、复盘回放、SGF 棋谱导出、手数标记
- 🎨 Material 3 动态主题：种子色派生明暗双主题，棋盘配色随主题自适应
- 🌐 中英双语界面
- 💾 战绩与设置纯本地存储，零服务器依赖
- 🔌 对局抽象为统一 `GameSession` 接口，为在线联机预留扩展点

## 开发路线

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | 规则引擎 + 本地双人 + 手绘棋盘 | ✅ |
| M2 | AI 引擎（Isolate 后台搜索）+ 难度分级 | ✅ |
| M3 | 辅助功能（提示/复盘/SGF/手数） | ✅ |
| M4 | 桌面端打磨（窗口管理、快捷键）+ Android 验证 | ✅ |
| M5 | 在线对战 | 计划中 |

## 从源码构建

```bash
# 依赖安装
flutter pub get

# 运行单元测试（规则引擎）
flutter test

# Windows 桌面运行
flutter run -d windows

# Android 构建发布包
flutter build apk --release

# Windows 构建发布包
flutter build windows --release
```

> Windows 桌面构建需要 Visual Studio 2022 的「使用 C++ 的桌面开发」工作负载；
> 插件构建需要开启 Windows 开发者模式。

## 目录结构

```
lib/
├── core/        # 纯 Dart 核心：棋盘数据结构、规则引擎（零 Flutter 依赖，可单测）
├── engine/      # AI 引擎（M2）：评估函数、搜索、Isolate 调度
├── state/       # Riverpod 状态层：对局状态机、主题偏好
├── ui/          # 界面：CustomPainter 棋盘、页面、组件
└── l10n/        # 中英文案（arb 文件）+ 生成的本地化代码
```

## License

MIT
