import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/time_format.dart';

/// 番組の進捗バー。1秒ごとに自分だけ作り直す。
///
/// 親 (`ChannelCard`) の再構築とは無関係に滑らかに進む。番組が切り替わったら
/// （`startAt`/`endAt` が変わったら）親の再構築で新しい値が渡される。
class ProgramProgressBar extends StatefulWidget {
  const ProgramProgressBar({
    super.key,
    required this.startAt,
    required this.endAt,
  });

  final DateTime startAt;
  final DateTime endAt;

  @override
  State<ProgramProgressBar> createState() => _ProgramProgressBarState();
}

class _ProgramProgressBarState extends State<ProgramProgressBar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: programProgress(widget.startAt, widget.endAt, _now),
    );
  }
}
