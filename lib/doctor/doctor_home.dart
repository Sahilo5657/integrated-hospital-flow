import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_card.dart';
import '../common/ui_section.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';
import 'doctor_queue_screen.dart';
import 'doctor_patient_record_screen.dart';
import '../wall/wall_display_screen.dart';

class DoctorHome extends StatelessWidget {
  const DoctorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value!;

    return UIShell(
      title: "Doctor Dashboard",
      actions: [
        IconButton(
          tooltip: "Logout",
          onPressed: AuthService.instance.logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        children: [
          Text("Welcome, Dr. ${user.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text("Manage queue, call next patient, and review clinical notes."),
          const SizedBox(height: 16),

          ValueListenableBuilder<List<QueueItem>>(
            valueListenable: AuthService.instance.queue,
            builder: (context, queue, _) {
              final serving = queue.where((q) => q.status == QueueStatus.serving).toList();
              final waitingCount = queue.where((q) => q.status == QueueStatus.waiting).length;
              final now = serving.isEmpty ? null : serving.first;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: UICard(
                          title: "Now Serving",
                          value: now == null ? "—" : "#${now.tokenNo}",
                          icon: Icons.campaign_outlined,
                          subtitle: now == null ? "No one yet" : now.patientName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UICard(
                          title: "Waiting",
                          value: "$waitingCount",
                          icon: Icons.people_alt_outlined,
                          subtitle: "Patients in queue",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  UICard(
                    title: "Daily Limit",
                    value: "${AuthService.instance.dailyLimit}",
                    icon: Icons.tune,
                    subtitle: "Max patients today",
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          UISection(
            title: "Queue Controls",
            subtitle: "Real-time behavior is simulated for defence.",
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: AuthService.instance.callNextDemo,
                      icon: const Icon(Icons.skip_next),
                      label: const Text("Call Next"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorQueueScreen())),
                      icon: const Icon(Icons.list_alt),
                      label: const Text("View Queue"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorPatientRecordScreen())),
                      icon: const Icon(Icons.folder_shared_outlined),
                      label: const Text("Patient Record"),
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
            ],
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Set Daily Limit (Demo)", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Slider(
                            value: AuthService.instance.dailyLimit.toDouble(),
                            min: 10,
                            max: 100,
                            divisions: 18,
                            label: "${AuthService.instance.dailyLimit}",
                            onChanged: (v) {
                              AuthService.instance.dailyLimit = v.round();
                              setState(() {});
                            },
                          ),
                          Text("Limit: ${AuthService.instance.dailyLimit} patients"),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
