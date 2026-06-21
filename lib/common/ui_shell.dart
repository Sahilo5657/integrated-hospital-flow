import 'package:flutter/material.dart';
import 'profile_screen.dart';

class UIShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showActions;

  const UIShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        actions: showActions
            ? [
                ...?actions,
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  tooltip: "My Profile",
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
