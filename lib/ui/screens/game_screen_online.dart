/// 在线对战的专用 UI 组件：回合 HUD、底部操作区、宽屏信息面板。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five_core/five_core.dart';
import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/online_controller.dart';
import 'package:five/state/settings_provider.dart';
import 'package:five/ui/screens/home_screen.dart';

/// 联机双方状态 HUD（你 VS 对手，带联机状态与行棋高亮）。
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
    final theme = Theme.of(context);
    final iAmBlack = online.myColor == SeatColor.black;
    final isPlaying = online.game.status == GameStatus.playing;
    final isMyTurn = isPlaying && online.isMyTurn;
    final isOpponentTurn = isPlaying && !online.isMyTurn;

    final myName = iAmBlack ? '你 (执黑)' : '你 (执白)';
    final opponentName = iAmBlack ? '对手 (执白)' : '对手 (执黑)';

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
          // 左侧：我的状态卡片
          Expanded(
            child: _OnlinePlayerBadge(
              name: myName,
              isBlack: iAmBlack,
              isActive: isMyTurn,
              subtext: isMyTurn ? '该你落子' : '等待对手',
            ),
          ),
          // 中间：房号与连接状态
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
                    '第 $moveCount 手',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online.opponentOnline ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      online.opponentOnline ? '在线' : '离线等待',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: online.opponentOnline
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右侧：对手状态卡片
          Expanded(
            child: _OnlinePlayerBadge(
              name: opponentName,
              isBlack: !iAmBlack,
              isActive: isOpponentTurn,
              subtext: !online.opponentOnline
                  ? '已断线'
                  : (isOpponentTurn ? '思考中…' : '等待落子'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePlayerBadge extends StatelessWidget {
  final String name;
  final bool isBlack;
  final bool isActive;
  final String subtext;

  const _OnlinePlayerBadge({
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
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameEnded && online.rematchOffered) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.opponentWantsRematch,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ),
          ] else if (gameEnded && online.rematchPending) ...[
            Text(
              l10n.waitingRematchReply,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await controller.leave();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.backToLobby),
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
                child: !gameEnded
                    ? FilledButton.tonalIcon(
                        onPressed: controller.resign,
                        icon: const Icon(Icons.flag_rounded),
                        label: Text(l10n.resign),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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
    final gameEnded = online.game.status != GameStatus.playing;
    final controller = ref.read(onlineControllerProvider.notifier);
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
              '在线对决',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            OnlineTurnBanner(online: online, moveCount: online.game.moves.length),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (!gameEnded)
              FilledButton.tonalIcon(
                onPressed: controller.resign,
                icon: const Icon(Icons.flag_rounded),
                label: Text(l10n.resign),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: online.rematchOffered
                    ? controller.acceptRematch
                    : (online.rematchPending ? null : controller.requestRematch),
                icon: const Icon(Icons.replay_rounded),
                label: Text(online.rematchOffered
                    ? l10n.opponentWantsRematch
                    : (online.rematchPending
                        ? l10n.waitingRematchReply
                        : l10n.rematch)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await controller.leave();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.backToLobby),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const Spacer(),
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
