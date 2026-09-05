/// 在线大厅：创建房间 / 加入房间 / 等待对手。
///
/// 页面完全由 [onlineControllerProvider] 的阶段驱动：
/// idle → (创建/加入) → connecting → waiting(显示房码) → 进对局页
/// 任何一步出错都落到 error 视图，给出重试出口。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/l10n/generated/app_localizations.dart';
import 'package:five/state/online_controller.dart';
import 'package:five/state/settings_provider.dart';
import 'package:five/ui/screens/game_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
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
    final online = ref.watch(onlineControllerProvider);

    ref.listen(onlineControllerProvider, (prev, next) {
      if (next.phase == OnlinePhase.inRoom &&
          prev?.phase != OnlinePhase.inRoom) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameScreen.online()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.onlineMode,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: switch (online.phase) {
              OnlinePhase.connecting => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在连接服务器…'),
                  ],
                ),
              OnlinePhase.waiting => _WaitingRoomView(state: online),
              _ => _LobbyForm(
                  roomCodeCtrl: _roomCodeCtrl,
                  serverCtrl: _serverCtrl,
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// 大厅表单：创建 / 加入 / 服务器地址。
class _LobbyForm extends ConsumerWidget {
  final TextEditingController roomCodeCtrl;
  final TextEditingController serverCtrl;

  const _LobbyForm({
    required this.roomCodeCtrl,
    required this.serverCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final online = ref.watch(onlineControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // —— 卡片 1：创建房间 ——
        Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
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
                          '生成专属 4 位房号，邀请好友对战',
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
                    onPressed: () =>
                        ref.read(onlineControllerProvider.notifier).createRoom(),
                    icon: const Icon(Icons.flash_on_rounded),
                    label: Text(l10n.createRoom),
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
          ),
        ),
        const SizedBox(height: 16),

        // —— 卡片 2：输入房号加入 ——
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 16),
                TextField(
                  controller: roomCodeCtrl,
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
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .25),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(onlineControllerProvider.notifier)
                        .joinRoom(roomCodeCtrl.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(l10n.joinRoom),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

        // 错误提示
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

        const SizedBox(height: 24),
        // —— 服务器配置折叠区 ——
        ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.dns_outlined, size: 20),
          title: Text(
            l10n.serverAddress,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: serverCtrl,
                decoration: InputDecoration(
                  hintText: 'ws://host:8080',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (value) =>
                    ref.read(serverUrlProvider.notifier).set(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 建房等待视图：大号房码 + 复制 + 取消。
class _WaitingRoomView extends ConsumerWidget {
  final OnlineState state;

  const _WaitingRoomView({required this.state});

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
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
