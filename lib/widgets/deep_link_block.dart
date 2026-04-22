import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _DeepLinkBlock extends StatelessWidget {
  final String code;
  const _DeepLinkBlock({required this.code});

  static String buildConnectLink(String code) {
    // Using the existing app deep-link scheme.
    // Always use `code=` so both manual offers and normal codes share one path.
    final uri = Uri(
      scheme: 'natproxy',
      host: 'connect',
      queryParameters: {'code': code},
    );
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final link = buildConnectLink(code);

    return Card(
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap-to-open Link',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SelectableText(
              link,
              style: t.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.2),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy link'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Opens the app directly on client.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
