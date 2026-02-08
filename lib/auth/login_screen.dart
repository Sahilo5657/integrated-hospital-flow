import 'package:flutter/material.dart';
import '../common/ui_shell.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: "demo@hospital.com");
  final password = TextEditingController(text: "password123");
  final name = TextEditingController(text: "Demo User");
  bool hide = true;
  UserRole role = UserRole.patient;

  void _login() {
    AuthService.instance.loginDemo(
      name: name.text.trim().isEmpty ? "Demo User" : name.text.trim(),
      email: email.text.trim().isEmpty ? "demo@hospital.com" : email.text.trim(),
      role: role,
    );
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Login",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                "Hospital Patient Flow",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Role-based login for Patient, Doctor, and Receptionist/Admin.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: "Full Name (Demo)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: hide,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => hide = !hide),
                    icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<UserRole>(
                value: role,
                decoration: const InputDecoration(labelText: "Login As (Demo)"),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (v) => setState(() => role = v ?? UserRole.patient),
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.lock_open),
                  label: const Text("Login"),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text("Create Patient Account"),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
