/// 首页：模式入口 + 战绩概览 + 主题设置。
///
/// 【Google 设计哲学】
/// - 大胆排版：品牌区用 displayLarge + 主色强调，一眼抓住用户
/// - 内容优先：模式卡片用图标色块 + 简洁文案，去除冗余装饰
/// - 有意图的动效：交错入场引导视线流向，不为炫技而动
/// - 无障碍：所有交互元素 ≥ 48dp 触控目标，语义清晰
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/engine/ai_service.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/stats_provider.dart';
import 'package:five/state/theme_provider.dart';
import 'package:five/ui/effects/effects.dart';
import 'package:five/ui/screens/game_screen.dart';
import 'package:five/ui/screens/online_lobby_screen.dart';
import 'package:five/ui/theme/m3_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// 弹出难度选择，选定后配置对局并进入对局页。
  Future<void> _pickDifficultyAndStart(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final level = await showModalBottomSheet<AiLevel>(
      context: context,
      // M3: 底部弹出表单，比 Dialog 更符合拇指操作习惯。
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
              child: Text(
                l10n.chooseDifficulty,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final level in AiLevel.values)
              _DifficultyTile(level: level),
          ],
        ),
      ),
    );

    if (level == null || !context.mounted) return;
    ref.read(gameControllerProvider.notifier).startNewGame(
          mode: GameMode.vsAi,
          aiLevel: level,
        );
    Navigator.of(context).push(
      SlideUpRoute<void>(builder: (_) => GameScreen.vsAi(level)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              slivers: [
                // —— 品牌区：大胆排版 ——
                SliverToBoxAdapter(
                  child: StaggeredEntry(
                    index: 0,
                    offset: const Offset(0, 40),
                    child: _HeroSection(l10n: l10n, colorScheme: colorScheme),
                  ),
                ),

                // —— 模式入口：视觉色块卡片 ——
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: M3Tokens.spaceXL),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: M3Tokens.spaceXXL),
                      StaggeredEntry(
                        index: 1,
                        child: _VisualModeCard(
                          icon: Icons.people_alt_rounded,
                          title: l10n.localTwoPlayer,
                          subtitle: l10n.localTwoPlayerDesc,
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(
                            SlideUpRoute<void>(
                                builder: (_) => const GameScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(height: M3Tokens.spaceM),
                      StaggeredEntry(
                        index: 2,
                        child: _VisualModeCard(
                          icon: Icons.psychology_rounded,
                          title: l10n.vsAi,
                          subtitle: l10n.chooseDifficulty,
                          colorScheme: colorScheme,
                          onTap: () =>
                              _pickDifficultyAndStart(context, ref),
                        ),
                      ),
                      const SizedBox(height: M3Tokens.spaceM),
                      StaggeredEntry(
                        index: 3,
                        child: _VisualModeCard(
                          icon: Icons.wifi_rounded,
                          title: l10n.onlineMode,
                          subtitle: l10n.createRoom,
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(
                            SlideUpRoute<void>(
                                builder: (_) => const OnlineLobbyScreen()),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),

                // —— 战绩概览 ——
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      M3Tokens.spaceXL,
                      M3Tokens.spaceXXL,
                      M3Tokens.spaceXL,
                      M3Tokens.spaceM),
                  sliver: SliverToBoxAdapter(
                    child: StaggeredEntry(
                      index: 4,
                      child: _StatsOverview(colorScheme: colorScheme),
                    ),
                  ),
                ),

                // —— 设置区 ——
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: M3Tokens.spaceXL),
                  sliver: SliverToBoxAdapter(
                    child: StaggeredEntry(
                      index: 5,
                      child: _SettingsCard(
                        themeMode: themeMode,
                        colorScheme: colorScheme,
                        l10n: l10n,
                        onThemeChanged: (mode) => ref
                            .read(themeModeProvider.notifier)
                            .set(mode),
                      ),
                    ),
                  ),
                ),

                // 底部安全间距。
                const SliverPadding(
                    padding: EdgeInsets.only(bottom: M3Tokens.spaceXXL)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 品牌区：大胆排版 + 主色强调
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _HeroSection({required this.l10n, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          M3Tokens.spaceXL, M3Tokens.spaceXXXL, M3Tokens.spaceXL, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用 primaryContainer 做品牌色块背景。
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: M3Tokens.spaceL, vertical: M3Tokens.spaceXS),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(M3Tokens.shapeXS),
            ),
            child: Text(
              'GOMOKU',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
            ),
          ),
          const SizedBox(height: M3Tokens.spaceL),
          // displayLarge：最大胆的排版层级。
          Text(
            l10n.appTitle,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: M3Tokens.spaceS),
          Text(
            l10n.homeSubtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 模式入口：视觉色块 + 图标前置
// ---------------------------------------------------------------------------

class _VisualModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _VisualModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // M3: 最小触控目标 48dp。
        child: Padding(
          padding: const EdgeInsets.all(M3Tokens.spaceL),
          child: Row(
            children: [
              // 图标色块：用 primaryContainer 突出但不喧宾。
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(M3Tokens.shapeM),
                ),
                child: Icon(icon,
                    size: 24, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: M3Tokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 难度选择：底部弹出表单的单个选项
// ---------------------------------------------------------------------------

class _DifficultyTile extends StatelessWidget {
  final AiLevel level;

  const _DifficultyTile({required this.level});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, label, description) = switch (level) {
      AiLevel.easy => (
          Icons.sentiment_satisfied_rounded,
          l10n.aiEasy,
          '适合新手入门',
        ),
      AiLevel.medium => (
          Icons.sentiment_neutral_rounded,
          l10n.aiMedium,
          '有一定挑战性',
        ),
      AiLevel.hard => (
          Icons.local_fire_department_rounded,
          l10n.aiHard,
          '竞技级难度',
        ),
    };

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(M3Tokens.shapeS),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: M3Tokens.spaceXL),
      onTap: () => Navigator.pop(context, level),
    );
  }
}

// ---------------------------------------------------------------------------
// 战绩概览：数据可视化风格
// ---------------------------------------------------------------------------

class _StatsOverview extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _StatsOverview({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(statsProvider);
    final total = stats.total;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(M3Tokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard_rounded,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: M3Tokens.spaceS),
                Text(l10n.statsTitle,
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: M3Tokens.spaceL),
            // 进度条：直观显示胜负比例。
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(M3Tokens.shapeXS),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (stats.wins > 0)
                        Expanded(
                          flex: stats.wins,
                          child: Container(color: colorScheme.primary),
                        ),
                      if (stats.draws > 0)
                        Expanded(
                          flex: stats.draws,
                          child: Container(color: colorScheme.outlineVariant),
                        ),
                      if (stats.losses > 0)
                        Expanded(
                          flex: stats.losses,
                          child: Container(color: colorScheme.error),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: M3Tokens.spaceM),
            ],
            // 数字格。
            Row(
              children: [
                _StatChip(
                  label: l10n.statsWins,
                  value: stats.wins,
                  color: colorScheme.primary,
                  icon: Icons.emoji_events_rounded,
                ),
                const SizedBox(width: M3Tokens.spaceS),
                _StatChip(
                  label: l10n.statsDraws,
                  value: stats.draws,
                  color: colorScheme.outline,
                  icon: Icons.handshake_rounded,
                ),
                const SizedBox(width: M3Tokens.spaceS),
                _StatChip(
                  label: l10n.statsLosses,
                  value: stats.losses,
                  color: colorScheme.error,
                  icon: Icons.sentiment_dissatisfied_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: M3Tokens.spaceS, horizontal: M3Tokens.spaceS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(M3Tokens.shapeS),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 设置卡片
// ---------------------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  final ThemeMode themeMode;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final ValueChanged<ThemeMode> onThemeChanged;

  const _SettingsCard({
    required this.themeMode,
    required this.colorScheme,
    required this.l10n,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(M3Tokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: M3Tokens.spaceS),
                Text(l10n.themeModeTitle,
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: M3Tokens.spaceM),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeSystem),
                    icon: const Icon(Icons.brightness_auto_rounded, size: 16)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeLight),
                    icon: const Icon(Icons.light_mode_rounded, size: 16)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeDark),
                    icon: const Icon(Icons.dark_mode_rounded, size: 16)),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) =>
                  onThemeChanged(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}
