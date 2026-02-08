import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';

class PatientQueueScreen extends StatelessWidget {
  const PatientQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentUser.value!.name.toLowerCase();

    return UIShell(
      title: "My Queue Status",
      child: ValueListenableBuilder<List<QueueItem>>(
        valueListenable: AuthService.instance.queue,
        builder: (context, queue, _) {
          final myItems = queue.where((q) => q.patientName.toLowerCase() == me).toList();
          if (myItems.isEmpty) {
            return const Center(child: Text("You are not in queue yet. Tap 'Join Queue (Demo)' from dashboard."));
          }

          final item = myItems.last;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Token #${item.tokenNo}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text("Queue ID: ${item.patientId}"),
              const SizedBox(height: 6),
              Text("Status: ${item.status.label}"),
              const SizedBox(height: 6),
              Text("ETA: ${item.etaMins} minutes"),
            ],
          );
        },
      ),
    );
  }
}
