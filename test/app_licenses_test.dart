import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/licenses/app_licenses.dart';

/// ネイティブ分の帰属情報が空になっていないことの回帰テスト。
void main() {
  test('手動登録分のライセンス情報が揃っている', () {
    final metas = buildAppLicenseMetas();

    expect(metas, isNotEmpty);
    final names = metas.map((m) => m.packageName).toList();
    expect(names, contains('kurumi'));
    expect(
      names.any((n) => n.contains('mpv') || n.contains('libmpv')),
      isTrue,
    );
    for (final meta in metas) {
      expect(meta.description, isNotEmpty);
      expect(meta.licenseText, isNotEmpty);
    }
  });
}
