import 'package:flutter/material.dart';

import '../common/placeholder_screen.dart';

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'ビデオ',
      icon: Icons.video_library_outlined,
    );
  }
}
