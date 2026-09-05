/// 应用主界面：底部导航栏（对弈 / 联机 / 战绩 / 设置）与全平台自适应框架。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/engine/ai_service.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/online_controller.dart';
import 'package:five/state/settings_provider.dart';
import 'package:five/state/stats_provider.dart';
import 'package:five/state/theme_provider.dart';
import 'package:five/ui/screens/game_screen.dart';

/// 首页主框架：带有 Material 3 底部导航栏（宽屏自适应为侧边 NavigationRail）。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 联机对手就位时自动跳进在线对局
    ref.listen(onlineControllerProvider, (prev, next) {
      if (next.phase == OnlinePhase.inRoom &&
          prev?.phase != OnlinePhase.inRoom) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const GameScreen.online()),
        );
      }
    });

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.sports_esports_outlined),
        selectedIcon: const Icon(Icons.sports_esports_rounded),
        label: l10n.navPlay,
      ),
      NavigationDestination(
        icon: const Icon(Icons.wifi_tethering_outlined),
        selectedIcon: const Icon(Icons.wifi_tethering_rounded),
        label: l10n.navOnline,
      ),
      NavigationDestination(
        icon: const Icon(Icons.leaderboard_outlined),
        selectedIcon: const Icon(Icons.leaderboard_rounded),
        label: l10n.navStats,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: l10n.navSettings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        Widget currentTab = IndexedStack(
          index: _currentIndex,
          children: const [
            _PlayTab(),
            _OnlineTab(),
            _StatsTab(),
            _SettingsTab(),
          ],
        );

        if (isWide) {
          // 桌面 / 平板宽屏：左侧 NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.grid_4x4_rounded,
                          color: theme.colorScheme.primary),
                    ),
                  ),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon,
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: currentTab,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 手机竖屏：标准原生底部导航栏
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: currentTab,
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB 0: 对弈主界面 (PlayTab)
// =============================================================================
class _PlayTab extends ConsumerWidget {
  const _PlayTab();

  void _startVsAi(BuildContext context, WidgetRef ref, AiLevel level) {
    ref.read(gameControllerProvider.notifier).startNewGame(
          mode: GameMode.vsAi,
          aiLevel: level,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen.vsAi(level)),
    );
  }

  Future<void> _pickDifficultyAndStart(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final level = await showDialog<AiLevel>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.psychology_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(l10n.chooseDifficulty),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final level in AiLevel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: switch (level) {
                        AiLevel.easy => Colors.green.withValues(alpha: .15),
                        AiLevel.medium => Colors.orange.withValues(alpha: .15),
                        AiLevel.hard => Colors.red.withValues(alpha: .15),
                      },
                      child: Icon(
                        switch (level) {
                          AiLevel.easy => Icons.sentiment_satisfied_rounded,
                          AiLevel.medium => Icons.sentiment_neutral_rounded,
                          AiLevel.hard => Icons.local_fire_department_rounded,
                        },
                        color: switch (level) {
                          AiLevel.easy => Colors.green,
                          AiLevel.medium => Colors.orange,
                          AiLevel.hard => Colors.red,
                        },
                      ),
                    ),
                    title: Text(
                      switch (level) {
                        AiLevel.easy => l10n.aiEasy,
                        AiLevel.medium => l10n.aiMedium,
                        AiLevel.hard => l10n.aiHard,
                      },
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      switch (level) {
                        AiLevel.easy => '温和防守 · 适合初学者',
                        AiLevel.medium => '攻守兼备 · 敏锐察觉四连',
                        AiLevel.hard => '算无遗策 · 深度剪枝推演',
                      },
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => Navigator.pop(dialogContext, level),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (level == null || !context.mounted) return;
    _startVsAi(context, ref, level);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _HeroHeader(l10n: l10n),
        const SizedBox(height: 24),

        // 人机对弈
        _VsAiCard(
          onPick: () => _pickDifficultyAndStart(context, ref),
          onStartLevel: (lvl) => _startVsAi(context, ref, lvl),
        ),
        const SizedBox(height: 14),

        // 本地双人
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: InkWell(
            onTap: () {
              ref.read(gameControllerProvider.notifier).startNewGame(
                    mode: GameMode.localTwoPlayer,
                  );
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GameScreen()),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        color: Color(0xFFE65100), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.localTwoPlayer,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.localTwoPlayerDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 规则说明小卡片
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '无禁手五子棋规则',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '黑先白后，交替落子。在横向、纵向或对角线任意方向最先连成五颗及以上同色棋子者获胜。无禁手限制，轻松对弈。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 1: 联机大厅 (OnlineTab)
// =============================================================================
class _OnlineTab extends ConsumerStatefulWidget {
  const _OnlineTab();

  @override
  ConsumerState<_OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends ConsumerState<_OnlineTab> {
  final _roomCodeCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _serverCtrl.text = ref.read(serverUrlProvider);
    });
  }

  @override
  void dispose() {
    _roomCodeCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final online = ref.watch(onlineControllerProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Row(
          children: [
            Icon(Icons.wifi_tethering_rounded,
                color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              '在线联机对战',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '跨端实时对战 · 房号即进 · 自动判定',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        if (online.phase == OnlinePhase.waiting) ...[
          _WaitingRoomCard(state: online),
        ] else ...[
          // 创建房间
          Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: .3),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.createRoom,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '生成专属 4 位房号，随时等待好友加入',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: online.phase == OnlinePhase.connecting
                          ? null
                          : () => ref
                              .read(onlineControllerProvider.notifier)
                              .createRoom(),
                      icon: online.phase == OnlinePhase.connecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.flash_on_rounded),
                      label: Text(online.phase == OnlinePhase.connecting
                          ? '正在创建…'
                          : l10n.createRoom),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 加入房间
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.login_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.joinRoom,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '输入好友分享的 4 位房间码',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _roomCodeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.roomCodeLabel,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: .25),
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(onlineControllerProvider.notifier)
                          .joinRoom(_roomCodeCtrl.text),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.joinRoom),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (online.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      online.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _WaitingRoomCard extends ConsumerWidget {
  final OnlineState state;

  const _WaitingRoomCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card.outlined(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.roomCodeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 12),
            SelectableText(
              state.roomId ?? '----',
              style: theme.textTheme.displayMedium?.copyWith(
                letterSpacing: 14,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: state.roomId ?? ''));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.roomCodeCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.copyRoomCode),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.waitingOpponent,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () =>
                  ref.read(onlineControllerProvider.notifier).leave(),
              child: Text(l10n.backToLobby),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: 战绩看板 (StatsTab)
// =============================================================================
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);
    final total = stats.total;
    final winRate = total > 0 ? (stats.wins * 100 / total).round() : 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '战绩与成就',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '人机对战数据本地统计',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (total > 0)
              IconButton.outlined(
                tooltip: '重置战绩',
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('重置所有战绩？'),
                      content: const Text('所有本地保存的人机胜负平记录将被清空且不可恢复。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(statsProvider.notifier).reset();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 核心战绩卡
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: .3),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 胜率大圆盘
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: total > 0 ? (stats.wins / total) : 0,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$winRate%',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '人机胜率',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // 三项统计
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BigStatTile(
                      label: '胜局',
                      value: stats.wins,
                      color: Colors.green,
                      icon: Icons.emoji_events_rounded,
                    ),
                    _BigStatTile(
                      label: '负局',
                      value: stats.losses,
                      color: Colors.redAccent,
                      icon: Icons.close_rounded,
                    ),
                    _BigStatTile(
                      label: '和局',
                      value: stats.draws,
                      color: theme.colorScheme.onSurfaceVariant,
                      icon: Icons.handshake_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 战绩成就荣誉卡
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成就徽章',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: stats.wins >= 1
                        ? Colors.amber.withValues(alpha: .2)
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.star_rounded,
                        color: stats.wins >= 1 ? Colors.amber : Colors.grey),
                  ),
                  title: const Text('初露锋芒'),
                  subtitle: const Text('在人机对战中取得首场胜利'),
                  trailing: stats.wins >= 1
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : const Text('未达成', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: stats.wins >= 5
                        ? Colors.blue.withValues(alpha: .2)
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.shield_rounded,
                        color: stats.wins >= 5 ? Colors.blue : Colors.grey),
                  ),
                  title: const Text('棋道名手'),
                  subtitle: const Text('在人机对战中累计胜满 5 局'),
                  trailing: stats.wins >= 5
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : Text('${stats.wins}/5', style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BigStatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _BigStatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 3: 设置与个性化 (SettingsTab)
// =============================================================================
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final boardStyle = ref.watch(boardStyleProvider);
    final showNumbers = ref.watch(showMoveNumbersProvider);
    final serverUrl = ref.watch(serverUrlProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Text(
          l10n.settingsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '棋盘材质、视觉主题与对弈选项',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // 棋盘风格
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_4x4_rounded,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.boardStyleTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                BoardStyleSelector(activeStyle: boardStyle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 主题设置
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.themeModeTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text(l10n.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded, size: 18),
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .set(selection.first),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 对局辅助与联机设置
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(l10n.showMoveNumbers),
                subtitle: const Text('对局棋面上清晰标注落子先后手数'),
                value: showNumbers,
                onChanged: (val) =>
                    ref.read(showMoveNumbersProvider.notifier).set(val),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(l10n.serverAddress),
                subtitle: Text(serverUrl),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final ctrl = TextEditingController(text: serverUrl);
                  final newUrl = await showDialog<String>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text(l10n.serverAddress),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          hintText: 'ws://host:8080',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, ctrl.text),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  );
                  if (newUrl != null && newUrl.trim().isNotEmpty) {
                    ref.read(serverUrlProvider.notifier).set(newUrl.trim());
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 关于软件
        Center(
          child: Column(
            children: [
              Text(
                'Five · 五子棋 v1.1.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '全平台 Material 3 竞技五子棋 · 开源品质',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =============================================================================
// 辅助子组件
// =============================================================================

class _HeroHeader extends StatelessWidget {
  final AppLocalizations l10n;

  const _HeroHeader({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF2C2219), const Color(0xFF19120B)]
                  : [const Color(0xFFECD5B1), const Color(0xFFCBA16C)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .35 : .18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF4D3724) : const Color(0xFFB5874D),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(40, 40),
                painter: _EmblemGridPainter(
                  color: isDark ? const Color(0x66D5B08A) : const Color(0x7356330E),
                ),
              ),
              const PositiondStone(isBlack: true, offset: Offset(-8, -6)),
              const PositiondStone(isBlack: false, offset: Offset(8, 6)),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Five',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '五子棋',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '落子无悔 · 方寸智弈 · 竞技级五子棋',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PositiondStone extends StatelessWidget {
  final bool isBlack;
  final Offset offset;

  const PositiondStone({super.key, required this.isBlack, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.9,
            colors: isBlack
                ? const [Color(0xFF565B66), Color(0xFF15171A)]
                : const [Color(0xFFFFFFFF), Color(0xFFD4DCE4)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .4),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
          border: isBlack
              ? null
              : Border.all(color: const Color(0x40A0AAB5), width: 0.8),
        ),
      ),
    );
  }
}

class _EmblemGridPainter extends CustomPainter {
  final Color color;

  _EmblemGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VsAiCard extends StatelessWidget {
  final VoidCallback onPick;
  final ValueChanged<AiLevel> onStartLevel;

  const _VsAiCard({required this.onPick, required this.onStartLevel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: isDark ? .4 : .25),
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      theme.colorScheme.primaryContainer.withValues(alpha: .28),
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
                    ]
                  : [
                      theme.colorScheme.primaryContainer.withValues(alpha: .45),
                      theme.colorScheme.surface,
                    ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: .35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.vsAi,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AI 对弈',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Alpha-Beta 剪枝与深度推演引擎',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _DifficultyPill(
                    label: l10n.aiEasy,
                    color: Colors.green,
                    icon: Icons.sentiment_satisfied_rounded,
                    onTap: () => onStartLevel(AiLevel.easy),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyPill(
                    label: l10n.aiMedium,
                    color: Colors.orange,
                    icon: Icons.sentiment_neutral_rounded,
                    onTap: () => onStartLevel(AiLevel.medium),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyPill(
                    label: l10n.aiHard,
                    color: Colors.red,
                    icon: Icons.local_fire_department_rounded,
                    onTap: () => onStartLevel(AiLevel.hard),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _DifficultyPill({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: .3),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 棋盘风格选择器（带有材质色球预览）。
class BoardStyleSelector extends ConsumerWidget {
  final BoardStyle activeStyle;

  const BoardStyleSelector({super.key, required this.activeStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final items = [
      (BoardStyle.wood, l10n.boardStyleWood, const Color(0xFFE4BF83)),
      (BoardStyle.zen, l10n.boardStyleZen, const Color(0xFF343B42)),
      (BoardStyle.jade, l10n.boardStyleJade, const Color(0xFF00696E)),
    ];

    return Row(
      children: [
        for (final (style, label, color) in items) ...[
          Expanded(
            child: InkWell(
              onTap: () => ref.read(boardStyleProvider.notifier).set(style),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: activeStyle == style
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: activeStyle == style
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: activeStyle == style
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: activeStyle == style
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (style != BoardStyle.jade) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
