import 'package:flutter/material.dart';

import '../../domain/entities/channel.dart';

/// チャンネルロゴ。テレビ画面のカードと視聴画面の番組情報タブで共有する。
///
/// [width] で幅を指定する。高さは 16:9 から求める。ロゴが無いチャンネル
/// ([Channel.logoUrl] が null) や読み込み失敗時は何も描かない。
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.channel, this.width = 72});

  final Channel channel;

  /// ロゴの幅。ロゴを囲む角丸は 8px 固定。
  final double width;

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    if (url == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(),
          ),
        ),
      ),
    );
  }
}
