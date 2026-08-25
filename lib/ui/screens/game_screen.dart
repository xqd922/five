/// 对局页：棋盘 + 回合状态 + 操作按钮 + 终局弹窗。
///
/// 【响应式布局】用 LayoutBuilder 按可用宽度切换两种骨架：
/// - 窄屏（手机竖屏）：状态条 → 棋盘 → 按钮，纵向排列；
/// - 宽屏（桌面/平板横屏）：左侧棋盘、右侧信息面板，横向并排。
/// 断点取 880 逻辑像素——足够区分「单手握持」与「桌面窗口」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/core/board.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/ui/board_view.dart';

/// 清盘开新局；若当前对局已有进展，先弹窗确认防止误触。
///
/// 窄屏与宽屏面板共用这一份逻辑，保证行为一致。
Future<void> _restartWithConfirm(
  BuildContext context,
  WidgetRef ref,
  GameState game,
  AppLocalizations l10n,
) async {
  final needsConfirm =
      game.status == GameStatus.playing && game.moves.isNotEmpty;
  // 注意括号：Dart 中 || 的优先级高于 ??，
  // 不加括号会被解析成 (!needsConfirm || dialog) ?? false 而报错。
  final confirmed =
      !needsConfirm || (await showDialog<bool>(
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

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final game = ref.watch(gameControllerProvider);
    final controller =
        ref.read(gameControllerProvider.notifier);

    // 监听终局：状态一变就弹出结算框。
    // ref.listen 写在 build 里，但回调在状态变化时才触发，
    // 且自动做了去重——不会因为界面重建而重复弹出。
    ref.listen(gameControllerProvider, (previous, next) {
      final justEnded = previous != null &&
          previous.status == GameStatus.playing &&
          next.status != GameStatus.playing;
      if (justEnded) _showResultDialog(context, ref, next, l10n);
    });

    // 宽度断点决定布局骨架。
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: LayoutBuilder(builder: (context, constraints) {
        final boardArea = Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              // 桌面上棋盘也不宜无限放大：上限 640px 保持观感。
              constraints: const BoxConstraints(maxWidth: 640),
              child: BoardView(
                board: game.board,
                lastMove: game.lastMove,
                winLine: game.winInfo?.line,
                onCellTap: game.status == GameStatus.playing
                    ? (cell) => controller.placeAt(cell.x, cell.y)
                    : null, // 终局后棋盘进入只读
              ),
            ),
          ),
        );

        if (constraints.maxWidth >= 880) {
          // —— 宽屏：左棋盘 + 右面板 ——
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: boardArea),
              SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _SidePanel(game: game),
                ),
              ),
            ],
          );
        }

        // —— 窄屏：纵向排列 ——
        return Column(
          children: [
            _TurnBanner(game: game),
            Expanded(child: boardArea),
            _BottomActions(game: game),
          ],
        );
      }),
    );
  }

  void _showResultDialog(
    BuildContext context,
    WidgetRef ref,
    GameState game,
    AppLocalizations l10n,
  ) {
    final message = switch (game.status) {
      GameStatus.won => game.winInfo!.winner == Cell.black
          ? l10n.blackWins
          : l10n.whiteWins,
      _ => l10n.drawGame,
    };

    showDialog<void>(
      context: context,
      barrierDismissible: false, // 必须明确选择去向
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          game.status == GameStatus.won
              ? Icons.emoji_events_rounded
              : Icons.handshake_rounded,
          size: 40,
        ),
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // 返回首页
            },
            child: Text(l10n.backHome),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(gameControllerProvider.notifier).restart();
            },
            child: Text(l10n.restart),
          ),
        ],
      ),
    );
  }
}

/// 回合指示条（窄屏顶部）：当前行棋方 + 手数。
class _TurnBanner extends StatelessWidget {
  final GameState game;

  const _TurnBanner({required this.game});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBlack = game.currentStone == Cell.black;
    // 终局后横幅改为展示结果文案。
    final text = switch (game.status) {
      GameStatus.playing =>
        isBlack ? l10n.blackToMove : l10n.whiteToMove,
      GameStatus.won => game.winInfo!.winner == Cell.black
          ? l10n.blackWins
          : l10n.whiteWins,
      GameStatus.draw => l10n.drawGame,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 行棋方棋子示意圆点。
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBlack ? Colors.black : Colors.white,
              border: Border.all(color: theme.colorScheme.outline, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(text, style: theme.textTheme.titleMedium),
          const SizedBox(width: 10),
          Text(
            l10n.moveCount(game.moves.length),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 底部操作区（窄屏）：悔棋 + 重开。
class _BottomActions extends ConsumerWidget {
  final GameState game;

  const _BottomActions({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              // 没有任何手数时无从悔起。
              onPressed:
                  game.moves.isEmpty ? null : () => ref.read(gameControllerProvider.notifier).undo(),
              icon: const Icon(Icons.undo_rounded),
              label: Text(l10n.undo),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _restartWithConfirm(context, ref, game, l10n),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restart),
            ),
          ),
        ],
      ),
    );
  }
}

/// 宽屏右侧信息面板：回合状态与操作按钮的纵排版本。
class _SidePanel extends ConsumerWidget {
  final GameState game;

  const _SidePanel({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch (game.status) {
                GameStatus.playing => game.currentStone == Cell.black
                    ? l10n.blackToMove
                    : l10n.whiteToMove,
                GameStatus.won => game.winInfo!.winner == Cell.black
                    ? l10n.blackWins
                    : l10n.whiteWins,
                GameStatus.draw => l10n.drawGame,
              },
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.moveCount(game.moves.length),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: game.moves.isEmpty
                  ? null
                  : () => ref.read(gameControllerProvider.notifier).undo(),
              icon: const Icon(Icons.undo_rounded),
              label: Text(l10n.undo),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _restartWithConfirm(context, ref, game, l10n),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restart),
            ),
          ],
        ),
      ),
    );
  }
}
