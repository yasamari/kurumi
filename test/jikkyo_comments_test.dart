import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment_list.dart';

void main() {
  // 固定した基準時刻。コメントの生成にだけ使い、テストの挙動には影響させない。
  final base = DateTime.utc(2026, 9, 30, 12);

  JikkyoComment comment(
    int no, {
    String content = 'x',
    Duration age = const Duration(seconds: 1),
  }) {
    return JikkyoComment(
      threadId: '26985',
      no: no,
      vpos: no * 1000,
      postedAt: base.subtract(age),
      content: content,
      userId: 'client-abc',
      mail: '',
    );
  }

  test('新着コメントはコメント番の昇順に並ぶ', () {
    final merged = mergeJikkyoComments(
      existing: const [],
      incoming: [comment(3), comment(1), comment(2)],
    );
    expect(merged.map((c) => c.no).toList(), [1, 2, 3]);
  });

  test('コメント番が重複したら既存を優先して1件にまとめる', () {
    final merged = mergeJikkyoComments(
      existing: [comment(1, content: '既存')],
      incoming: [comment(1, content: '重複'), comment(2)],
    );
    expect(merged.map((c) => c.no).toList(), [1, 2]);
    expect(merged.first.content, '既存');
  });

  test('過去ログのように古いコメントが届いても正しい位置に並ぶ', () {
    // 過去ログは「既存より古い」コメントとして届く。
    final merged = mergeJikkyoComments(
      existing: [comment(10), comment(11)],
      incoming: [comment(8), comment(9)],
    );
    expect(merged.map((c) => c.no).toList(), [8, 9, 10, 11]);
  });

  test('新着が既存より新しい場合は末尾に足される', () {
    // 新着が既存より新しい場合は末尾に足される。
    final merged = mergeJikkyoComments(
      existing: [comment(1), comment(2)],
      incoming: [comment(3)],
    );
    expect(merged.map((c) => c.no).toList(), [1, 2, 3]);
  });

  test('最大件数を超えたら古いものから捨てる', () {
    final merged = mergeJikkyoComments(
      existing: const [],
      incoming: [for (var no = 1; no <= 10; no++) comment(no)],
      maxCount: 3,
    );
    expect(merged.map((c) => c.no).toList(), [8, 9, 10]);
  });

  test('最大件数之内ならそのまま返す', () {
    final merged = mergeJikkyoComments(
      existing: const [],
      incoming: [comment(1), comment(2)],
      maxCount: 5,
    );
    expect(merged.map((c) => c.no).toList(), [1, 2]);
  });

  test('受け皿が空なら空のままになる', () {
    expect(mergeJikkyoComments(existing: const [], incoming: const []), isEmpty);
  });

  test('コメ番に欠番があっても壊れない', () {
    // NX-Jikkyo はキュー溢れで古いコメントを黙って捨てるため、連続性は無保証。
    final merged = mergeJikkyoComments(
      existing: const [],
      incoming: [comment(1), comment(900), comment(901)],
    );
    expect(merged.map((c) => c.no).toList(), [1, 900, 901]);
  });

  test('既定の保持件数が 500 件である', () {
    expect(jikkyoCommentBufferSize, 500);
  });
}
