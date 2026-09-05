/// 对局页：棋盘 + 双人状态 HUD + 操作按钮 + 终局弹窗。
///
/// 【响应式布局】用 LayoutBuilder 按可用宽度切换两种骨架：
/// - 窄屏（手机竖屏）：双方对弈 HUD → 棋盘 → 底部操作控制坞；
/// - 宽屏（桌面/平板横屏）：左侧棋盘、右侧信息控制面板，横向并排。
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five_core/five_core.dart';
import 'package:five/engine/ai_service.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/online_controller.dart';
import 'package:five/state/settings_provider.dart';
import 'package:five/ui/board_view.dart';
import 'package:five/ui/screens/game_screen_online.dart';
import 'package:five/ui/screens/home_screen.dart';

/// 对局页。
class GameScreen extends ConsumerStatefulWidget {
  final GameMode mode;

  /// AI 难度；仅人机模式使用。
  final AiLevel? aiLevel;

  const GameScreen({super.key, this.mode = GameMode.localTwoPlayer})
      : aiLevel = null;

  /// 人机对战入口。
  const GameScreen.vsAi(this.aiLevel, {super.key}) : mode = GameMode.vsAi;

  /// 在线对战入口（对局状态由 OnlineController 提供）。
  const GameScreen.online({super.key})
      : mode = GameMode.online,
        aiLevel = null;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameControllerProvider.notifier).startNewGame(
            mode: widget.mode,
            aiLevel: widget.aiLevel,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOnline = widget.mode == GameMode.online;

    final GameState game;
    final OnlineState? online;
    if (isOnline) {
      final state = ref.watch(onlineControllerProvider);
      online = state;
      game = state.game;
    } else {
      online = null;
      game = ref.watch(gameControllerProvider);
    }
    final showNumbers = ref.watch(showMoveNumbersProvider);
    final boardStyle = ref.watch(boardStyleProvider);
    final localController = ref.read(gameControllerProvider.notifier);

    // 提示按钮可用性：仅人机模式（联机用 AI 提示属于作弊）、对局中。
    final canHint = !isOnline &&
        game.mode == GameMode.vsAi &&
        game.status == GameStatus.playing &&
        !game.isAiTurn &&
        !game.aiThinking &&
        !game.hintLoading;

    // 终局弹窗
    if (!isOnline) {
      ref.listen(gameControllerProvider, (previous, next) {
        final justEnded = previous != null &&
            previous.status == GameStatus.playing &&
            next.status != GameStatus.playing;
        if (justEnded) _showResultDialog(context, ref, next, l10n);
      });
    }

    return CallbackShortcuts(
      bindings: {
        if (!isOnline)
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              localController.undo,
        if (!isOnline)
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              localController.undo,
        if (!isOnline)
          const SingleActivator(LogicalKeyboardKey.keyH, control: true):
              localController.requestHint,
        if (!isOnline)
          const SingleActivator(LogicalKeyboardKey.keyH, meta: true):
              localController.requestHint,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            () => _restartWithConfirm(context, ref, game, l10n),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            () => _restartWithConfirm(context, ref, game, l10n),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            switch (game.mode) {
              GameMode.vsAi => switch (game.aiLevel) {
                  AiLevel.easy => '人机对战 · 入门',
                  AiLevel.medium => '人机对战 · 进阶',
                  AiLevel.hard => '人机对战 · 大师',
                  null => l10n.vsAi,
                },
              GameMode.online => l10n.onlineMode,
              GameMode.localTwoPlayer => l10n.localTwoPlayer,
            },
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!isOnline && game.mode == GameMode.vsAi)
              IconButton(
                tooltip: l10n.hint,
                icon: game.hintLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lightbulb_outline_rounded,
                        color: Color(0xFFFFB300)),
                onPressed: canHint ? localController.requestHint : null,
              ),
            // 切换手数快捷按钮
            IconButton(
              tooltip: l10n.showMoveNumbers,
              icon: Icon(
                showNumbers ? Icons.pin_rounded : Icons.pin_outlined,
                color: showNumbers ? theme.colorScheme.primary : null,
              ),
              onPressed: () => ref
                  .read(showMoveNumbersProvider.notifier)
                  .set(!showNumbers),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export') _exportSgf(context, ref, game, l10n);
                if (value == 'wood') ref.read(boardStyleProvider.notifier).set(BoardStyle.wood);
                if (value == 'zen') ref.read(boardStyleProvider.notifier).set(BoardStyle.zen);
                if (value == 'jade') ref.read(boardStyleProvider.notifier).set(BoardStyle.jade);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'export', child: Row(
                  children: [
                    const Icon(Icons.save_alt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.exportSgf),
                  ],
                )),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'wood',
                  checked: boardStyle == BoardStyle.wood,
                  child: Text(l10n.boardStyleWood),
                ),
                CheckedPopupMenuItem(
                  value: 'zen',
                  checked: boardStyle == BoardStyle.zen,
                  child: Text(l10n.boardStyleZen),
                ),
                CheckedPopupMenuItem(
                  value: 'jade',
                  checked: boardStyle == BoardStyle.jade,
                  child: Text(l10n.boardStyleJade),
                ),
              ],
            ),
          ],
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final showingFinalBoard =
              game.replayIndex == null || game.replayIndex == game.moves.length;
          final boardArea = Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: BoardView(
                  board: game.displayBoard,
                  lastMove: game.displayLastMove,
                  winLine: showingFinalBoard ? game.winInfo?.line : null,
                  moves: game.moves,
                  showMoveNumbers: showNumbers,
                  hint: showingFinalBoard ? game.hint : null,
                  onCellTap: _canPlace(game, online)
                      ? (cell) => isOnline
                          ? ref
                              .read(onlineControllerProvider.notifier)
                              .placeAt(cell.x, cell.y)
                          : localController.placeAt(cell.x, cell.y)
                      : null,
                ),
              ),
            ),
          );

          if (constraints.maxWidth >= 880) {
            // —— 宽屏布局：左棋盘 + 右侧精美控制面板 ——
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: boardArea),
                      if (!isOnline && game.status != GameStatus.playing)
                        _ReplayBar(game: game),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: isOnline
                        ? OnlineSidePanel(online: online!)
                        : _SidePanel(game: game),
                  ),
                ),
              ],
            );
          }

          // —— 窄屏布局：对弈双方 HUD → 棋盘 → 底部操作控制坞 ——
          return Column(
            children: [
              isOnline
                  ? OnlineTurnBanner(online: online!, moveCount: game.moves.length)
                  : _PlayerStatusHUD(game: game),
              Expanded(child: boardArea),
              if (!isOnline && game.status != GameStatus.playing)
                _ReplayBar(game: game),
              isOnline
                  ? OnlineBottomActions(online: online!)
                  : _BottomActions(game: game),
            ],
          );
        }),
      ),
    );
  }

  bool _canPlace(GameState game, OnlineState? online) {
    if (game.status != GameStatus.playing) return false;
    if (game.replayIndex != null) return false;
    if (online != null) return online.isMyTurn;
    return !game.aiThinking && !game.hintLoading && !game.isAiTurn;
  }

  /// 终局华丽结果弹窗。
  void _showResultDialog(
    BuildContext context,
    WidgetRef ref,
    GameState game,
    AppLocalizations l10n,
  ) {
    final isWon = game.status == GameStatus.won;
    final winner = game.winInfo?.winner;
    final isBlackWin = winner == Cell.black;
    final isHumanWin = game.mode == GameMode.vsAi ? isBlackWin : null;

    final String titleText;
    final String subtitleText;
    final IconData iconData;
    final Color accentColor;

    if (isWon) {
      if (game.mode == GameMode.vsAi) {
        if (isHumanWin == true) {
          titleText = '🏆 棋高一着 · 恭喜获胜！';
          subtitleText = '你成功战胜了 AI 对手，落子沉着，进退有据！';
          iconData = Icons.emoji_events_rounded;
          accentColor = Colors.amber;
        } else {
          titleText = '⚔️ 棋差一着 · AI 获胜';
          subtitleText = 'AI 抓住了关键落子点成五，胜败乃兵家常事，再接再厉！';
          iconData = Icons.psychology_rounded;
          accentColor = Colors.blueGrey;
        }
      } else {
        titleText = isBlackWin ? '🏆 黑方拔得头筹！' : '🏆 白方技高一筹！';
        subtitleText = isBlackWin ? '黑方先发制人，五子连珠！' : '白方后发制人，逆转决胜！';
        iconData = Icons.emoji_events_rounded;
        accentColor = Colors.amber;
      }
    } else {
      titleText = '🤝 势均力敌 · 棋盘已满';
      subtitleText = '双方防守滴水不漏，以平局收尾！';
      iconData = Icons.handshake_rounded;
      accentColor = Colors.teal;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 36, color: accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                titleText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitleText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('总手数：', style: theme.textTheme.bodyMedium),
                    Text(
                      '${game.moves.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: Text(l10n.backHome),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('复盘'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    ref.read(gameControllerProvider.notifier).restart();
                  },
                  child: Text(l10n.restart),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 窄屏对弈双方状态 HUD（黑方 VS 白方 卡片，当前回合高亮呼吸指示）。
class _PlayerStatusHUD extends StatelessWidget {
  final GameState game;

  const _PlayerStatusHUD({required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaying = game.status == GameStatus.playing;
    final isBlackTurn = isPlaying && game.currentStone == Cell.black;
    final isWhiteTurn = isPlaying && game.currentStone == Cell.white;

    final String blackName = game.mode == GameMode.vsAi ? '玩家 (黑)' : '黑方';
    final String whiteName = game.mode == GameMode.vsAi
        ? switch (game.aiLevel) {
            AiLevel.easy => 'AI · 入门',
            AiLevel.medium => 'AI · 进阶',
            AiLevel.hard => 'AI · 大师',
            null => 'AI',
          }
        : '白方';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
        ),
      ),
      child: Row(
        children: [
          // 黑方卡片
          Expanded(
            child: _PlayerBadge(
              name: blackName,
              isBlack: true,
              isActive: isBlackTurn,
              subtext: isBlackTurn ? '行棋中' : (isPlaying ? '等待中' : ''),
            ),
          ),
          // 中间 VS 与状态胶囊
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '第 ${game.moves.length} 手',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (game.aiThinking) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '推演中',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 白方卡片
          Expanded(
            child: _PlayerBadge(
              name: whiteName,
              isBlack: false,
              isActive: isWhiteTurn,
              subtext: isWhiteTurn
                  ? (game.aiThinking ? '深度算力…' : '行棋中')
                  : (isPlaying ? '等待中' : ''),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String name;
  final bool isBlack;
  final bool isActive;
  final String subtext;

  const _PlayerBadge({
    required this.name,
    required this.isBlack,
    required this.isActive,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: .6)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // 拟真 3D 棋子头像
          Container(
            width: 24,
            height: 24,
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
                  color: Colors.black.withValues(alpha: .35),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
              border: isBlack
                  ? null
                  : Border.all(color: const Color(0x55A0AAB5), width: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtext.isNotEmpty)
                  Text(
                    subtext,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作区（窄屏）：优雅浮动控制坞。
class _BottomActions extends ConsumerWidget {
  final GameState game;

  const _BottomActions({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canUndo = game.moves.isNotEmpty && !game.aiThinking;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canUndo
                  ? () => ref.read(gameControllerProvider.notifier).undo()
                  : null,
              icon: const Icon(Icons.undo_rounded),
              label: Text(l10n.undo),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _restartWithConfirm(context, ref, game, l10n),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restart),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 宽屏右侧信息面板。
class _SidePanel extends ConsumerWidget {
  final GameState game;

  const _SidePanel({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canUndo = game.moves.isNotEmpty && !game.aiThinking;
    final showNumbers = ref.watch(showMoveNumbersProvider);
    final boardStyle = ref.watch(boardStyleProvider);

    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '对弈状态',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _PlayerStatusHUD(game: game),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 操作按钮
            OutlinedButton.icon(
              onPressed: canUndo
                  ? () => ref.read(gameControllerProvider.notifier).undo()
                  : null,
              icon: const Icon(Icons.undo_rounded),
              label: Text(l10n.undo),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => _restartWithConfirm(context, ref, game, l10n),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restart),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(showMoveNumbersProvider.notifier)
                  .set(!showNumbers),
              icon: Icon(showNumbers ? Icons.pin_rounded : Icons.pin_outlined),
              label: Text(l10n.showMoveNumbers),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const Spacer(),

            // 棋盘风格快选
            Text(
              l10n.boardStyleTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            BoardStyleSelector(activeStyle: boardStyle),
          ],
        ),
      ),
    );
  }
}

/// 终局后的复盘回放控制条。
class _ReplayBar extends ConsumerWidget {
  final GameState game;

  const _ReplayBar({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = game.moves.length;
    final index = game.replayIndex ?? total;

    void moveTo(int i) =>
        ref.read(gameControllerProvider.notifier).replayTo(i.clamp(0, total));

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '开局',
              onPressed: index > 0 ? () => moveTo(0) : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              tooltip: '上一手',
              onPressed: index > 0 ? () => moveTo(index - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '复盘：${l10n.replayPosition(index, total)} 手',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: '下一手',
              onPressed: index < total ? () => moveTo(index + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: '终局',
              onPressed: index < total ? () => moveTo(total) : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _restartWithConfirm(
  BuildContext context,
  WidgetRef ref,
  GameState game,
  AppLocalizations l10n,
) async {
  final needsConfirm =
      game.status == GameStatus.playing && game.moves.isNotEmpty;
  final confirmed = !needsConfirm ||
      (await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.restartConfirmTitle),
              content: Text(l10n.restartConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.confirm),
                ),
              ],
            ),
          ) ??
          false);

  if (confirmed && context.mounted) {
    ref.read(gameControllerProvider.notifier).restart();
  }
}

Future<void> _exportSgf(
  BuildContext context,
  WidgetRef ref,
  GameState game,
  AppLocalizations l10n,
) async {
  if (game.moves.isEmpty) return;

  final location = await getSaveLocation(
    suggestedName:
        'five_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.sgf',
  );
  if (location == null || !context.mounted) return;

  final result = switch (game.status) {
    GameStatus.won => game.winInfo!.winner == Cell.black ? 'B+' : 'W+',
    GameStatus.draw => '0',
    GameStatus.playing => null,
  };
  final sgf = SgfExporter.export(moves: game.moves, result: result);

  try {
    await File(location.path).writeAsString(sgf);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sgfSaved)),
      );
    }
  } on FileSystemException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed)),
      );
    }
  }
}
