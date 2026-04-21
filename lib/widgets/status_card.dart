import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.28)),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.7)),
              const SizedBox(height: 12),
              ...children.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: DefaultTextStyle(
                    style: t.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                    child: w,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
