/// 在线对战消息协议 —— 客户端与服务端的唯一通信契约。
///
/// 【传输】WebSocket 文本帧，每帧一条 JSON 对象。
/// 【设计原则】
/// - 落子确认采用「全量 moves 回传」而非增量：一局最多 225 手，
///   每手两个整数，全量不过几 KB——换来的是客户端无需处理
///   「漏包乱序」类问题，任何时刻收到任意消息都能对齐状态；
/// - 坐标一律 [列x, 行y] 二元数组，与棋盘坐标系一致；
/// - 颜色用字符串 "black"/"white"，跨语言可读。
///
/// 消息一览（C→S 客户端发出 / S→C 服务端发出）：
/// ```
/// C→S: create | join(roomId) | rejoin(roomId,token)
///      move(x,y) | resign | rematch | rematchAccept | leave | ping
/// S→C: created | joined | rejoined | peerJoined | moveApplied
///      gameOver(result,reason,line) | peerLeft | peerRejoined
///      rematchRequested | newGame | error(message) | pong
/// ```
library;

import 'board.dart';
import 'rules.dart';

/// 房间逻辑阶段。
enum RoomPhase {
  /// 等待对手加入。
  waiting,

  /// 有玩家断线，等待其限时重连。
  reconnecting,

  /// 对局进行中。
  playing,

  /// 已分胜负（可发起再战）。
  finished,
}

/// 座位颜色常量（协议层用字符串，与 [Cell] 整数互转）。
abstract final class SeatColor {
  static const String black = 'black';
  static const String white = 'white';

  /// 全部合法颜色的遍历顺序。
  static const List<String> all = [black, white];

  /// 协议色 → 引擎整数。
  static int toStone(String color) =>
      color == black ? Cell.black : Cell.white;

  /// 引擎整数 → 协议色。
  static String fromStone(int stone) =>
      stone == Cell.black ? black : white;

  /// 对方颜色。
  static String opposite(String color) =>
      color == black ? white : black;
}

/// 协议编解码辅助。所有字段名集中于此，杜绝手滑拼错 key。
abstract final class Msg {
  // ---- 公共 ----
  static const String type = 'type';
  static const String roomId = 'roomId';
  static const String token = 'token';
  static const String color = 'color';
  static const String moves = 'moves';
  static const String x = 'x';
  static const String y = 'y';
  static const String result = 'result';
  static const String reason = 'reason';
  static const String line = 'line';
  static const String message = 'message';

  // ---- C→S ----
  static const String create = 'create';
  static const String join = 'join';
  static const String rejoin = 'rejoin';
  static const String move = 'move';
  static const String resign = 'resign';
  static const String rematch = 'rematch';
  static const String rematchAccept = 'rematchAccept';
  static const String leave = 'leave';
  static const String ping = 'ping';

  // ---- S→C ----
  static const String created = 'created';
  static const String joined = 'joined';
  static const String rejoined = 'rejoined';
  static const String peerJoined = 'peerJoined';
  static const String moveApplied = 'moveApplied';
  static const String gameOver = 'gameOver';
  static const String peerLeft = 'peerLeft';
  static const String peerRejoined = 'peerRejoined';
  static const String rematchRequested = 'rematchRequested';
  static const String newGame = 'newGame';
  static const String error = 'error';
  static const String pong = 'pong';
}

/// 手顺表 ↔ JSON 编码：[[x,y],[x,y],…]
List<List<int>> encodeMoves(List<Point> points) =>
    [for (final p in points) [p.x, p.y]];

/// JSON 手顺表 → [Point] 列表；格式非法抛 FormatException。
List<Point> decodeMoves(Object? raw) {
  if (raw is! List) throw const FormatException('moves 必须是数组');
  return raw.map((item) {
    if (item is! List || item.length != 2) {
      throw FormatException('非法着法: $item');
    }
    return Point(item[0] as int, item[1] as int);
  }).toList();
}

/// 胜利连线坐标编码（gameOver.line 用）。
List<List<int>> encodeLine(List<Point> line) => encodeMoves(line);
