import 'package:flutter/material.dart';

import '../common/placeholder_screen.dart';

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '録画予約',
      icon: Icons.schedule_outlined,
    );
  }
}
