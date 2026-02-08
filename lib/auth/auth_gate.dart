import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import '../routes/role_router.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) return const LoginScreen();
        return const RoleRouter();
      },
    );
  }
}
