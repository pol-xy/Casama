import 'package:flutter/material.dart';

import '../dashboard/main_navigation_shell.dart';

/// Interactive feature tour embedded in the live main section of Casama.
class InteractiveTutorialScreen extends StatelessWidget {
  const InteractiveTutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationShell(initialIndex: 0, isTourMode: true);
  }
}
