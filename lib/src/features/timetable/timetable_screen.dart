import 'package:flutter/material.dart';

import '../common/placeholder_screen.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '番組表',
      icon: Icons.calendar_view_day_outlined,
    );
  }
}
