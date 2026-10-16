import 'package:flutter/material.dart';

import '../../core/utils/url_format.dart';
import '../../domain/entities/backend_type.dart';

/// バックエンドのサーバーURL編集ダイアログ。
///
/// [TextEditingController] はこのウィジェットが破棄されるタイミングで
/// dispose する（ダイアログ Future の完了時点では画面遷移アニメーションが
/// まだ進行中で、TextField が controller を参照しうるため）。
class UrlEditDialog extends StatefulWidget {
  const UrlEditDialog({
    super.key,
    required this.backendType,
    required this.initialValue,
    required this.hintText,
    required this.onSave,
    required this.onInvalid,
  });

  final BackendType backendType;
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onSave;
  final VoidCallback onInvalid;

  @override
  State<UrlEditDialog> createState() => _UrlEditDialogState();
}

class _UrlEditDialogState extends State<UrlEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final url = normalizeBaseUrl(_controller.text);
    if (url.isNotEmpty && !isValidBaseUrl(url)) {
      widget.onInvalid();
      return;
    }
    widget.onSave(url);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.backendType.label} サーバーURL'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.url,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(onPressed: _handleSave, child: const Text('保存')),
      ],
    );
  }
}

/// URL形式エラーの表示ダイアログ。
Future<void> showUrlErrorDialog(BuildContext context, String message) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    },
  );
}
