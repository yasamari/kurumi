import 'package:flutter/material.dart';

import '../utils/program_text.dart';

/// 番組情報文字列の表示用テキスト。
///
/// `parseProgramTextSymbols()` で分割し、`[字]` のような記号部分だけ
/// primary色背景のバッジとして描画する (KonomiTV の `decorate-symbol`
/// 相当)。1文字の記号は正方形に近づけ、角丸を付ける。
///
/// 通常の [Text] と同様に [style]・[maxLines]・[overflow] を指定できる。
class ProgramSymbolText extends StatelessWidget {
  const ProgramSymbolText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final badgeStyle = baseStyle.apply(
      color: colorScheme.onPrimary,
      fontSizeFactor: 0.85,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final segment in parseProgramTextSymbols(text))
            if (segment.isSymbol)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _SymbolBadge(
                  symbol: segment.text,
                  style: badgeStyle,
                  background: colorScheme.primary,
                ),
              )
            else
              TextSpan(text: segment.text),
        ],
      ),
      style: baseStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// 記号1件分のバッジ。1文字の場合は正方形にする。
class _SymbolBadge extends StatelessWidget {
  const _SymbolBadge({
    required this.symbol,
    required this.style,
    required this.background,
  });

  final String symbol;
  final TextStyle style;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
    );
    // 前後の文字との間隔。背景色の範囲には含めない。
    const margin = EdgeInsets.symmetric(horizontal: 2);
    // Container の `alignment` は親の最大幅いっぱいに広がるため使わない。
    // (WidgetSpan の子には行幅が最大幅として渡される)
    // 1文字は寸法確定の正方形で包み、中央揃えにする。
    if (symbol.runes.length == 1) {
      final dimension = (style.fontSize ?? 14.0) + 8.0;
      return Container(
        margin: margin,
        decoration: decoration,
        child: SizedBox.square(
          dimension: dimension,
          child: Center(
            child: Text(
              symbol,
              style: style.copyWith(height: 1.0),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: decoration,
      child: Text(
        symbol,
        style: style.copyWith(height: 1.0),
        textAlign: TextAlign.center,
      ),
    );
  }
}
