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
    // 首帧后同步服务器地址输入框（需要读 provider）。
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

    // 对手就位（进入房间且开局）→ 自动跳转对局页，只触发一次。
    ref.listen(onlineControllerProvider, (prev, next) {
      if (next.phase == OnlinePhase.inRoom &&
          prev?.phase != OnlinePhase.inRoom) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameScreen.online()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.onlineMode)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: switch (online.phase) {
              OnlinePhase.connecting =>
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('…'),
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
    final online = ref.watch(onlineControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => ref.read(onlineControllerProvider.notifier).createRoom(),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: Text(l10n.createRoom),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ref
              .read(onlineControllerProvider.notifier)
              .joinRoom(roomCodeCtrl.text),
          icon: const Icon(Icons.login_rounded),
          label: Text(l10n.joinRoom),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: roomCodeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.roomCodeLabel,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(letterSpacing: 12),
        ),

        // 错误提示（连接失败 / 房间不存在等）。
        if (online.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            online.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],

        const SizedBox(height: 32),
        // —— 高级设置：服务器地址 ——
        TextField(
          controller: serverCtrl,
          decoration: InputDecoration(
            labelText: l10n.serverAddress,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (value) =>
              ref.read(serverUrlProvider.notifier).set(value),
        ),
        const SizedBox(height: 6),
        Text(
          'ws://host:port',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.roomCodeLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        // 房号是这一屏的主角——超大展示，方便口头报给朋友。
        SelectableText(
          state.roomId ?? '----',
          style: theme.textTheme.displayLarge?.copyWith(
            letterSpacing: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
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
          icon: const Icon(Icons.copy_rounded),
          label: Text(l10n.copyRoomCode),
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(l10n.waitingOpponent,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            ref.read(onlineControllerProvider.notifier).leave();
            Navigator.of(context).pop(); // 回首页
          },
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
