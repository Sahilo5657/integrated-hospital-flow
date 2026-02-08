import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_shell.dart';
import 'staff_register_patient_screen.dart';
import '../wall/wall_display_screen.dart';

class StaffHome extends StatelessWidget {
  const StaffHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value!;

    return UIShell(
      title: "Receptionist/Admin Dashboard",
      actions: [
        IconButton(
          tooltip: "Logout",
          onPressed: AuthService.instance.logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        children: [
          Text("Welcome, ${user.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text("Register patients and manage onboarding."),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffRegisterPatientScreen())),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text("Register Patient"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WallDisplayScreen())),
                  icon: const Icon(Icons.tv),
                  label: const Text("Wall Display"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
