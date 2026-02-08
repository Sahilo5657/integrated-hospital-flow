import 'package:flutter/material.dart';

class UISection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const UISection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
