import 'package:flutter/material.dart';
import '../common/ui_shell.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool hide = true;

  void _register() {
    if (password.text.trim() != confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    AuthService.instance.registerPatientDemo(
      name: name.text.trim().isEmpty ? "New Patient" : name.text.trim(),
      email: email.text.trim().isEmpty ? "patient@hospital.com" : email.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Register (Patient)",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Full Name")),
              const SizedBox(height: 12),
              TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
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
              TextField(
                controller: confirm,
                obscureText: hide,
                decoration: const InputDecoration(labelText: "Confirm Password"),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.person_add),
                  label: const Text("Create Account"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
