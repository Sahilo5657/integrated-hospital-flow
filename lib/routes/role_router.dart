import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../doctor/doctor_home.dart';
import '../staff/staff_home.dart';
import '../patient/patient_home.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in.")));
    }

    return FutureBuilder<UserProfile?>(
      // Firestore check with 3-second timeout fallback
      future: authService.getUserProfile(user.uid).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("RoleRouter: Profile fetch timed out for ${user.email}. Falling back to Patient View.");
          return null;
        },
      ),
      builder: (context, snapshot) {
        // --- UNCOUPLED DEVELOPMENT BYPASS GATE ---
        // This executes immediately, bypassing the loading wheel for test accounts.
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.email != null) {
          final email = currentUser.email!.toLowerCase();

          // 1. DOCTOR BYPASS
          if (email == 'sahilo5657@gmail.com' || email.contains('doctor')) {
            return const DoctorHome();
          }

          // 2. STAFF BYPASS
          if (email == 'eshaan5657@gmail.com' || email.contains('staff')) {
            return const StaffHome();
          }

          // 3. PATIENT BYPASS
          if (email.contains('patient') || email.contains('testpatient')) {
            return const PatientHome();
          }
        }

        // Standard loading state for non-bypass accounts
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          debugPrint("RoleRouter Error: ${snapshot.error}");
        }

        UserProfile? profile = snapshot.data;

        // If no profile found after timeout or fetch, default to PatientHome
        if (profile == null) {
          debugPrint("RoleRouter: No profile document found. Routing to PatientHome default.");
          return const PatientHome();
        }

        // Standard Routing Logic using the Firestore profile
        switch (profile.role) {
          case 'doctor':
            return const DoctorHome();
          case 'staff':
            return const StaffHome();
          case 'patient':
            return const PatientHome();
          default:
            return const PatientHome();
        }
      },
    );
  }
}
