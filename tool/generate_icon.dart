/// 应用图标生成脚本（开发工具，不参与构建）。
///
/// 运行：`dart run tool/generate_icon.dart`
/// 产出：assets/icon.png (1024×1024)
///
/// 设计：深青瓷底 + 白色网格线 + 黑白双子对弈 + 斜向白子连珠示意。
/// 各平台启动器会自行裁切圆角/遮罩，因此这里输出全幅方图即可。
library;

import 'dart:io';

import 'package:image/image.dart' as img;

const int size = 1024;

void main() {
  final image = img.Image(width: size, height: size);

  // —— 底色：深青瓷（与 lib/main.dart 种子色同源）——
  img.fill(
    image,
    color: img.ColorUint8.rgb(0x00, 0x69, 0x6E),
  );

  // —— 网格线：7×7 简化棋盘 ——
  final grid = img.ColorUint8.rgba(255, 255, 255, 64);
  const margin = 150;
  const cells = 6; // 7 条线
  final step = (size - margin * 2) ~/ cells;
  for (var i = 0; i <= cells; i++) {
    final p = margin + i * step;
    img.drawLine(image,
        x1: p, y1: margin, x2: p, y2: size - margin, color: grid, thickness: 5);
    img.drawLine(image,
        x1: margin, y1: p, x2: size - margin, y2: p, color: grid, thickness: 5);
  }

  // —— 斜向白子连珠（视觉主角）——
  drawStone(image, margin + 1 * step, margin + 3 * step, white: true);
  drawStone(image, margin + 2 * step, margin + 4 * step, white: true);
  drawStone(image, margin + 3 * step, margin + 5 * step - 40, white: true);

  // —— 黑子（对手）——
  drawStone(image, margin + 2 * step, margin + 1 * step, white: false);
  drawStone(image, margin + 5 * step, margin + 2 * step, white: false);
  drawStone(image, margin + 4 * step, margin + 6 * step - 60, white: false);

  Directory('assets').createSync(recursive: true);
  File('assets/icon.png').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('OK assets/icon.png ($size×$size)');
}

/// 画一颗带高光的棋子。
void drawStone(img.Image image, int cx, int cy, {required bool white}) {
  const r = 56;
  final body = white
      ? img.ColorUint8.rgb(0xF6, 0xF8, 0xF9)
      : img.ColorUint8.rgb(0x14, 0x17, 0x19);
  final edge = white
      ? img.ColorUint8.rgb(0x00, 0x45, 0x49)
      : img.ColorUint8.rgb(0x3A, 0x3F, 0x42);
  final shadow = img.ColorUint8.rgb(0x08, 0x28, 0x2A);

  img.fillCircle(image, x: cx, y: cy + 6, radius: r, color: shadow);
  img.fillCircle(image, x: cx, y: cy, radius: r, color: body);
  img.drawCircle(image, x: cx, y: cy, radius: r, color: edge);
  if (white) {
    img.fillCircle(image,
        x: cx - 18, y: cy - 20, radius: 13, color: img.ColorUint8.rgb(255, 255, 255));
  }
}
