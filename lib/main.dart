/// 应用入口。
///
/// 启动流程：
/// 1. 等待 Flutter 引擎绑定完毕；
/// 2. 读取本地偏好存储（主题模式等），注入 Riverpod 容器；
/// 3. 挂载根组件 [FiveApp]。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/theme_provider.dart';
import 'package:five/ui/screens/home_screen.dart';

/// Material 3 的主题种子色：深青瓷色。
/// 明暗两套 ColorScheme 全部由它自动派生，换主题色只改这一处。
const Color _seedColor = Color(0xFF00696E);

Future<void> main() async {
  // 在使用任何插件/异步初始化前必须先确保引擎就绪。
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // 把真实磁盘上的偏好数据交给容器——
        // 之后任何 provider 都能通过 sharedPreferencesProvider 拿到它。
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FiveApp(),
    ),
  );
}

class FiveApp extends ConsumerWidget {
  const FiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

      // —— 国际化 ——
      localizationsDelegates: const [
        AppLocalizations.delegate, // 我们自己的 arb 文案
        GlobalMaterialLocalizations.delegate, // Material 内置控件文案
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales, // en + zh

      // —— Material 3 双主题 ——
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeMode,

      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
