import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/settings_model.dart';
import '../services/platform_bridge.dart';
import '../services/settings_service.dart';
import '../models/log_entry.dart';
import '../widgets/status_card.dart';
import '../widgets/connection_code.dart';
import '../widgets/vless_link.dart';
import '../widgets/log_panel.dart';
import '../widgets/app_background.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:app_links/app_links.dart';

const _kLogPollInterval = Duration(milliseconds: 500);
const _kStatusPollInterval = Duration(seconds: 2);

Widget _hostActivePill(BuildContext context, bool active) {
  final cs = Theme.of(context).colorScheme;
  final bg = active ? Colors.green.withOpacity(0.15) : cs.surfaceContainerHighest;
  final fg = active ? Colors.green.shade700 : cs.onSurfaceVariant;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: fg.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(active ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
            size: 16, color: fg),
        const SizedBox(width: 6),
        Text(active ? 'Host Active' : 'Host Inactive',
            style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
      ],
    ),
  );
}

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _deepLinkSub;
  bool _isRunning = false;
  bool _isStarting = false;
  String _connectionCode = '';
  String _vlessLink = '';
  String _publicIP = '';
  String _natMethod = '';
  String _protocol = '';
  String _transport = '';
  int _clientCount = 0;
  int _totalPeers = 0;
  int _bytesUp = 0;
  int _bytesDown = 0;

  // Coarse usage breakdown (server-side best-effort heuristics)
  int _webDown = 0;
  int _videoDown = 0;
  int _otherDown = 0;
  double _rateUp = 0;
  double _rateDown = 0;
  double _uptimeSec = 0;
  int _goroutines = 0;
  double _heapMB = 0;
  int _dataChannels = 0;
  int _peerConnections = 0;
  int _smuxStreams = 0;
  List<int> _streamDist = [];
  String? _error;
  String _listingId = '';
  String _natType = '';
  bool _detectingNat = false;
  ServerSettings _settings = const ServerSettings();
  final List<LogEntry> _logEntries = [];
  int _logCursor = 0;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  bool _manualStopRequested = false;
  Timer? _autoRestartTimer;

  // Manual signaling state
  int _manualStep = 0; // 0=off, 1=show offer, 2=enter answer, 3=connecting
  String _offerCode = '';
  final _answerController = TextEditingController();
  DateTime? _offerCreatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusSub = PlatformBridge.statusStream.listen(_onPlatformEvent);
    _loadSettings();
    _syncState();
    _detectNatType();
    PlatformBridge.requestBatteryOptimization();
    _listenDeepLinks();
  }

  @override
  void dispose() {
    _autoRestartTimer?.cancel();
    _statusSub?.cancel();
    _deepLinkSub?.cancel();
    _answerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _listenDeepLinks() {
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme != 'natproxy') return;
      if (uri.host != 'connect') return;

      final answer = uri.queryParameters['answer'];
      if (answer == null || answer.isEmpty) return;

      // If we are not already in manual flow, bring the user there.
      setState(() {
        _manualStep = _manualStep == 0 ? 2 : _manualStep;
        _answerController.text = answer;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer received. Tap Accept to connect.')),
        );
      }
    }, onError: (_) {
      // ignore
    });
  }

  void _onPlatformEvent(Map<String, dynamic> event) {
    if (event['event'] == 'stopped' && event['source'] == 'server' && mounted) {
      final shouldRestart = !_manualStopRequested;
      setState(() {
        _isRunning = false;
        _connectionCode = '';
        _vlessLink = '';
        _publicIP = '';
        _natMethod = '';
        _protocol = '';
        _transport = '';
        _clientCount = 0;
        _totalPeers = 0;
        _bytesUp = 0;
        _bytesDown = 0;
        _rateUp = 0;
        _rateDown = 0;
        _uptimeSec = 0;
        _goroutines = 0;
        _heapMB = 0;
        _dataChannels = 0;
        _peerConnections = 0;
        _smuxStreams = 0;
        _streamDist = [];
        _listingId = '';
        _manualStep = 0;
        _offerCode = '';
      });

      if (shouldRestart) {
        // Watchdog: if Android kills the service, bring it back.
        _autoRestartTimer?.cancel();
        _autoRestartTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (_isStarting || _isRunning) return;
          _manualStopRequested = false;
          _startServer();
        });
      }

      // Reset manual stop flag after handling stop.
      _manualStopRequested = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isStarting) {
      _syncState();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().loadServerSettings();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _syncState() async {
    try {
      final statusJson = await PlatformBridge.getServerStatus();
      final status = jsonDecode(statusJson) as Map<String, dynamic>;
      if (mounted) {
        final running = status['running'] as bool? ?? false;
        final isManual = status['manualMode'] as bool? ?? false;
        setState(() {
          _isRunning = running;
          if (running) {
            _publicIP = status['publicIP'] as String? ?? '';
            _clientCount = status['clients'] as int? ?? 0;
            _natMethod = status['upnp'] == true ? 'UPnP' : 'Hole Punch';
            _protocol = status['protocol'] as String? ?? '';
            _transport = status['transport'] as String? ?? '';
            final code = status['connectionCode'] as String? ?? '';
            if (code.isNotEmpty) _connectionCode = code;
            _vlessLink = status['vlessLink'] as String? ?? '';
            _totalPeers = status['totalPeers'] as int? ?? 0;
            _bytesUp = status['bytesUp'] as int? ?? 0;
            _bytesDown = status['bytesDown'] as int? ?? 0;
            _webDown = status['webDown'] as int? ?? 0;
            _videoDown = status['videoDown'] as int? ?? 0;
            _otherDown = status['otherDown'] as int? ?? 0;
            _rateUp = (status['rateUp'] as num?)?.toDouble() ?? 0;
            _rateDown = (status['rateDown'] as num?)?.toDouble() ?? 0;
            _uptimeSec = (status['uptimeSec'] as num?)?.toDouble() ?? 0;
            _goroutines = status['goroutines'] as int? ?? 0;
            _heapMB = (status['heapMB'] as num?)?.toDouble() ?? 0;
            _dataChannels = status['dataChannels'] as int? ?? 0;
            _peerConnections = status['peerConnections'] as int? ?? 0;
            _smuxStreams = status['smuxStreams'] as int? ?? 0;
            _streamDist = (status['streamDist'] as List<dynamic>?)
                    ?.map((e) => (e as num).toInt())
                    .toList() ??
                [];
            // Restore manual mode state on resume
            if (isManual && _manualStep == 0) {
              final offer = status['offerCode'] as String? ?? '';
              if (offer.isNotEmpty) {
                _offerCode = offer;
                _manualStep = 1;
              }
            }
          }
        });
        if (running) {
          _pollStatus();
          _pollLogs();
        }
      }
    } catch (e) {
      debugPrint('ServerScreen: syncState error: $e');
    }
  }

  Future<void> _detectNatType() async {
    setState(() => _detectingNat = true);
    try {
      final result = await PlatformBridge.detectNatType();
      if (mounted) {
        setState(() {
          _natType = result;
          _detectingNat = false;
        });
      }
    } catch (e) {
      debugPrint('ServerScreen: detectNatType error: $e');
      if (mounted) setState(() => _detectingNat = false);
    }
  }

  String _formatNatType(String raw) {
    switch (raw) {
      case 'full_cone':
        return 'Full Cone';
      case 'restricted_cone':
        return 'Restricted Cone';
      case 'port_restricted':
        return 'Port Restricted';
      case 'symmetric':
        return 'Symmetric';
      case 'cone':
        return 'Cone';
      case 'unknown':
        return 'Unknown';
      default:
        return raw;
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    _pollLogs();
    try {
      final settingsJson = jsonEncode(_settings.toJson());
      final result = await PlatformBridge.startServer(settingsJson);
      if (!mounted) return;
      // Parse result: JSON {"code":"...", "vless":"..."} or raw base64 string
      String code = result;
      String vless = '';
      if (result.startsWith('{')) {
        try {
          final parsed = jsonDecode(result) as Map<String, dynamic>;
          code = parsed['code'] as String? ?? result;
          vless = parsed['vless'] as String? ?? '';
        } catch (_) {
          // Fallback: treat as raw connection code
        }
      }
      setState(() {
        _connectionCode = code;
        _vlessLink = vless;
        _isRunning = true;
        _isStarting = false;
      });
      _pollStatus();
      // Register on discovery if enabled
      if (_settings.discoveryEnabled && _settings.displayName.isNotEmpty) {
        try {
          final discoverySettings = jsonEncode({
            'signalingUrl': _settings.signalingUrl,
            'discoveryUrl': _settings.discoveryUrl,
            'displayName': _settings.displayName,
            'room': _settings.room,
          });
          final id = await PlatformBridge.registerDiscovery(
            code,
            discoverySettings,
          );
          if (mounted) setState(() => _listingId = id);
        } catch (e) {
          debugPrint('ServerScreen: discovery register failed: $e');
          if (mounted) {
            setState(
              () => _error = 'Server started but discovery registration failed',
            );
          }
        }
      }
    } catch (e, stack) {
      debugPrint('ServerScreen: startServer error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isStarting = false;
      });
    }
  }

  // Manual signaling

  Future<void> _startServerManual() async {
    setState(() {
      _isStarting = true;
      _error = null;
      _manualStep = 0;
      _offerCode = '';
    });
    _pollLogs();
    try {
      final settingsJson = jsonEncode(_settings.toJson());
      final offerCode = await PlatformBridge.startServerManual(settingsJson);
      if (!mounted) return;
      setState(() {
        _offerCode = offerCode;
        _manualStep = 1;
        _isRunning = true;
        _isStarting = false;
        _offerCreatedAt = DateTime.now();
      });
      _pollStatus();
    } catch (e, stack) {
      debugPrint('ServerScreen: startServerManual error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isStarting = false;
      });
    }
  }

  Future<void> _acceptManualAnswer() async {
    final answerCode = _answerController.text.trim();
    if (answerCode.isEmpty) {
      setState(() => _error = 'Please paste the answer code');
      return;
    }

    // Quick validation to reduce common copy/paste mistakes.
    if (!answerCode.startsWith('M1A:')) {
      setState(
        () => _error =
            'Invalid answer code. It should start with "M1A:" (manual answer).',
      );
      return;
    }

    setState(() {
      _manualStep = 3;
      _error = null;
    });

    try {
      await PlatformBridge.acceptManualAnswer(answerCode);
      if (!mounted) return;
      setState(() {
        _manualStep = 0;
        _offerCode = '';
        _answerController.clear();
      });
    } catch (e, stack) {
      debugPrint('ServerScreen: acceptManualAnswer error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _manualStep = 2; // allow retry
      });
    }
  }

  Future<void> _stopServer() async {
    _manualStopRequested = true;
    _autoRestartTimer?.cancel();
    try {
      if (_listingId.isNotEmpty) {
        try {
          await PlatformBridge.unregisterDiscovery();
        } catch (e) {
          debugPrint('ServerScreen: discovery unregister failed: $e');
        }
      }
      await PlatformBridge.stop();
      setState(() {
        _isRunning = false;
        _connectionCode = '';
        _vlessLink = '';
        _publicIP = '';
        _natMethod = '';
        _protocol = '';
        _transport = '';
        _clientCount = 0;
        _totalPeers = 0;
        _bytesUp = 0;
        _bytesDown = 0;
        _rateUp = 0;
        _rateDown = 0;
        _uptimeSec = 0;
        _goroutines = 0;
        _heapMB = 0;
        _dataChannels = 0;
        _peerConnections = 0;
        _smuxStreams = 0;
        _streamDist = [];
        _listingId = '';
        _manualStep = 0;
        _offerCode = '';
      });
    } catch (e, stack) {
      debugPrint('ServerScreen: stopServer error: $e\n$stack');
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _pollLogs() async {
    while ((_isStarting || _isRunning) && mounted) {
      await _fetchLogs();
      await Future.delayed(_kLogPollInterval);
    }
  }

  Future<void> _pollStatus() async {
    while (_isRunning && mounted) {
      try {
        final statusJson = await PlatformBridge.getServerStatus();
        final status = jsonDecode(statusJson) as Map<String, dynamic>;
        if (mounted && _isRunning) {
          setState(() {
            _publicIP = status['publicIP'] as String? ?? '';
            _clientCount = status['clients'] as int? ?? 0;
            _natMethod = status['upnp'] == true ? 'UPnP' : 'Hole Punch';
            _protocol = status['protocol'] as String? ?? '';
            _transport = status['transport'] as String? ?? '';
            _vlessLink = status['vlessLink'] as String? ?? '';
            _totalPeers = status['totalPeers'] as int? ?? 0;
            _bytesUp = status['bytesUp'] as int? ?? 0;
            _bytesDown = status['bytesDown'] as int? ?? 0;
            _rateUp = (status['rateUp'] as num?)?.toDouble() ?? 0;
            _rateDown = (status['rateDown'] as num?)?.toDouble() ?? 0;
            _uptimeSec = (status['uptimeSec'] as num?)?.toDouble() ?? 0;
            _goroutines = status['goroutines'] as int? ?? 0;
            _heapMB = (status['heapMB'] as num?)?.toDouble() ?? 0;
            _dataChannels = status['dataChannels'] as int? ?? 0;
            _peerConnections = status['peerConnections'] as int? ?? 0;
            _smuxStreams = status['smuxStreams'] as int? ?? 0;
            _streamDist = (status['streamDist'] as List<dynamic>?)
                    ?.map((e) => (e as num).toInt())
                    .toList() ??
                [];
          });
        }
      } catch (e) {
        debugPrint('ServerScreen: pollStatus error: $e');
      }
      await Future.delayed(_kStatusPollInterval);
    }
  }

  Future<void> _fetchLogs() async {
    try {
      final logsJson = await PlatformBridge.getLogs(_logCursor);
      final data = jsonDecode(logsJson) as Map<String, dynamic>;
      final entries =
          (data['e'] as List<dynamic>?)
              ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (entries.isNotEmpty && mounted) {
        setState(() {
          _logEntries.addAll(entries);
          _logCursor = data['c'] as int? ?? _logCursor;
        });
      }
    } catch (e) {
      debugPrint('ServerScreen: fetchLogs error: $e');
    }
  }

  Future<void> _clearLogs() async {
    try {
      await PlatformBridge.clearLogs();
      setState(() {
        _logEntries.clear();
        _logCursor = 0;
      });
    } catch (e) {
      debugPrint('ServerScreen: clearLogs error: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatRate(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatUptime(double seconds) {
    final dur = Duration(seconds: seconds.toInt());
    if (dur.inHours > 0) {
      return '${dur.inHours}h ${dur.inMinutes.remainder(60)}m';
    }
    if (dur.inMinutes > 0) {
      return '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s';
    }
    return '${dur.inSeconds}s';
  }

  Widget _usageRow(
    BuildContext context, {
    required String label,
    required int bytes,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? (bytes / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatBytes(bytes),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualWizard() {
    switch (_manualStep) {
      case 1:
        // Show offer code
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Step 1: Share Offer Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_offerCreatedAt != null)
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, _) {
                          final elapsed = DateTime.now()
                              .difference(_offerCreatedAt!)
                              .inSeconds;
                          return Text(
                            '${elapsed}s ago',
                            style: TextStyle(
                              fontSize: 12,
                              color: elapsed > 120
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send this code to the client device. '
                  'Complete the exchange within 2-3 minutes.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final link = Uri(
                    scheme: 'natproxy',
                    host: 'connect',
                    queryParameters: {'code': _offerCode},
                  ).toString();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _offerCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap-to-open Link (recommended)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          link,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: link,
                            size: 180,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _offerCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offer code copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            setState(() => _manualStep = 2),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case 2:
        // Enter answer code
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.input, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Step 2: Enter Answer Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste the answer code from the client device.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Paste M1A:... code here',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.paste_rounded),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _answerController.text = data!.text!;
                        }
                      },
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _manualStep = 1),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _acceptManualAnswer,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case 3:
        // Connecting
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Establishing connection...',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Waiting for ICE negotiation',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
        title: const Text('Share Internet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/server-settings');
              _loadSettings();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _hostActivePill(context, _isRunning),
                  ),
                  const SizedBox(height: 12),
                  StatusCard(
                    icon: _isRunning ? Icons.cloud_upload : Icons.cloud_off,
                    title: _isRunning ? 'Server Running' : 'Server Stopped',
                    color: _isRunning ? Colors.green : Colors.grey,
                    children: [
                      if (_detectingNat)
                        const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Detecting NAT type...'),
                          ],
                        )
                      else if (_natType.isNotEmpty)
                        Text('NAT Type: ${_formatNatType(_natType)}'),
                      if (_publicIP.isNotEmpty) Text('Public IP: $_publicIP'),
                      if (_natMethod.isNotEmpty)
                        Text('NAT Method: $_natMethod'),
                      if (_protocol.isNotEmpty)
                        Text(
                          'Protocol: ${_protocol.toUpperCase()}'
                          '${_transport.isNotEmpty ? ' / ${_transport.toUpperCase()}' : ''}',
                        ),
                      if (_isRunning) ...[
                        Text(
                          'Peers: $_clientCount active'
                          '${_totalPeers > 0 ? ' / $_totalPeers total' : ''}',
                        ),
                        Text(
                          'Upload: ${_formatBytes(_bytesUp)}'
                          '${_rateUp > 0 ? ' (${_formatRate(_rateUp)})' : ''}',
                        ),
                        Text(
                          'Download: ${_formatBytes(_bytesDown)}'
                          '${_rateDown > 0 ? ' (${_formatRate(_rateDown)})' : ''}',
                        ),
                        Text('Uptime: ${_formatUptime(_uptimeSec)}'),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Resource Details',
                              style: TextStyle(fontSize: 13),
                            ),
                            children: [
                              Text('Goroutines: $_goroutines'),
                              Text(
                                'Heap: ${_heapMB.toStringAsFixed(1)} MB',
                              ),
                              Text('PeerConnections: $_peerConnections'),
                              Text('Data Channels: $_dataChannels'),
                              Text('Smux Streams: $_smuxStreams'),
                              if (_streamDist.isNotEmpty)
                                Text('Stream Dist: $_streamDist'),
                            ],
                          ),
                        ),
                      ],
                      if (_listingId.isNotEmpty && _isRunning)
                        const Text(
                          'Listed on discovery',
                          style: TextStyle(color: Colors.blue),
                        ),
                    ],
                  ),

                  // Lightweight dashboard: shows what is routing through the host.
                  if (_isRunning) ...[
                    const SizedBox(height: 12),
                    StatusCard(
                      icon: Icons.dashboard,
                      title: 'Routing dashboard (through host)',
                      color: Colors.tealAccent,
                      children: [
                        const Text(
                          'This is a best-effort breakdown based on destination ports. '
                          'Content is not inspected (TLS is opaque).',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        _usageRow(
                          context,
                          label: 'Web (80/443)',
                          bytes: _webDown,
                          total: _bytesDown,
                          color: Colors.lightBlueAccent,
                        ),
                        _usageRow(
                          context,
                          label: 'Video / large HTTPS',
                          bytes: _videoDown,
                          total: _bytesDown,
                          color: Colors.purpleAccent,
                        ),
                        _usageRow(
                          context,
                          label: 'Other',
                          bytes: _otherDown,
                          total: _bytesDown,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Routing policy: client traffic (incl. DNS) is forced through the host tunnel.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_manualStep > 0) ...[
                    const SizedBox(height: 16),
                    _buildManualWizard(),
                  ],
                  if (_connectionCode.isNotEmpty && _manualStep == 0) ...[
                    const SizedBox(height: 16),
                    ConnectionCodeDisplay(code: _connectionCode),
                  ],
                  if (_vlessLink.isNotEmpty && _manualStep == 0) ...[
                    const SizedBox(height: 12),
                    VLESSLinkDisplay(link: _vlessLink),
                  ],
                  const SizedBox(height: 24),
                  if (!_isRunning && _manualStep == 0) ...[
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _isStarting ? null : _startServer,
                        icon: _isStarting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _isStarting ? 'Starting...' : 'Start Sharing',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isStarting ? null : _startServerManual,
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        label: const Text('Manual Exchange'),
                      ),
                    ),
                  ] else if (_isRunning) ...[
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _stopServer,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Sharing'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          LogPanel(entries: _logEntries, onClear: _clearLogs),
        ],
      ),
        ),
      ),
    );
  }
}
