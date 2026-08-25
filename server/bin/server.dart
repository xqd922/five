/// 服务端启动入口。
///
/// ```bash
/// PORT=9000 dart run bin/server.dart
/// ```
/// 环境变量：
/// - `PORT`：监听端口，默认 8080
library;

import 'dart:io';

import 'package:five_server/server_app.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await FiveServer.start(port: port);
  stdout.writeln('Five 对战服务器已启动: ws://0.0.0.0:$port');
  stdout.writeln('健康检查: http://<host>:$port/health');

  // 优雅关闭：SIGTERM（docker stop）/ SIGINT（Ctrl+C）时收尾。
  ProcessSignal.sigterm.watch().listen((_) => server.stop());
  ProcessSignal.sigint.watch().listen((_) => server.stop());
}
