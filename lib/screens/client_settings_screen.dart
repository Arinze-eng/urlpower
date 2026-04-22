import 'package:flutter/material.dart';
import 'package:natproxy/models/settings_model.dart';
import 'package:natproxy/services/settings_service.dart';
import 'package:natproxy/widgets/app_background.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();

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

  bool _isLoading = true;
  bool _allowDirectDNS = false;
  bool _maskIPs = false;
  bool _discoveryEnabled = false;
  bool _dtlsSkipVerify = false;
  bool _sctpZeroChecksum = false;
  bool _disableCloseByDTLS = false;

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

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.loadClientSettings();
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

  void _applySettings(ClientSettings s) {
    _socksPortController.text = s.socksPort.toString();
    _tunAddressController.text = s.tunAddress;
    _mtuController.text = s.mtu.toString();
    _dns1Controller.text = s.dns1;
    _dns2Controller.text = s.dns2;
    _allowDirectDNS = s.allowDirectDNS;
    _stunController.text = s.stunServer;
    _signalingController.text = s.signalingUrl;
    _maskIPs = s.maskIPs;
    _discoveryUrlController.text = s.discoveryUrl;
    _discoveryEnabled = s.discoveryEnabled;
    _roomFilterController.text = s.roomFilter;
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
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final s = ClientSettings(
      socksPort: int.parse(_socksPortController.text),
      tunAddress: _tunAddressController.text,
      mtu: int.parse(_mtuController.text),
      dns1: _dns1Controller.text,
      dns2: _dns2Controller.text,
      allowDirectDNS: _allowDirectDNS,
      stunServer: _stunController.text,
      signalingUrl: _signalingController.text,
      maskIPs: _maskIPs,
      discoveryUrl: _discoveryUrlController.text,
      discoveryEnabled: _discoveryEnabled,
      roomFilter: _roomFilterController.text,
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
    );

    try {
      await _settingsService.saveClientSettings(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client settings saved.')),
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
        content: const Text('All client settings will be reverted to their default values.'),
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

  String? _validatePort(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) return '1-65535';
    return null;
  }

  String? _validateIpv4(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final regExp = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$');
    if (!regExp.hasMatch(value.trim())) return 'Invalid IPv4';
    return null;
  }

  String? _validateMtu(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final mtu = int.tryParse(value.trim());
    if (mtu == null || mtu < 576 || mtu > 1500) return '576-1500';
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
    return Scaffold(
      body: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Client Settings'),
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
                        Text('Proxy', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _socksPortController,
                          decoration: const InputDecoration(
                            labelText: 'SOCKS Proxy Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validatePort,
                        ),
                        const SizedBox(height: 24),
                        Text('VPN', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tunAddressController,
                          decoration: const InputDecoration(
                            labelText: 'TUN Address',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateIpv4,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _mtuController,
                          decoration: const InputDecoration(
                            labelText: 'MTU',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateMtu,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dns1Controller,
                          decoration: const InputDecoration(
                            labelText: 'DNS Server 1',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateIpv4,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dns2Controller,
                          decoration: const InputDecoration(
                            labelText: 'DNS Server 2',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateIpv4,
                        ),
                        SwitchListTile(
                          title: const Text('Allow Direct DNS Fallback'),
                          value: _allowDirectDNS,
                          onChanged: (value) => setState(() => _allowDirectDNS = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),
                        Text('Network', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _stunController,
                          decoration: const InputDecoration(
                            labelText: 'STUN Server',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateHostPort,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _signalingController,
                          decoration: const InputDecoration(
                            labelText: 'Signaling Server URL',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                          validator: _validateUrl,
                        ),
                        const SizedBox(height: 24),
                        Text('Logging', style: Theme.of(context).textTheme.titleMedium),
                        SwitchListTile(
                          title: const Text('Mask IP Addresses in Logs'),
                          value: _maskIPs,
                          onChanged: (value) => setState(() => _maskIPs = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),
                        Text('Server Discovery', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _discoveryUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Discovery Server URL',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                          validator: _validateUrl,
                        ),
                        SwitchListTile(
                          title: const Text('Browse available servers'),
                          value: _discoveryEnabled,
                          onChanged: (value) => setState(() => _discoveryEnabled = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _roomFilterController,
                          decoration: const InputDecoration(
                            labelText: 'Room filter',
                            border: OutlineInputBorder(),
                          ),
                          enabled: _discoveryEnabled,
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
