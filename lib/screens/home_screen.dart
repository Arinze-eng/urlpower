import 'package:flutter/material.dart';
import 'package:natproxy/widgets/gradient_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CDN-NETSHARE'),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => Navigator.pushNamed(context, '/account'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GradientHeader(
              child: Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.wifi_tethering_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'P2P Internet Sharing',
                          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share your connection securely with nearby devices.',
                          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Choose a mode', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/server'),
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Share Internet (Server)'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/client'),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Connect (Client)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: cs.tertiary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.tips_and_updates_outlined, color: cs.tertiary),
                ),
                title: const Text('Tip'),
                subtitle: const Text('For best results, keep both devices on the same network and disable aggressive battery saving.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
