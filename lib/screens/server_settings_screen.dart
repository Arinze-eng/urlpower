import 'package:flutter/material.dart';
import 'package:natproxy/models/settings_model.dart';
import 'package:natproxy/services/settings_service.dart';
import 'package:natproxy/services/name_generator.dart';
import 'package:natproxy/widgets/app_background.dart';
import 'package:natproxy/widgets/glass_card.dart';
import 'package:uuid/uuid.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isLoading = true;

  // Controllers
  final _portController = TextEditingController();
  final _stunController = TextEditingController();
  final _signalingController = TextEditingController();
  final _upnpLeaseDurationController = TextEditingController();
  final _upnpRetriesController = TextEditingController();
  final _ssdpTimeoutController = TextEditingController();
  final _socksUsernameController = TextEditingController();
  final _socksPasswordController = TextEditingController();
  final _kcpMtuController = TextEditingController();
  final _kcpSndWndController = TextEditingController();
  final _kcpRcvWndController = TextEditingController();
  final _kcpReadBufferController = TextEditingController();
  final _kcpWriteBufferController = TextEditingController();
  final _xhttpPathController = TextEditingController();
  final _numPeerConnectionsController = TextEditingController();
  final _numChannelsController = TextEditingController();
  final _smuxStreamBufferController = TextEditingController();
  final _smuxSessionBufferController = TextEditingController();
  final _smuxFrameSizeController = TextEditingController();
  final _smuxKeepAliveController = TextEditingController();
  final _smuxKeepAliveTimeoutController = TextEditingController();
  final _dcMaxBufferedController = TextEditingController();
  final _dcLowMarkController = TextEditingController();
  final _paddingMaxController = TextEditingController();
  final _sctpRecvBufferController = TextEditingController();
  final _sctpRTOMaxController = TextEditingController();
  final _udpReadBufferController = TextEditingController();
  final _udpWriteBufferController = TextEditingController();
  final _iceDisconnTimeoutController = TextEditingController();
  final _iceFailedTimeoutController = TextEditingController();
  final _iceKeepaliveController = TextEditingController();
  final _dtlsRetransmitController = TextEditingController();
  final _uuidController = TextEditingController();

  // Settings State
  String _natMethod = 'auto';
  String _protocol = 'vless';
  String _transport = 'kcp';
  String _socksAuth = 'noauth';
  bool _socksUdp = true;
  String _uuidMode = 'random';
  bool _useRelay = false;
  String _transportMode = 'datachannel';
  bool _disableIPv6 = false;
  final _rateLimitUpController = TextEditingController();
  final _rateLimitDownController = TextEditingController();
  bool _paddingEnabled = false;
  bool _dtlsSkipVerify = false;
  bool _sctpZeroChecksum = false;
  bool _disableCloseByDTLS = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.loadServerSettings();
      if (!mounted) return;
      _applySettings(settings);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load settings: $e')),
      );
    }
  }

  void _applySettings(ServerSettings s) {
    _portController.text = s.listenPort.toString();
    _stunController.text = s.stunServer;
    _signalingController.text = s.signalingUrl;
    _natMethod = s.natMethod;
    _upnpLeaseDurationController.text = s.upnpLeaseDuration.toString();
    _upnpRetriesController.text = s.upnpRetries.toString();
    _ssdpTimeoutController.text = s.ssdpTimeout.toString();
    _protocol = s.protocol;
    _transport = s.transport;
    _socksAuth = s.socksAuth;
    _socksUsernameController.text = s.socksUsername;
    _socksPasswordController.text = s.socksPassword;
    _socksUdp = s.socksUdp;
    _uuidController.text = s.uuid;
    _useRelay = s.useRelay;
    _transportMode = s.transportMode;
    _disableIPv6 = s.disableIPv6;
    _rateLimitUpController.text = s.rateLimitUp.toString();
    _rateLimitDownController.text = s.rateLimitDown.toString();
    _paddingEnabled = s.paddingEnabled;
    _paddingMaxController.text = s.paddingMax.toString();
    _numPeerConnectionsController.text = s.numPeerConnections.toString();
    _numChannelsController.text = s.numChannels.toString();
    _smuxStreamBufferController.text = s.smuxStreamBuffer.toString();
    _smuxSessionBufferController.text = s.smuxSessionBuffer.toString();
    _smuxFrameSizeController.text = s.smuxFrameSize.toString();
    _smuxKeepAliveController.text = s.smuxKeepAlive.toString();
    _smuxKeepAliveTimeoutController.text = s.smuxKeepAliveTimeout.toString();
    _dcMaxBufferedController.text = s.dcMaxBuffered.toString();
    _dcLowMarkController.text = s.dcLowMark.toString();
    _sctpRecvBufferController.text = s.sctpRecvBuffer.toString();
    _sctpRTOMaxController.text = s.sctpRTOMax.toString();
    _udpReadBufferController.text = s.udpReadBuffer.toString();
    _udpWriteBufferController.text = s.udpWriteBuffer.toString();
    _iceDisconnTimeoutController.text = s.iceDisconnTimeout.toString();
    _iceFailedTimeoutController.text = s.iceFailedTimeout.toString();
    _iceKeepaliveController.text = s.iceKeepalive.toString();
    _dtlsRetransmitController.text = s.dtlsRetransmit.toString();
    _dtlsSkipVerify = s.dtlsSkipVerify;
    _sctpZeroChecksum = s.sctpZeroChecksum;
    _disableCloseByDTLS = s.disableCloseByDTLS;
    _kcpMtuController.text = s.kcpMtu.toString();
    _kcpReadBufferController.text = s.kcpReadBufferSize.toString();
    _kcpWriteBufferController.text = s.kcpWriteBufferSize.toString();
    _xhttpPathController.text = s.xhttpPath;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final s = ServerSettings(
      listenPort: int.parse(_portController.text),
      stunServer: _stunController.text,
      signalingUrl: _signalingController.text,
      natMethod: _natMethod,
      upnpLeaseDuration: int.parse(_upnpLeaseDurationController.text),
      upnpRetries: int.parse(_upnpRetriesController.text),
      ssdpTimeout: int.parse(_ssdpTimeoutController.text),
      protocol: _protocol,
      transport: _transport,
      socksAuth: _socksAuth,
      socksUsername: _socksUsernameController.text,
      socksPassword: _socksPasswordController.text,
      socksUdp: _socksUdp,
      uuid: _uuidController.text,
      useRelay: _useRelay,
      transportMode: _transportMode,
      disableIPv6: _disableIPv6,
      rateLimitUp: int.tryParse(_rateLimitUpController.text) ?? 0,
      rateLimitDown: int.tryParse(_rateLimitDownController.text) ?? 0,
      paddingEnabled: _paddingEnabled,
      paddingMax: int.parse(_paddingMaxController.text),
      numPeerConnections: int.parse(_numPeerConnectionsController.text),
      numChannels: int.parse(_numChannelsController.text),
      smuxStreamBuffer: int.parse(_smuxStreamBufferController.text),
      smuxSessionBuffer: int.parse(_smuxSessionBufferController.text),
      smuxFrameSize: int.parse(_smuxFrameSizeController.text),
      smuxKeepAlive: int.parse(_smuxKeepAliveController.text),
      smuxKeepAliveTimeout: int.parse(_smuxKeepAliveTimeoutController.text),
      dcMaxBuffered: int.parse(_dcMaxBufferedController.text),
      dcLowMark: int.parse(_dcLowMarkController.text),
      sctpRecvBuffer: int.parse(_sctpRecvBufferController.text),
      sctpRTOMax: int.parse(_sctpRTOMaxController.text),
      udpReadBuffer: int.parse(_udpReadBufferController.text),
      udpWriteBuffer: int.parse(_udpWriteBufferController.text),
      iceDisconnTimeout: int.parse(_iceDisconnTimeoutController.text),
      iceFailedTimeout: int.parse(_iceFailedTimeoutController.text),
      iceKeepalive: int.parse(_iceKeepaliveController.text),
      dtlsRetransmit: int.parse(_dtlsRetransmitController.text),
      dtlsSkipVerify: _dtlsSkipVerify,
      sctpZeroChecksum: _sctpZeroChecksum,
      disableCloseByDTLS: _disableCloseByDTLS,
      kcpMtu: int.parse(_kcpMtuController.text),
      kcpReadBufferSize: int.parse(_kcpReadBufferController.text),
      kcpWriteBufferSize: int.parse(_kcpWriteBufferController.text),
      xhttpPath: _xhttpPathController.text,
    );

    try {
      await _settingsService.saveServerSettings(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('All server settings will be reverted to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _applySettings(const ServerSettings());
    }
  }

  void _onProtocolChanged(String? value) {
    if (value == null) return;
    setState(() => _protocol = value);
  }

  void _onTransportChanged(String? value) {
    if (value == null) return;
    setState(() => _transport = value);
  }

  bool _isHolepunchSelected() => _natMethod == 'holepunch';

  String _generateUuid() => const Uuid().v4();

  String? _validatePort(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) return '1-65535';
    return null;
  }

  String? _validateHostPort(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!value.contains(':')) return 'Host:Port required';
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'http:// or https:// required';
    }
    return null;
  }

  String? _validatePositiveInt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final v = int.tryParse(value.trim());
    if (v == null || v < 0) return 'Must be >= 0';
    return null;
  }

  String? _validateUuid(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final regExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!regExp.hasMatch(value.trim())) return 'Invalid UUID format';
    return null;
  }

  @override
  void dispose() {
    _portController.dispose();
    _stunController.dispose();
    _signalingController.dispose();
    _upnpLeaseDurationController.dispose();
    _upnpRetriesController.dispose();
    _ssdpTimeoutController.dispose();
    _socksUsernameController.dispose();
    _socksPasswordController.dispose();
    _kcpMtuController.dispose();
    _kcpSndWndController.dispose();
    _kcpRcvWndController.dispose();
    _kcpReadBufferController.dispose();
    _kcpWriteBufferController.dispose();
    _xhttpPathController.dispose();
    _numPeerConnectionsController.dispose();
    _numChannelsController.dispose();
    _smuxStreamBufferController.dispose();
    _smuxSessionBufferController.dispose();
    _smuxFrameSizeController.dispose();
    _smuxKeepAliveController.dispose();
    _smuxKeepAliveTimeoutController.dispose();
    _dcMaxBufferedController.dispose();
    _dcLowMarkController.dispose();
    _paddingMaxController.dispose();
    _sctpRecvBufferController.dispose();
    _sctpRTOMaxController.dispose();
    _udpReadBufferController.dispose();
    _udpWriteBufferController.dispose();
    _iceDisconnTimeoutController.dispose();
    _iceFailedTimeoutController.dispose();
    _iceKeepaliveController.dispose();
    _dtlsRetransmitController.dispose();
    _uuidController.dispose();
    _rateLimitUpController.dispose();
    _rateLimitDownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Server Settings'),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Reset to Defaults',
                onPressed: _isLoading ? null : _resetToDefaults,
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _isLoading ? null : _saveSettings,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Network', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(labelText: 'Listen Port', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: _validatePort,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _stunController,
                          decoration: const InputDecoration(labelText: 'STUN Server', border: OutlineInputBorder()),
                          validator: _validateHostPort,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _signalingController,
                          decoration: const InputDecoration(labelText: 'Signaling Server URL', border: OutlineInputBorder()),
                          keyboardType: TextInputType.url,
                          validator: _validateUrl,
                        ),
                        const SizedBox(height: 24),
                        Text('NAT Traversal', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _natMethod,
                          decoration: const InputDecoration(labelText: 'NAT Method', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'auto', child: Text('Auto')),
                            DropdownMenuItem(value: 'upnp', child: Text('UPnP Only')),
                            DropdownMenuItem(value: 'holepunch', child: Text('Hole Punch Only (WebRTC)')),
                          ],
                          onChanged: (value) { if (value != null) setState(() => _natMethod = value); },
                        ),
                        if (_natMethod != 'holepunch') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _upnpLeaseDurationController,
                            decoration: const InputDecoration(labelText: 'Lease Duration (sec)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _upnpRetriesController,
                            decoration: const InputDecoration(labelText: 'Mapping Retries', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ssdpTimeoutController,
                            decoration: const InputDecoration(labelText: 'SSDP Timeout (sec)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (!_isHolepunchSelected()) ...[
                          Text('Protocol & Transport', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _protocol,
                            decoration: const InputDecoration(labelText: 'Protocol', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'vless', child: Text('VLESS')),
                              DropdownMenuItem(value: 'socks', child: Text('SOCKS5')),
                            ],
                            onChanged: _onProtocolChanged,
                          ),
                          if (_protocol == 'vless') ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _transport,
                              decoration: const InputDecoration(labelText: 'Transport', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'kcp', child: Text('KCP (UDP)')),
                                DropdownMenuItem(value: 'xhttp', child: Text('xHTTP (TCP)')),
                              ],
                              onChanged: _onTransportChanged,
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _uuidController,
                            decoration: InputDecoration(
                              labelText: 'UUID',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _uuidController.text = _generateUuid(),
                              ),
                            ),
                            validator: _validateUuid,
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          SwitchListTile(
                            title: const Text('UDP Relay Fallback'),
                            value: _useRelay,
                            onChanged: (value) => setState(() => _useRelay = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _transportMode,
                            decoration: const InputDecoration(labelText: 'Transport Mode', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'datachannel', child: Text('Data Channel')),
                              DropdownMenuItem(value: 'media', child: Text('Media Stream')),
                            ],
                            onChanged: (value) { if (value != null) setState(() => _transportMode = value); },
                          ),
                          const SizedBox(height: 24),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _saveSettings,
                            child: const Text('Save Server Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
