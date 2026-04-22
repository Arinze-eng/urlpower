import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:natproxy/widgets/animated_hero_header.dart';
import 'package:natproxy/widgets/app_background.dart';
import 'package:natproxy/widgets/glass_card.dart';
import 'package:natproxy/widgets/gradient_button.dart';
import 'package:natproxy/widgets/info_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _listenDeepLinks();
  }

  void _listenDeepLinks() {
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme != 'natproxy') return;
      if (uri.host != 'connect') return;

      final code = uri.queryParameters['code'];
      final offer = uri.queryParameters['offer'];
      final answer = uri.queryParameters['answer'];

      if (answer != null && answer.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: answer));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer copied. Open Server and paste it.')),
        );
        Navigator.pushNamed(context, '/server');
        return;
      }

      final payload = (offer != null && offer.isNotEmpty) ? offer : code;
      if (payload == null || payload.isEmpty) return;
      Navigator.pushNamed(context, '/client', arguments: {'code': payload});
    }, onError: (_) {
      // ignore
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

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
                        Text(
                          'Choose a mode',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        GradientButton(
                          onPressed: () => Navigator.pushNamed(context, '/server'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_rounded),
                              SizedBox(width: 10),
                              Text('Share Internet (Host)'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/client'),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Connect (Receiver)'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/speed-test'),
                          icon: const Icon(Icons.speed),
                          label: const Text('Speed Test (Standalone)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const InfoBanner(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Manual pairing quick start',
                  message:
                      '1) On Host: Server → Manual Exchange → share Offer QR/link\n'
                      '2) On Receiver: open link/scan QR → it generates Answer\n'
                      '3) Back on Host: paste Answer → connection goes live\n'
                      '4) Receiver taps Continue → VPN starts automatically',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
