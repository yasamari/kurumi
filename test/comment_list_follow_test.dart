import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/features/player/comment_list_panel.dart';

void main() {
  JikkyoComment comment(int no) {
    return JikkyoComment(
      threadId: '26985',
      no: no,
      vpos: no * 1000,
      postedAt: DateTime.utc(2026, 9, 30, 12).add(Duration(seconds: no)),
      content: 'x',
      userId: 'client-abc',
      mail: '',
    );
  }
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

  test('末尾へ足された新着の件数を数える', () {
    // 通常の追記は末尾の連続分だけ数える。
    final comments = [for (var no = 1; no <= 5; no++) comment(no)];
    expect(
      countAppendedLiveComments(
        comments: comments,
        prevLength: 3,
        prevMaxNo: 3,
      ),
      2,
    );
    // 上限到達時は先頭が捨てられても末尾の新着だけ数える。
    final capped = [for (var no = 3; no <= 7; no++) comment(no)];
    expect(
      countAppendedLiveComments(
        comments: capped,
        prevLength: 5,
        prevMaxNo: 5,
      ),
      2,
    );
    // 新着がなければ 0。
    expect(
      countAppendedLiveComments(
        comments: comments,
        prevLength: 5,
        prevMaxNo: 5,
      ),
      0,
    );
    // 初回は全件を新着とみなす。
    expect(
      countAppendedLiveComments(
        comments: comments,
        prevLength: 0,
        prevMaxNo: 0,
      ),
      5,
    );
    // 空なら 0。
    expect(
      countAppendedLiveComments(comments: const [], prevLength: 0, prevMaxNo: 0),
      0,
    );
  });

  test('上限到達時の先戻し量は平均行高×捨てた件数', () {
    // 全高 5000 (max 4600 + 画面 400) を 500 件で割った平均 10 × 2 件。
    expect(
      liveCapCompensationShift(
        maxScrollExtent: 4600,
        viewportDimension: 400,
        prevLength: 500,
        droppedCount: 2,
      ),
      20,
    );
    // 補正が要らないときは 0。
    expect(
      liveCapCompensationShift(
        maxScrollExtent: 4600,
        viewportDimension: 400,
        prevLength: 500,
        droppedCount: 0,
      ),
      0,
    );
    expect(
      liveCapCompensationShift(
        maxScrollExtent: 4600,
        viewportDimension: 400,
        prevLength: 0,
        droppedCount: 2,
      ),
      0,
    );
    expect(
      liveCapCompensationShift(
        maxScrollExtent: 0,
        viewportDimension: 400,
        prevLength: 500,
        droppedCount: 2,
      ),
      0,
    );
  });

  test('上限の先戻しは静止中の追従でのみ行う', () {
    // 末端で静止して新着で先頭が捨てられるときだけ先戻しする。
    expect(
      shouldCompensateLiveCap(
        following: true,
        animating: false,
        added: 2,
        dropped: 2,
        shift: 20,
      ),
      isTrue,
    );
    // 末端へのアニメーション実行中は先戻ししない。後ろへ引くたびに到着が
    // 遠のき、流れが続く限り末端に着地できなくなるため。
    expect(
      shouldCompensateLiveCap(
        following: true,
        animating: true,
        added: 2,
        dropped: 2,
        shift: 20,
      ),
      isFalse,
    );
    // 非追従・新着なし・捨てなし・量なしでは先戻ししない。
    expect(
      shouldCompensateLiveCap(
        following: false,
        animating: false,
        added: 2,
        dropped: 2,
        shift: 20,
      ),
      isFalse,
    );
    expect(
      shouldCompensateLiveCap(
        following: true,
        animating: false,
        added: 0,
        dropped: 0,
        shift: 20,
      ),
      isFalse,
    );
    expect(
      shouldCompensateLiveCap(
        following: true,
        animating: false,
        added: 2,
        dropped: 0,
        shift: 0,
      ),
      isFalse,
    );
    expect(
      shouldCompensateLiveCap(
        following: true,
        animating: false,
        added: 2,
        dropped: 2,
        shift: 0,
      ),
      isFalse,
    );
  });
}
