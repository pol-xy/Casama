import 'package:flutter/material.dart';

import 'auth_screen.dart';

/// Legacy `/login` route consolidated cleanly onto [AuthScreen] Log In mode.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialTabIndex: 1);
  }
}
