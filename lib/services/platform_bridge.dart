import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  static const _channel = MethodChannel('com.p2pshare/vpn');
  static const _statusChannel = EventChannel('com.p2pshare/status');

  /// Resolves localhost URLs to device IP address for Termux compatibility.
  static Future<String> resolveSignalingUrl(String url) async {
    if (url.isEmpty) return url;
    
    try {
      final uri = Uri.parse(url);
      
      // Only translate localhost/127.0.0.1
      if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
        return url;
      }
      
      // Get device's local IP address
      final deviceIp = await _channel.invokeMethod<String>('getLocalIpAddress');
      if (deviceIp != null && deviceIp.isNotEmpty && deviceIp != '127.0.0.1') {
        final newUri = uri.replace(host: deviceIp);
        final resolved = newUri.toString();
        debugPrint('PlatformBridge: Resolved localhost URL: $url → $resolved');
        return resolved;
      }
    } catch (e) {
      debugPrint('PlatformBridge: Failed to resolve localhost URL: $e');
    }
    
    return url;
  }

  /// Resolves all signaling URLs in settings JSON
  static Future<Map<String, dynamic>> resolveSettingsUrls(
    Map<String, dynamic> settings,
  ) async {
    final resolved = Map<String, dynamic>.from(settings);
    
    if (resolved['signalingUrl'] is String) {
      resolved['signalingUrl'] = await resolveSignalingUrl(
        resolved['signalingUrl'] as String,
      );
    }
    
    if (resolved['discoveryUrl'] is String) {
      resolved['discoveryUrl'] = await resolveSignalingUrl(
        resolved['discoveryUrl'] as String,
      );
    }
    
    return resolved;
  }

  static Future<bool> requestVpnPermission() async {
    return await _channel.invokeMethod<bool>('requestVpnPermission') ?? false;
  }

  static Future<bool> requestBatteryOptimization() async {
    return await _channel.invokeMethod<bool>('requestBatteryOptimization') ??
        false;
  }

  static Future<String> getLocalIpAddress() async {
    final result = await _channel.invokeMethod<String>('getLocalIpAddress');
    return result ?? '127.0.0.1';
  }

  static Future<String> startServer(String settingsJson) async {
    final result = await _channel.invokeMethod<String>('startServer', {
      'settings': settingsJson,
    });
    if (result == null) {
      debugPrint('PlatformBridge: startServer returned null');
    }
    return result ?? '';
  }

  // Legacy mode: starts VPN service which handles the full connection
  // (used for UPnP / direct xray-core connections).
  static Future<void> startClient(
    String connectionCode,
    String settingsJson,
  ) async {
    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      final resolved = await resolveSettingsUrls(settings);
      final resolvedJson = jsonEncode(resolved);
      
      await _channel.invokeMethod('startClient', {
        'code': connectionCode,
        'settings': resolvedJson,
      });
    } catch (e) {
      debugPrint('PlatformBridge: startClient error: $e');
      rethrow;
    }
  }

  // Phase 1: connect WebRTC before the TUN is up. Throws on failure.
  static Future<void> connectWebRTC(
    String connectionCode,
    String settingsJson,
  ) async {
    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      final resolved = await resolveSettingsUrls(settings);
      final resolvedJson = jsonEncode(resolved);
      
      await _channel.invokeMethod('connectWebRTC', {
        'code': connectionCode,
        'settings': resolvedJson,
      });
    } catch (e) {
      debugPrint('PlatformBridge: connectWebRTC error: $e');
      rethrow;
    }
  }

  // Phase 2: WebRTC is up, now bring the TUN online. Call after connectWebRTC.
  static Future<void> startVpn(String settingsJson) async {
    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      final resolved = await resolveSettingsUrls(settings);
      final resolvedJson = jsonEncode(resolved);
      
      await _channel.invokeMethod('startVpn', {
        'settings': resolvedJson,
      });
    } catch (e) {
      debugPrint('PlatformBridge: startVpn error: $e');
      rethrow;
    }
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  static Future<String> getServerStatus() async {
    final result = await _channel.invokeMethod<String>('getServerStatus');
    if (result == null) {
      debugPrint('PlatformBridge: getServerStatus returned null');
    }
    return result ?? '{}';
  }

  static Future<String> getClientStatus() async {
    final result = await _channel.invokeMethod<String>('getClientStatus');
    if (result == null) {
      debugPrint('PlatformBridge: getClientStatus returned null');
    }
    return result ?? '{}';
  }

  static Future<String> detectNatType() async {
    final result = await _channel.invokeMethod<String>('detectNatType');
    if (result == null) {
      debugPrint('PlatformBridge: detectNatType returned null');
    }
    return result ?? 'unknown';
  }

  static Future<String> getLogs(int cursor) async {
    final result = await _channel.invokeMethod<String>('getLogs', {
      'cursor': cursor,
    });
    return result ?? '{"c":0,"e":[]}';
  }

  static Future<void> clearLogs() async {
    await _channel.invokeMethod('clearLogs');
  }

  static Future<String> testLatency() async {
    final result = await _channel.invokeMethod<String>('testLatency');
    if (result == null) {
      debugPrint('PlatformBridge: testLatency returned null');
    }
    return result ?? '{"error": "no response"}';
  }

  static Future<String> listServers(
    String discoveryUrl,
    String room,
  ) async {
    final result = await _channel.invokeMethod<String>('listServers', {
      'discoveryUrl': discoveryUrl,
      'room': room,
    });
    if (result == null) {
      debugPrint('PlatformBridge: listServers returned null');
    }
    return result ?? '[]';
  }

  static Future<String> registerDiscovery(
    String code,
    String settingsJson,
  ) async {
    final result = await _channel.invokeMethod<String>('registerDiscovery', {
      'code': code,
      'settings': settingsJson,
    });
    if (result == null) {
      debugPrint('PlatformBridge: registerDiscovery returned null');
    }
    return result ?? '';
  }

  static Future<void> unregisterDiscovery() async {
    await _channel.invokeMethod('unregisterDiscovery');
  }

  // Manual signaling

  static Future<String> startServerManual(String settingsJson) async {
    final result = await _channel.invokeMethod<String>('startServerManual', {
      'settings': settingsJson,
    });
    return result ?? '';
  }

  static Future<void> acceptManualAnswer(String answerCode) async {
    await _channel.invokeMethod('acceptManualAnswer', {
      'answerCode': answerCode,
    });
  }

  static Future<String> processManualOffer(
    String offerCode,
    String settingsJson,
  ) async {
    final result = await _channel.invokeMethod<String>('processManualOffer', {
      'offerCode': offerCode,
      'settings': settingsJson,
    });
    return result ?? '';
  }

  static Future<void> waitManualConnection(int timeoutSec) async {
    await _channel.invokeMethod('waitManualConnection', {
      'timeout': timeoutSec,
    });
  }

  static Stream<Map<String, dynamic>> get statusStream {
    return _statusChannel.receiveBroadcastStream().map(
      (e) => Map<String, dynamic>.from(e as Map),
    );
  }
}
