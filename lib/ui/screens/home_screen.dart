/// 首页：模式入口 + 主题设置。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/engine/ai_service.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/theme_provider.dart';
import 'package:five/ui/screens/game_screen.dart';
import 'package:five/ui/screens/online_lobby_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// 弹出难度选择，选定后配置对局并进入对局页。
  Future<void> _pickDifficultyAndStart(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final level = await showDialog<AiLevel>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.chooseDifficulty),
        children: [
          for (final level in AiLevel.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, level),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      switch (level) {
                        AiLevel.easy => Icons.sentiment_satisfied_rounded,
                        AiLevel.medium => Icons.sentiment_neutral_rounded,
                        AiLevel.hard => Icons.local_fire_department_rounded,
                      },
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      switch (level) {
                        AiLevel.easy => l10n.aiEasy,
                        AiLevel.medium => l10n.aiMedium,
                        AiLevel.hard => l10n.aiHard,
                      },
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (level == null || !context.mounted) return;
    ref.read(gameControllerProvider.notifier).startNewGame(
          mode: GameMode.vsAi,
          aiLevel: level,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen.vsAi(level)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          // 内容限宽居中：手机上自然占满，桌面上不会拉成一条横幅。
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // —— 品牌区 ——
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.displayLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeSubtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // —— 模式入口 ——
                _ModeCard(
                  icon: Icons.people_alt_rounded,
                  title: l10n.localTwoPlayer,
                  subtitle: l10n.localTwoPlayerDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const GameScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  icon: Icons.psychology_rounded,
                  title: l10n.vsAi,
                  subtitle: l10n.chooseDifficulty,
                  onTap: () => _pickDifficultyAndStart(context, ref),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  icon: Icons.wifi_rounded,
                  title: l10n.onlineMode,
                  subtitle: l10n.createRoom,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const OnlineLobbyScreen()),
                  ),
                ),
                const SizedBox(height: 32),

                // —— 设置区 ——
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette_outlined,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(l10n.themeModeTitle,
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Material 3 分段按钮：三个互斥选项一目了然。
                        SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                                value: ThemeMode.system,
                                label: Text(l10n.themeSystem)),
                            ButtonSegment(
                                value: ThemeMode.light,
                                label: Text(l10n.themeLight)),
                            ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text(l10n.themeDark)),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (selection) => ref
                              .read(themeModeProvider.notifier)
                              .set(selection.first),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 首页模式入口卡片。
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias, // 让水波纹不溢出圆角
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
