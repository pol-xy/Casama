import 'package:flutter/material.dart';

import 'interactive_tutorial_screen.dart';

/// Legacy `/tutorial` alias consolidated into [InteractiveTutorialScreen].
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InteractiveTutorialScreen();
  }
}
