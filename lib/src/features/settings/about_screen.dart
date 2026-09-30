import 'package:flutter/material.dart';

/// このアプリについて。著作権・ライセンス・OSS帰属を表示する。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _copyright = 'Copyright (C) 2026 yasamari';
  static const _repositoryUrl = 'https://github.com/yasamari/kurumi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('OSSライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Kurumi',
              applicationLegalese: _copyright,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.code_outlined),
            title: Text('ソースコード'),
            subtitle: Text(_repositoryUrl),
          ),
        ],
      ),
    );
  }
}
