import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';
import '../patient/patient_home.dart';
import '../doctor/doctor_home.dart';
import '../staff/staff_home.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) return const SizedBox.shrink();

        switch (user.role) {
          case UserRole.patient:
            return const PatientHome();
          case UserRole.doctor:
            return const DoctorHome();
          case UserRole.staff:
            return const StaffHome();
        }
      },
    );
  }
}
