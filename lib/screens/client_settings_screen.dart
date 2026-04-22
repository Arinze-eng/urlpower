import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isLoading = true;

  late TextEditingController _socksPortController;
  late TextEditingController _tunAddressController;
  late TextEditingController _mtuController;
  late TextEditingController _dns1Controller;
  late TextEditingController _dns2Controller;
  late TextEditingController _stunController;
  late TextEditingController _signalingController;
  late TextEditingController _discoveryUrlController;
  late TextEditingController _roomFilterController;
  late TextEditingController _sctpRecvBufferController;
  late TextEditingController _sctpRTOMaxController;
  late TextEditingController _udpReadBufferController;
  late TextEditingController _udpWriteBufferController;
  late TextEditingController _iceDisconnTimeoutController;
  late TextEditingController _iceFailedTimeoutController;
  late TextEditingController _iceKeepaliveController;
  late TextEditingController _dtlsRetransmitController;

  bool _discoveryEnabled = true;
  bool _dtlsSkipVerify = false;
  bool _sctpZeroChecksum = false;
  bool _disableCloseByDTLS = false;
  bool _allowDirectDNS = false;
  bool _maskIPs = false;

  @override
  void initState() {
    super.initState();
    _socksPortController = TextEditingController();
    _tunAddressController = TextEditingController();
    _mtuController = TextEditingController();
    _dns1Controller = TextEditingController();
    _dns2Controller = TextEditingController();
    _stunController = TextEditingController();
    _signalingController = TextEditingController();
    _discoveryUrlController = TextEditingController();

    _roomFilterController = TextEditingController();
    _sctpRecvBufferController = TextEditingController();
    _sctpRTOMaxController = TextEditingController();
    _udpReadBufferController = TextEditingController();
    _udpWriteBufferController = TextEditingController();
    _iceDisconnTimeoutController = TextEditingController();
    _iceFailedTimeoutController = TextEditingController();
    _iceKeepaliveController = TextEditingController();
    _dtlsRetransmitController = TextEditingController();
    _loadSettings();
  }

  void _applySettings(ClientSettings settings) {
    setState(() {
      _socksPortController.text = settings.socksPort.toString();
      _tunAddressController.text = settings.tunAddress;
      _mtuController.text = settings.mtu.toString();
      _dns1Controller.text = settings.dns1;
      _dns2Controller.text = settings.dns2;
      _stunController.text = settings.stunServer;
      _signalingController.text = settings.signalingUrl;
      _discoveryUrlController.text = settings.discoveryUrl;

      _discoveryEnabled = settings.discoveryEnabled;
      _roomFilterController.text = settings.roomFilter;
      _sctpRecvBufferController.text = settings.sctpRecvBuffer.toString();
      _sctpRTOMaxController.text = settings.sctpRTOMax.toString();
      _udpReadBufferController.text = settings.udpReadBuffer.toString();
      _udpWriteBufferController.text = settings.udpWriteBuffer.toString();
      _iceDisconnTimeoutController.text = settings.iceDisconnTimeout.toString();
      _iceFailedTimeoutController.text = settings.iceFailedTimeout.toString();
      _iceKeepaliveController.text = settings.iceKeepalive.toString();
      _dtlsRetransmitController.text = settings.dtlsRetransmit.toString();
      _dtlsSkipVerify = settings.dtlsSkipVerify;
      _sctpZeroChecksum = settings.sctpZeroChecksum;
      _disableCloseByDTLS = settings.disableCloseByDTLS;
      _allowDirectDNS = settings.allowDirectDNS;
      _maskIPs = settings.maskIPs;
    });
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('All client settings will be reverted to their default values. This does not save automatically.'),
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
      _applySettings(const ClientSettings());
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.loadClientSettings();
      if (!mounted) return;
      _applySettings(settings);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('ClientSettingsScreen: loadSettings error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = ClientSettings(
      socksPort: int.parse(_socksPortController.text.trim()),
      tunAddress: _tunAddressController.text.trim(),
      mtu: int.parse(_mtuController.text.trim()),
      dns1: _dns1Controller.text.trim(),
      dns2: _dns2Controller.text.trim(),
      stunServer: _stunController.text.trim(),
      signalingUrl: _signalingController.text.trim(),
      discoveryUrl: _discoveryUrlController.text.trim(),
      discoveryEnabled: _discoveryEnabled,
      roomFilter: _roomFilterController.text.trim(),
      sctpRecvBuffer: int.parse(_sctpRecvBufferController.text.trim()),
      sctpRTOMax: int.parse(_sctpRTOMaxController.text.trim()),
      udpReadBuffer: int.parse(_udpReadBufferController.text.trim()),
      udpWriteBuffer: int.parse(_udpWriteBufferController.text.trim()),
      iceDisconnTimeout: int.parse(_iceDisconnTimeoutController.text.trim()),
      iceFailedTimeout: int.parse(_iceFailedTimeoutController.text.trim()),
      iceKeepalive: int.parse(_iceKeepaliveController.text.trim()),
      dtlsRetransmit: int.parse(_dtlsRetransmitController.text.trim()),
      dtlsSkipVerify: _dtlsSkipVerify,
      sctpZeroChecksum: _sctpZeroChecksum,
      disableCloseByDTLS: _disableCloseByDTLS,
      allowDirectDNS: _allowDirectDNS,
      maskIPs: _maskIPs,
    );

    try {
      await _settingsService.saveClientSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  void dispose() {
    _socksPortController.dispose();
    _tunAddressController.dispose();
    _mtuController.dispose();
    _dns1Controller.dispose();
    _dns2Controller.dispose();
    _stunController.dispose();
    _signalingController.dispose();
    _discoveryUrlController.dispose();
    _roomFilterController.dispose();
    _sctpRecvBufferController.dispose();
    _sctpRTOMaxController.dispose();
    _udpReadBufferController.dispose();
    _udpWriteBufferController.dispose();
    _iceDisconnTimeoutController.dispose();
    _iceFailedTimeoutController.dispose();
    _iceKeepaliveController.dispose();
    _dtlsRetransmitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Client Settings'),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                onPressed: _resetToDefaults,
                tooltip: 'Reset to Defaults',
              ),
            ],
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _socksPortController,
                    decoration: const InputDecoration(labelText: 'SOCKS Port'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _tunAddressController,
                    decoration: const InputDecoration(labelText: 'TUN Address'),
                  ),
                  TextFormField(
                    controller: _mtuController,
                    decoration: const InputDecoration(labelText: 'MTU'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _dns1Controller,
                    decoration: const InputDecoration(labelText: 'DNS 1'),
                  ),
                  TextFormField(
                    controller: _dns2Controller,
                    decoration: const InputDecoration(labelText: 'DNS 2'),
                  ),
                  TextFormField(
                    controller: _stunController,
                    decoration: const InputDecoration(labelText: 'STUN Server'),
                  ),
                  TextFormField(
                    controller: _signalingController,
                    decoration: const InputDecoration(labelText: 'Signaling URL'),
                  ),
                  TextFormField(
                    controller: _discoveryUrlController,
                    decoration: const InputDecoration(labelText: 'Discovery URL'),
                  ),
                  SwitchListTile(
                    title: const Text('Discovery Enabled'),
                    value: _discoveryEnabled,
                    onChanged: (val) => setState(() => _discoveryEnabled = val),
                  ),
                  TextFormField(
                    controller: _roomFilterController,
                    decoration: const InputDecoration(labelText: 'Room Filter'),
                  ),
                  const Divider(),
                  const Text('Advanced Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    controller: _sctpRecvBufferController,
                    decoration: const InputDecoration(labelText: 'SCTP Recv Buffer'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _sctpRTOMaxController,
                    decoration: const InputDecoration(labelText: 'SCTP RTO Max'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _udpReadBufferController,
                    decoration: const InputDecoration(labelText: 'UDP Read Buffer'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _udpWriteBufferController,
                    decoration: const InputDecoration(labelText: 'UDP Write Buffer'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _iceDisconnTimeoutController,
                    decoration: const InputDecoration(labelText: 'ICE Disconnect Timeout'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _iceFailedTimeoutController,
                    decoration: const InputDecoration(labelText: 'ICE Failed Timeout'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _iceKeepaliveController,
                    decoration: const InputDecoration(labelText: 'ICE Keepalive'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _dtlsRetransmitController,
                    decoration: const InputDecoration(labelText: 'DTLS Retransmit'),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    title: const Text('DTLS Skip Verify'),
                    value: _dtlsSkipVerify,
                    onChanged: (val) => setState(() => _dtlsSkipVerify = val),
                  ),
                  SwitchListTile(
                    title: const Text('SCTP Zero Checksum'),
                    value: _sctpZeroChecksum,
                    onChanged: (val) => setState(() => _sctpZeroChecksum = val),
                  ),
                  SwitchListTile(
                    title: const Text('Disable Close by DTLS'),
                    value: _disableCloseByDTLS,
                    onChanged: (val) => setState(() => _disableCloseByDTLS = val),
                  ),
                  SwitchListTile(
                    title: const Text('Allow Direct DNS'),
                    value: _allowDirectDNS,
                    onChanged: (val) => setState(() => _allowDirectDNS = val),
                  ),
                  SwitchListTile(
                    title: const Text('Mask IPs'),
                    value: _maskIPs,
                    onChanged: (val) => setState(() => _maskIPs = val),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saveSettings,
                      child: const Text('Save'),
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
