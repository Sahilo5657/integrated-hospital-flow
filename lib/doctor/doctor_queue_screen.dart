import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';

class DoctorQueueScreen extends StatelessWidget {
  const DoctorQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Today’s Queue",
      child: ValueListenableBuilder<List<QueueItem>>(
        valueListenable: AuthService.instance.queue,
        builder: (context, queue, _) {
          if (queue.isEmpty) return const Center(child: Text("Queue is empty."));
          return ListView.separated(
            itemCount: queue.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final q = queue[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
                    child: Text(
                      "${q.tokenNo}",
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900),
                    ),
                  ),
                  title: Text(q.patientName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text("Queue ID: ${q.patientId} • ETA: ${q.etaMins} min"),
                  trailing: Chip(label: Text(q.status.label)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
