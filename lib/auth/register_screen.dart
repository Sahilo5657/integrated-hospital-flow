import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/ui_shell.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nfcController = TextEditingController();
  String _selectedRole = 'patient'; // Default role
  bool _hide = true;
  bool _isLoading = false;

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();
    final nfcId = _nfcController.text.trim();

    // 1. Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    if (_selectedRole == 'patient' && nfcId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NFC Card ID is required for patients")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Call AuthService via Provider with the selected role and NFC Card ID
      await Provider.of<AuthService>(context, listen: false).signUp(
        email,
        password,
        name,
        _selectedRole,
        nfcCardId: _selectedRole == 'patient' ? nfcId : null,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nfcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Create Account",
      showActions: false,
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Join Hospital Flow", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),

                // Role Selection Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: "I am a...", prefixIcon: Icon(Icons.badge)),
                  items: const [
                    DropdownMenuItem(value: 'patient', child: Text("Patient")),
                    DropdownMenuItem(value: 'doctor', child: Text("Doctor")),
                    DropdownMenuItem(value: 'staff', child: Text("Hospital Staff")),
                  ],
                  onChanged: (val) => setState(() => _selectedRole = val!),
                ),

                // NFC Card ID Field (Conditional for Patients)
                if (_selectedRole == 'patient') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nfcController,
                    decoration: const InputDecoration(
                      labelText: "NFC Card ID (Compulsory)",
                      prefixIcon: Icon(Icons.nfc),
                      helperText: "Card must be activated by hospital staff first.",
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _register,
                    icon: _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                        : const Icon(Icons.person_add),
                    label: Text(_isLoading ? "Creating Account..." : "Register"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
