/// 对局页：棋盘 + 回合状态 + 操作按钮 + 终局弹窗。
///
/// 【响应式布局】用 LayoutBuilder 按可用宽度切换两种骨架：
/// - 窄屏（手机竖屏）：状态条 → 棋盘 → 按钮，纵向排列；
/// - 宽屏（桌面/平板横屏）：左侧棋盘、右侧信息面板，横向并排。
/// 断点取 880 逻辑像素——足够区分「单手握持」与「桌面窗口」。
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/core/board.dart';
import 'package:five/core/sgf.dart';
import 'package:five/engine/ai_service.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_controller.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/settings_provider.dart';
import 'package:five/ui/board_view.dart';

/// 对局页。
///
/// 进入即按 [mode] / [aiLevel] 开新局——首页两个入口无需各自记得
/// 重置控制器，对局初始化内聚在本页的生命周期里。
class GameScreen extends ConsumerStatefulWidget {
  final GameMode mode;

  /// AI 难度；仅人机模式使用。
  final AiLevel? aiLevel;

  const GameScreen({super.key, this.mode = GameMode.localTwoPlayer})
      : aiLevel = null;

  /// 人机对战入口。
  const GameScreen.vsAi(this.aiLevel, {super.key}) : mode = GameMode.vsAi;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // 首帧渲染完成后再开新局：避免在构建期间修改 provider 状态，
    // 也保证「从进行中的棋局返回首页再进来」一定得到干净的新局。
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
    final game = ref.watch(gameControllerProvider);
    final showNumbers = ref.watch(showMoveNumbersProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    // 提示按钮可用性：人机模式、对局中、轮到人类、无后台任务。
    final canHint = game.mode == GameMode.vsAi &&
        game.status == GameStatus.playing &&
        !game.isAiTurn &&
        !game.aiThinking &&
        !game.hintLoading;

    // 监听终局：状态一变就弹出结算框。
    // ref.listen 写在 build 里，但回调在状态变化时才触发，
    // 且自动做了去重——不会因为界面重建而重复弹出。
    ref.listen(gameControllerProvider, (previous, next) {
      final justEnded = previous != null &&
          previous.status == GameStatus.playing &&
          next.status != GameStatus.playing;
      if (justEnded) _showResultDialog(context, ref, next, l10n);
    });

    // 桌面端键盘快捷键。Windows/Linux 用 Ctrl，macOS 自动匹配 Cmd——
    // 同一动作注册两种修饰键，各平台只会命中自己那组。
    // 移动端没有物理键盘，CallbackShortcuts 静默无副作用。
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            () => _restartWithConfirm(context, ref, game, l10n),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            () => _restartWithConfirm(context, ref, game, l10n),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true):
            controller.requestHint,
        const SingleActivator(LogicalKeyboardKey.keyH, meta: true):
            controller.requestHint,
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.hint,
            icon: game.hintLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline_rounded),
            onPressed: canHint ? controller.requestHint : null,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') _exportSgf(context, ref, game, l10n);
              if (value == 'numbers') {
                ref
                    .read(showMoveNumbersProvider.notifier)
                    .set(!showNumbers);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'export', child: Text(l10n.exportSgf)),
              CheckedPopupMenuItem(
                value: 'numbers',
                checked: showNumbers,
                child: Text(l10n.showMoveNumbers),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        // 回放中显示历史盘面；胜利线只在与最终局面一致时绘制。
        final showingFinalBoard =
            game.replayIndex == null || game.replayIndex == game.moves.length;
        final boardArea = Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              // 桌面上棋盘也不宜无限放大：上限 640px 保持观感。
              constraints: const BoxConstraints(maxWidth: 640),
              child: BoardView(
                board: game.displayBoard,
                lastMove: game.displayLastMove,
                winLine: showingFinalBoard ? game.winInfo?.line : null,
                moves: game.moves,
                showMoveNumbers: showNumbers,
                hint: showingFinalBoard ? game.hint : null,
                onCellTap: game.status == GameStatus.playing &&
                        !game.aiThinking &&
                        !game.hintLoading &&
                        game.replayIndex == null
                    ? (cell) => controller.placeAt(cell.x, cell.y)
                    : null, // 终局/思考中/回放中：棋盘只读
              ),
            ),
          ),
        );

        if (constraints.maxWidth >= 880) {
          // —— 宽屏：左棋盘(+回放条) + 右面板 ——
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: boardArea),
                    if (game.status != GameStatus.playing)
                      _ReplayBar(game: game),
                  ],
                ),
              ),
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
            if (game.status != GameStatus.playing) _ReplayBar(game: game),
            _BottomActions(game: game),
          ],
        );
      }),
      ),
    );
  }

  /// 终局结算弹窗：展示胜负 + 「再来一局」或返回主页。
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

/// 导出当前对局为 SGF 棋谱文件。
///
/// file_selector 弹出系统「另存为」对话框（Windows/macOS/桌面端原生体验，
/// Android 走 SAF）。用户取消则静默返回。
Future<void> _exportSgf(
  BuildContext context,
  WidgetRef ref,
  GameState game,
  AppLocalizations l10n,
) async {
  if (game.moves.isEmpty) return; // 空局没有可导出的内容。

  final location = await getSaveLocation(
    suggestedName:
        'five_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.sgf',
  );
  if (location == null || !context.mounted) return; // 用户取消

  final result = switch (game.status) {
    GameStatus.won =>
      game.winInfo!.winner == Cell.black ? 'B+' : 'W+',
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
    // 写盘失败（权限/磁盘）：不打断对局，仅提示。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed)),
      );
    }
  }
}

/// 终局后的复盘回放控制条：⏮ ◀ 位置 ▶ ⏭。
class _ReplayBar extends ConsumerWidget {
  final GameState game;

  const _ReplayBar({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 当前查看位置：null 表示正显示最终盘面，等价于第 n 手。
    final total = game.moves.length;
    final index = game.replayIndex ?? total;

    void moveTo(int i) =>
        ref.read(gameControllerProvider.notifier).replayTo(i.clamp(0, total));

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '⏮',
            onPressed: index > 0 ? () => moveTo(0) : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            tooltip: '◀',
            onPressed: index > 0 ? () => moveTo(index - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              l10n.replayPosition(index, total),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: '▶',
            onPressed: index < total ? () => moveTo(index + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: '⏭',
            onPressed: index < total ? () => moveTo(total) : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}

/// 回合指示条（窄屏顶部）：当前行棋方 + 手数 + AI 思考指示。
class _TurnBanner extends StatelessWidget {
  final GameState game;

  const _TurnBanner({required this.game});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBlack = game.currentStone == Cell.black;
    // AI 思考中优先展示思考文案；终局后横幅改为展示结果文案。
    final text = game.aiThinking
        ? l10n.aiThinking
        : switch (game.status) {
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
              border:
                  Border.all(color: theme.colorScheme.outline, width: 1.2),
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
          if (game.aiThinking) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
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
    // AI 思考中禁用悔棋（此时局面正在等待 AI 结果）。
    final canUndo = game.moves.isNotEmpty && !game.aiThinking;

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canUndo
                  ? () => ref.read(gameControllerProvider.notifier).undo()
                  : null,
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
    final canUndo = game.moves.isNotEmpty && !game.aiThinking;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              game.aiThinking
                  ? l10n.aiThinking
                  : switch (game.status) {
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
              onPressed: canUndo
                  ? () => ref.read(gameControllerProvider.notifier).undo()
                  : null,
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
