import 'package:flutter/material.dart';
import 'package:natproxy/widgets/animated_hero_header.dart';
import 'package:natproxy/widgets/app_background.dart';
import 'package:natproxy/widgets/glass_card.dart';
import 'package:natproxy/widgets/gradient_button.dart';
import 'package:natproxy/widgets/info_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
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
            const AnimatedHeroHeader(
              title: 'CDN-NETSHARE',
              subtitle: 'P2P sharing made simple, secure, and fast.',
              icon: Icons.wifi_tethering_rounded,
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Choose a mode', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    GradientButton(
                      onPressed: () => Navigator.pushNamed(context, '/server'),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_rounded),
                          SizedBox(width: 10),
                          Text('Share Internet (Server)'),
                        ],
                      ),
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
            InfoBanner(
              icon: Icons.auto_awesome_outlined,
              title: 'Quick start',
              message:
                  '1) Choose Server on the device sharing internet\n'
                  '2) Start Sharing and copy the Connection Code\n'
                  '3) On the other device choose Client and paste the code',
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
