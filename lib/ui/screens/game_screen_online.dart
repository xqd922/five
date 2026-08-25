/// 在线对战的专用 UI 组件：回合横幅、底部操作区、宽屏信息面板。
///
/// 与本地组件分离的原因：联机的状态源是 [OnlineState]，
/// 操作语义也不同（认输/再战/返回大厅 vs 悔棋/重开）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five_core/five_core.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/online_controller.dart';

/// 联机回合横幅：你的颜色 + 对手状态 + 手数。
class OnlineTurnBanner extends StatelessWidget {
  final OnlineState online;
  final int moveCount;

  const OnlineTurnBanner({
    super.key,
    required this.online,
    required this.moveCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final iAmBlack = online.myColor == SeatColor.black;

    // 文案优先级：终局 > 对手掉线 > 行棋提示。
    final String text;
    if (online.game.status == GameStatus.won) {
      text = online.game.winInfo!.winner == Cell.black
          ? l10n.blackWins
          : l10n.whiteWins;
    } else if (online.game.status == GameStatus.draw) {
      text = l10n.drawGame;
    } else if (!online.opponentOnline) {
      text = l10n.opponentLeft;
    } else {
      text = online.isMyTurn
          ? (iAmBlack ? l10n.youPlayBlack : l10n.youPlayWhite)
          : l10n.aiThinking; // 复用「思考中」语义：等对手走棋
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iAmBlack ? Colors.black : Colors.white,
              border:
                  Border.all(color: theme.colorScheme.outline, width: 1.2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: theme.textTheme.titleMedium)),
          if (!online.opponentOnline &&
              online.game.status == GameStatus.playing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            l10n.moveCount(moveCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 联机底部操作区：对局中=认输；终局后=再战流程。
class OnlineBottomActions extends ConsumerWidget {
  final OnlineState online;

  const OnlineBottomActions({super.key, required this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(onlineControllerProvider.notifier);
    final gameEnded = online.game.status != GameStatus.playing;

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameEnded && online.rematchOffered) ...[
            Text(l10n.opponentWantsRematch,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
          ] else if (gameEnded && online.rematchPending) ...[
            Text(l10n.waitingRematchReply,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await controller.leave();
                    if (context.mounted) {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst); // 回首页
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.backToLobby),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: !gameEnded
                    ? FilledButton.tonalIcon(
                        onPressed: controller.resign,
                        icon: const Icon(Icons.flag_rounded),
                        label: Text(l10n.resign),
                      )
                    : FilledButton.icon(
                        onPressed: online.rematchOffered
                            ? controller.acceptRematch
                            : (online.rematchPending
                                ? null
                                : controller.requestRematch),
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(online.rematchOffered
                            ? l10n.rematch
                            : online.rematchPending
                                ? l10n.waitingRematchReply
                                : l10n.rematch),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 宽屏联机信息面板。
class OnlineSidePanel extends ConsumerWidget {
  final OnlineState online;

  const OnlineSidePanel({super.key, required this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final iAmBlack = online.myColor == SeatColor.black;
    final gameEnded = online.game.status != GameStatus.playing;
    final controller = ref.read(onlineControllerProvider.notifier);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iAmBlack ? Colors.black : Colors.white,
                    border: Border.all(
                        color: theme.colorScheme.outline, width: 1.2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(iAmBlack ? l10n.youPlayBlack : l10n.youPlayWhite,
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              !online.opponentOnline && !gameEnded
                  ? l10n.opponentLeft
                  : l10n.moveCount(online.game.moves.length),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!gameEnded)
              FilledButton.tonalIcon(
                onPressed: controller.resign,
                icon: const Icon(Icons.flag_rounded),
                label: Text(l10n.resign),
              )
            else ...[
              FilledButton.icon(
                onPressed: online.rematchOffered ? controller.acceptRematch : null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(online.rematchOffered
                    ? l10n.opponentWantsRematch
                    : l10n.rematch),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: (online.rematchOffered || online.rematchPending)
                    ? null
                    : controller.requestRematch,
                child: Text(online.rematchPending
                    ? l10n.waitingRematchReply
                    : l10n.rematch),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
