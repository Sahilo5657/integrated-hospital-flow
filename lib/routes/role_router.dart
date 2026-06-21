import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../doctor/doctor_home.dart';
import '../staff/staff_home.dart';
import '../patient/patient_home.dart';
import '../wall/wall_mounted_screen.dart';

class RoleRouter extends StatefulWidget {
  final FirebaseAuth? auth;
  const RoleRouter({super.key, this.auth});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    // Store the Future once — never recreated on rebuilds.
    // This is critical: a StatelessWidget would create a new Future on every
    // parent rebuild (AuthGate fires multiple times on login), resetting the
    // spinner indefinitely.
    final user = (widget.auth ?? FirebaseAuth.instance).currentUser;
    if (user != null) {
      _profileFuture = context
          .read<AuthService>()
          .getUserProfile(user.uid)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
    } else {
      _profileFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint("RoleRouter Error: ${snapshot.error}");
        }

        final profile = snapshot.data;

        if (profile == null) {
          debugPrint("RoleRouter: No profile found. Defaulting to PatientHome.");
          return const PatientHome();
        }

        switch (profile.role) {
          case 'doctor':
            return const DoctorHome();
          case 'staff':
            return const StaffHome();
          case 'patient':
            return const PatientHome();
          case 'wallmounted':
            return const WallMountedScreen();
          default:
            return const PatientHome();
        }
      },
    );
  }
}
