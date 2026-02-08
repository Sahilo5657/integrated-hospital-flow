import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_card.dart';
import '../common/ui_section.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';
import 'patient_queue_screen.dart';
import 'patient_summary_screen.dart';
import '../wall/wall_display_screen.dart';

class PatientHome extends StatelessWidget {
  const PatientHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value!;

    return UIShell(
      title: "Patient Dashboard",
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
          const Text("See your token, queue position, and ETA while away from the wall display."),
          const SizedBox(height: 16),

          ValueListenableBuilder<List<QueueItem>>(
            valueListenable: AuthService.instance.queue,
            builder: (context, queue, _) {
              final my = queue.where((q) => q.patientName.toLowerCase() == user.name.toLowerCase()).toList();
              final active = my.where((q) => q.status == QueueStatus.waiting || q.status == QueueStatus.serving).toList();
              final item = active.isNotEmpty ? active.first : null;

              final serving = queue.where((q) => q.status == QueueStatus.serving).toList();
              final nowServing = serving.isNotEmpty ? serving.first : null;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: UICard(
                          title: "My Token",
                          value: item == null ? "—" : "#${item.tokenNo}",
                          icon: Icons.confirmation_number_outlined,
                          subtitle: item == null ? "Not in queue yet" : "Queue ID: ${item.patientId}",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UICard(
                          title: "ETA",
                          value: item == null ? "—" : "${item.etaMins} min",
                          icon: Icons.timer_outlined,
                          subtitle: "Estimated waiting time",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  UICard(
                    title: "Now Serving",
                    value: nowServing == null ? "—" : "#${nowServing.tokenNo}",
                    icon: Icons.campaign_outlined,
                    subtitle: nowServing == null ? "Queue not started" : nowServing.patientName,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          UISection(
            title: "Quick Actions",
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => AuthService.instance.joinQueueDemo(user.name),
                      icon: const Icon(Icons.nfc),
                      label: const Text("Join Queue"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientQueueScreen())),
                      icon: const Icon(Icons.list_alt),
                      label: const Text("My Queue"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientSummaryScreen())),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("AI Summary (Demo)"),
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
        ],
      ),
    );
  }
}
