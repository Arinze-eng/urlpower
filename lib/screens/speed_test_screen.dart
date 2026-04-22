import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:natproxy/services/platform_bridge.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  bool _running = false;
  String? _error;

  double? _downloadMbps;
  double? _uploadMbps;
  int? _downloadBytes;
  int? _uploadBytes;
  int? _downloadMs;
  int? _uploadMs;

  String _fmtBytes(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _downloadMbps = null;
      _uploadMbps = null;
      _downloadBytes = null;
      _uploadBytes = null;
      _downloadMs = null;
      _uploadMs = null;
    });

    try {
      final raw = await PlatformBridge.speedTestDirect();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      if (data['error'] != null) {
        setState(() {
          _error = data['error'] as String;
        });
        return;
      }

      setState(() {
        _downloadMbps = (data['download_mbps'] as num?)?.toDouble();
        _uploadMbps = (data['upload_mbps'] as num?)?.toDouble();
        _downloadBytes = (data['download_bytes'] as num?)?.toInt();
        _uploadBytes = (data['upload_bytes'] as num?)?.toInt();
        _downloadMs = (data['download_ms'] as num?)?.toInt();
        _uploadMs = (data['upload_ms'] as num?)?.toInt();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Speed Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Standalone internet speed test',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Runs a real download + upload against Cloudflare’s speed test endpoints. '
                      'This test is separate from the tunnel and can be used before connecting.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: _running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.speed),
                      label: Text(_running ? 'Testing…' : 'Run Speed Test'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Results',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'Download',
                        _downloadMbps == null
                            ? '-'
                            : '${_downloadMbps!.toStringAsFixed(1)} Mbps',
                      ),
                      _row(
                        'Upload',
                        _uploadMbps == null
                            ? '-'
                            : '${_uploadMbps!.toStringAsFixed(1)} Mbps',
                      ),
                      const Divider(height: 18),
                      _row('Download sample', _fmtBytes(_downloadBytes)),
                      _row('Download time', _downloadMs == null ? '-' : '${_downloadMs} ms'),
                      _row('Upload sample', _fmtBytes(_uploadBytes)),
                      _row('Upload time', _uploadMs == null ? '-' : '${_uploadMs} ms'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.white70))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
