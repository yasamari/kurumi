import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/comment_list_panel.dart';

void main() {
  test('再生位置の行の表示添字を求める', () {
    // reverse (index 0 が最新・下端) のため古い順の添字を反転する。
    // 3件中2件が再生位置までなら、表示添字は 3 - 2 = 1。
    expect(playbackBuilderIndex(commentCount: 3, dueCount: 2), 1);
    // 全件が再生位置までなら最新 (0)。
    expect(playbackBuilderIndex(commentCount: 3, dueCount: 3), 0);
    // 該当なしなら最古 (末尾)。
    expect(playbackBuilderIndex(commentCount: 3, dueCount: 0), 2);
    // 範囲外は丸める。
    expect(playbackBuilderIndex(commentCount: 3, dueCount: 9), 0);
    expect(playbackBuilderIndex(commentCount: 0, dueCount: 0), 0);
  });

  test('戻るボタンの向きは追従先への方向を向く', () {
    // ライブは常に下向き。
    expect(
      commentJumpIcon(
        isPlayback: false,
        anchor: 0,
        visibleRange: (min: 50, max: 60),
      ),
      Icons.arrow_downward,
    );
    // 再生位置より先 (新しい方) へ進んでいれば上向き。
    expect(
      commentJumpIcon(
        isPlayback: true,
        anchor: 100,
        visibleRange: (min: 0, max: 15),
      ),
      Icons.arrow_upward,
    );
    // 再生位置より前に戻っていれば下向き。
    expect(
      commentJumpIcon(
        isPlayback: true,
        anchor: 100,
        visibleRange: (min: 150, max: 165),
      ),
      Icons.arrow_downward,
    );
    // 範囲内なら中央との前後で決める。
    expect(
      commentJumpIcon(
        isPlayback: true,
        anchor: 102,
        visibleRange: (min: 100, max: 110),
      ),
      Icons.arrow_downward,
    );
    expect(
      commentJumpIcon(
        isPlayback: true,
        anchor: 108,
        visibleRange: (min: 100, max: 110),
      ),
      Icons.arrow_upward,
    );
    // 範囲不明なら下向き。
    expect(
      commentJumpIcon(isPlayback: true, anchor: 100, visibleRange: null),
      Icons.arrow_downward,
    );
  });
}
