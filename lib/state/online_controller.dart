/// 在线对战控制器：把 WebSocket 消息流翻译成 [GameState]。
///
/// 【核心设计】内部持有的 game 字段与本地对局是**同一个模型**——
/// GameScreen 的渲染代码完全复用，联机只是换了一种「落子来源」。
/// 这正是 M1 时坚持「状态机与控制来源分离」的回报。
///
/// 【服务端权威】本控制器从不自行判定胜负、不自行落子；
/// 一切以服务端回执为准（moveApplied / gameOver），
/// 从根上杜绝两端状态分叉。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five_core/five_core.dart';

import 'package:five/network/ws_client.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/settings_provider.dart';

/// 在线流程阶段。
enum OnlinePhase {
  /// 未参与任何房间。
  idle,

  /// 正在与服务器握手。
  connecting,

  /// 房间已建，等待对手加入。
  waiting,

  /// 房间内（对局中或终局展示）。
  inRoom,

  /// 发生错误，需用户重试或返回大厅。
  error,
}

class OnlineState {
  final OnlinePhase phase;

  /// 当前对局（复用本地渲染模型）。
  final GameState game;

  /// 我执的颜色；未入座为 null。
  final String? myColor;

  final String? roomId;
  final String? token;

  /// 对手是否在线。
  final bool opponentOnline;

  final String? errorMessage;

  /// 我已发出再战邀请，等待对方同意。
  final bool rematchPending;

  /// 对方邀请再战，等待我决定。
  final bool rematchOffered;

  const OnlineState({
    required this.game,
    this.phase = OnlinePhase.idle,
    this.myColor,
    this.roomId,
    this.token,
    this.opponentOnline = false,
    this.errorMessage,
    this.rematchPending = false,
    this.rematchOffered = false,
  });

  /// 是否轮到我落子。
  bool get isMyTurn =>
      phase == OnlinePhase.inRoom &&
      myColor != null &&
      game.status == GameStatus.playing &&
      SeatColor.toStone(myColor!) == game.currentStone;

  OnlineState copyWith({
    OnlinePhase? phase,
    GameState? game,
    String? myColor,
    String? roomId,
    String? token,
    bool? opponentOnline,
    String? errorMessage,
    bool clearError = false,
    bool? rematchPending,
    bool? rematchOffered,
  }) {
    return OnlineState(
      phase: phase ?? this.phase,
      game: game ?? this.game,
      myColor: myColor ?? this.myColor,
      roomId: roomId ?? this.roomId,
      token: token ?? this.token,
      opponentOnline: opponentOnline ?? this.opponentOnline,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rematchPending: rematchPending ?? this.rematchPending,
      rematchOffered: rematchOffered ?? this.rematchOffered,
    );
  }
}

final onlineControllerProvider =
    NotifierProvider<OnlineController, OnlineState>(OnlineController.new);

class OnlineController extends Notifier<OnlineState> {
  final WsClient _ws = WsClient();
  StreamSubscription<WsState>? _stateSub;
  StreamSubscription<Map<String, Object?>>? _msgSub;

  @override
  OnlineState build() {
    ref.onDispose(() async {
      await _stateSub?.cancel();
      await _msgSub?.cancel();
      await _ws.close();
    });
    return OnlineState(game: GameState.initial());
  }

  // ------------------------------------------------------------------
  // 大厅动作
  // ------------------------------------------------------------------

  /// 创建房间。
  Future<void> createRoom() => _enter(
      afterConnect: () => _ws.send({Msg.type: Msg.create}));

  /// 加入指定房号。
  Future<void> joinRoom(String roomId) => _enter(afterConnect: () =>
      _ws.send({Msg.type: Msg.join, Msg.roomId: roomId.trim()}));

  /// 断线后凭令牌重连。
  Future<void> reconnect() async {
    final roomId = state.roomId;
    final token = state.token;
    if (roomId == null || token == null) return;
    await _enter(afterConnect: () =>
        _ws.send({Msg.type: Msg.rejoin, Msg.roomId: roomId, Msg.token: token}));
  }

  /// 离开房间并断开连接，回到大厅空闲态。
  Future<void> leave() async {
    _ws.send({Msg.type: Msg.leave});
    await _detachListeners();
    await _ws.close();
    state = OnlineState(game: GameState.initial());
  }

  // ------------------------------------------------------------------
  // 对局动作（全部只是「提议」，等服务器回执）
  // ------------------------------------------------------------------

  void placeAt(int x, int y) {
    if (!state.isMyTurn) return;
    if (!Rules.isLegalMove(state.game.board, x, y)) return;
    _ws.send({Msg.type: Msg.move, Msg.x: x, Msg.y: y});
  }

  void resign() {
    if (state.phase != OnlinePhase.inRoom) return;
    _ws.send({Msg.type: Msg.resign});
  }

  void requestRematch() {
    if (state.phase != OnlinePhase.inRoom) return;
    if (state.game.status == GameStatus.playing) return; // 未终局不能再战
    state = state.copyWith(rematchPending: true);
    _ws.send({Msg.type: Msg.rematch});
  }

  void acceptRematch() {
    if (!state.rematchOffered) return;
    state = state.copyWith(rematchOffered: false, rematchPending: true);
    _ws.send({Msg.type: Msg.rematchAccept});
  }

  // ------------------------------------------------------------------
  // 连接建立与消息路由
  // ------------------------------------------------------------------

  Future<void> _enter({required void Function() afterConnect}) async {
    state = state.copyWith(
        phase: OnlinePhase.connecting, clearError: true);
    await _detachListeners();

    _msgSub = _ws.messages.listen(_onMessage);
    _stateSub = _ws.states.listen((s) {
      final inFlow = state.phase == OnlinePhase.waiting ||
          state.phase == OnlinePhase.inRoom;
      if (s == WsState.idle && inFlow) {
        state = state.copyWith(
            phase: OnlinePhase.error, errorMessage: '连接已断开');
      }
    });

    await _ws.connect(ref.read(serverUrlProvider));
    if (_ws.state == WsState.connected) {
      afterConnect();
    } else if (state.phase == OnlinePhase.connecting) {
      state = state.copyWith(
          phase: OnlinePhase.error, errorMessage: '无法连接服务器');
    }
  }

  void _onMessage(Map<String, Object?> msg) {
    switch (msg[Msg.type]) {
      case Msg.created:
        state = state.copyWith(
          phase: OnlinePhase.waiting,
          myColor: msg[Msg.color] as String?,
          roomId: msg[Msg.roomId] as String?,
          token: msg[Msg.token] as String?,
          opponentOnline: false,
        );

      case Msg.joined:
        // 入座确认（第二人开局 / 再战新局），手顺必为空盘。
        state = state.copyWith(
          phase: OnlinePhase.inRoom,
          game: _gameFromMoves(const []),
          opponentOnline: true,
          rematchOffered: false,
          rematchPending: false,
          myColor: msg[Msg.color] as String? ?? state.myColor,
        );

      case Msg.peerJoined:
        final serverPhase = msg['phase'] as String?;
        final opponentJustArrived = serverPhase != RoomPhase.waiting.name;
        state = state.copyWith(
          opponentOnline: true,
          phase: opponentJustArrived ? OnlinePhase.inRoom : state.phase,
          game: opponentJustArrived ? _gameFromMoves(const []) : state.game,
        );

      case Msg.moveApplied:
        try {
          state = state.copyWith(
              game: _gameFromMoves(decodeMoves(msg[Msg.moves])));
        } on FormatException {
          /* 服务端不会发坏数据；防御性忽略 */
        }

      case Msg.gameOver:
        _applyGameOver(msg);

      case Msg.peerLeft:
        state = state.copyWith(opponentOnline: false);

      case Msg.peerRejoined:
        state = state.copyWith(opponentOnline: true);

      case Msg.rejoined:
        _applyRestoredState(msg);

      case Msg.rematchRequested:
        state = state.copyWith(rematchOffered: true);

      case Msg.newGame:
        state = state.copyWith(
          phase: OnlinePhase.inRoom,
          game: _gameFromMoves(const []),
          rematchOffered: false,
          rematchPending: false,
        );

      case Msg.pong:
        break; // 心跳应答，无业务含义

      case Msg.error:
        state = state.copyWith(
          phase: OnlinePhase.error,
          errorMessage: msg[Msg.message] as String? ?? '未知错误',
        );
    }
  }

  /// 重连成功：按服务端快照恢复完整局面。
  void _applyRestoredState(Map<String, Object?> msg) {
    try {
      final moves = decodeMoves(msg[Msg.moves]);
      final rawLine = msg[Msg.line];
      final line = rawLine is List ? _lineFromJson(rawLine) : null;

      // 服务端重连快照只带连线坐标，胜方从连线首子的手数奇偶推出
      // （与手顺颜色推导规则一致）。
      WinInfo? win;
      if (line != null && line.isNotEmpty) {
        final firstIndex =
            moves.indexWhere((p) => p == line.first);
        win = WinInfo(
          winner: firstIndex.isEven ? Cell.black : Cell.white,
          line: line,
        );
      }

      state = state.copyWith(
        phase: OnlinePhase.inRoom,
        game: _gameFromMoves(moves, winInfo: win),
        opponentOnline: true,
        myColor: msg[Msg.color] as String? ?? state.myColor,
      );
    } on FormatException {
      state = state.copyWith(
          phase: OnlinePhase.error, errorMessage: '状态同步失败');
    }
  }

  /// 终局消息 → 更新 game.status 与胜利连线。
  void _applyGameOver(Map<String, Object?> msg) {
    final result = msg[Msg.result] as String? ?? '';
    List<Point>? line;
    final rawLine = msg[Msg.line];
    if (rawLine is List) line = _lineFromJson(rawLine);

    final GameState updated;
    if (result.startsWith('B') || result.startsWith('W')) {
      updated = state.game.copyWith(
        status: GameStatus.won,
        winInfo:
            WinInfo(winner: result.startsWith('B') ? Cell.black : Cell.white,
                line: line ?? const []),
      );
    } else {
      updated = state.game.copyWith(status: GameStatus.draw);
    }
    state = state.copyWith(game: updated);
  }

  /// 从手顺表重建完整对局状态（盘面由代码推导，绝不手拼）。
  GameState _gameFromMoves(List<Point> moves, {WinInfo? winInfo}) {
    final board = Board();
    for (var i = 0; i < moves.length; i++) {
      board.place(
          moves[i].x, moves[i].y, i.isEven ? Cell.black : Cell.white);
    }
    final status = winInfo != null
        ? GameStatus.won
        : (board.isFull ? GameStatus.draw : GameStatus.playing);
    return GameState(board: board, moves: moves, status: status, winInfo: winInfo);
  }

  List<Point> _lineFromJson(List raw) {
    try {
      return decodeMoves(raw);
    } on FormatException {
      return const [];
    }
  }

  Future<void> _detachListeners() async {
    await _msgSub?.cancel();
    await _stateSub?.cancel();
    _msgSub = null;
    _stateSub = null;
  }
}
