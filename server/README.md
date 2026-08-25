# Five 对战服务器

纯 Dart 实现的 WebSocket 房间制对战服务端。与客户端共享同一份规则引擎
（`packages/five_core`），**胜负判定权威在服务端**，客户端无法伪造结果。

## 快速启动

```bash
cd server
dart pub get
PORT=8080 dart run bin/server.dart
# → Five 对战服务器已启动: ws://0.0.0.0:8080
```

客户端「在线对战 → 对战服务器」填 `ws://<服务器IP>:8080`。

## 运维要点

| 项 | 说明 |
|---|---|
| 健康检查 | `GET /health` → `{"ok":true,"rooms":N}` |
| 端口 | 环境变量 `PORT`，默认 8080 |
| 优雅关闭 | 收到 SIGTERM/SIGINT 自动收尾（Docker stop 友好） |
| 断线宽限 | 60 秒，超时判负（`Room.reconnectGrace` 可调） |
| 内存占用 | 每房间 < 10 KB，单实例数千房间无压力 |

## 测试

```bash
dart test    # 13 个房间生命周期测试：开局/落子/断线/重连/超时判负/再战
```

## 协议

见 `packages/five_core/lib/protocol.dart` 顶部注释——客户端与服务端
共享同一份协议定义，改协议只需改一处。

## 已知边界（v1.0）

- 房间状态存内存，进程重启即清空（对局类服务的常见取舍）
- 重连令牌不绑定身份——拿到房号+令牌即可恢复座位，
  朋友间对战足够；公网竞技场景需加账号体系
- 无速率限制——公网部署建议在前面加一层反代（nginx/caddy）做限流
