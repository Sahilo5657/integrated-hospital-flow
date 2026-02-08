import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';

class WallDisplayScreen extends StatelessWidget {
  const WallDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Wall Display",
      child: ValueListenableBuilder<List<QueueItem>>(
        valueListenable: AuthService.instance.queue,
        builder: (context, queue, _) {
          final nowServingList = queue.where((q) => q.status == QueueStatus.serving).toList();
          final waiting = queue.where((q) => q.status == QueueStatus.waiting).toList();

          final now = nowServingList.isEmpty ? null : nowServingList.first;
          final next = waiting.take(3).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NOW SERVING", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(
                        now == null ? "—" : "#${now.tokenNo}  •  ${now.patientName}",
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(now == null ? "" : "Queue ID: ${now.patientId}"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NEXT", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        if (next.isEmpty)
                          const Text("No upcoming patients.", style: TextStyle(fontSize: 18))
                        else
                          ...next.map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        "#${n.tokenNo}",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "${n.patientName}  •  ETA ${n.etaMins} min",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
