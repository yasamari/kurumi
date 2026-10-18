import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'player_capture.dart';

/// キャプチャタブの一覧。撮影した画像を確認する。
///
/// 16:9 のサムネイルをグリッド表示し、タップで画像だけの拡大ダイアログを
/// 出す (枠外タップで閉じる)。削除はしない。
/// 選択中だけ載せる (コメントタブと同じく、不可視の画像デコードを避けるため)。
class CaptureListPanel extends StatelessWidget {
  const CaptureListPanel({super.key, required this.captures});

  /// キャプチャ一覧の通知元。画面の State が所有する。
  ///
  /// 購読はこのタブの中だけに行い、映像の再構築に巻き込まない
  /// ([SubtitleToggleButton] と同じ理屈)。
  final ValueListenable<List<CaptureEntry>> captures;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CaptureEntry>>(
      valueListenable: captures,
      builder: (context, entries, _) {
        if (entries.isEmpty) {
          return const Center(child: Text('キャプチャはまだありません'));
        }
        // 新しいものが先頭に来るよう逆順で並べる (一覧自体は撮影順のまま)。
        final reversed = entries.reversed.toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            // 幅に合わせて最大3列まで表示する。
            final columns = (constraints.maxWidth / 180).floor().clamp(1, 3);
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                // サムネイルは 16:9 で並べる。
                childAspectRatio: 16 / 9,
              ),
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                return InkWell(
                  onTap: () => _showCaptureDetail(context, entry),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(entry.jpegBytes, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 拡大ダイアログ。画像だけを表示する (画像・枠外タップで閉じる)。
  Future<void> _showCaptureDetail(BuildContext context, CaptureEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(entry.jpegBytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
