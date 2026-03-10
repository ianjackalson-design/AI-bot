import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ServerInfo {
  final String ipAddress;
  final int port;
  final String name;

  ServerInfo({
    required this.ipAddress,
    required this.port,
    required this.name,
  });

  String get url => 'http://$ipAddress:$port';

  @override
  String toString() => '
  String toString() => '$name ($ipAddress:$port)';
}

class DiscoveryService extends ChangeNotifier {
  List<ServerInfo> _discoveredServers = [];
  ServerInfo? _selectedServer;
  bool _isScanning = false;

  List<ServerInfo> get discoveredServers => _discoveredServers;
  ServerInfo? get selectedServer => _selectedServer;
  bool get isScanning => _isScanning;

  /// Start local network discovery (LAN broadcast scan)
  Future<void> startDiscovery({int timeoutSeconds = 5}) async {
    _isScanning = true;
    _discoveredServers = [];
    notifyListeners();

    try {
      // Get local IP address
      final localIp = await _getLocalIpAddress();
      if (localIp == null) {
        throw Exception('Could not determine local IP address');
      }

      // Extract subnet (e.g., 192.168.1 from 192.168.1.100)
      final subnet = localIp.substring(0, localIp.lastIndexOf('.'));

      // Scan subnet IPs in parallel
      final futures = <Future<void>>[];
      for (int i = 1; i <= 254; i++) {
        final ip = '$subnet.$i';
        if (ip != localIp) {
          futures.add(_checkServer(ip));
        }
      }

      // Wait for all checks with timeout
      await Future.wait(futures, eagerError: false).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => debugPrint('Discovery scan timeout'),
      );
    } catch (e) {
      debugPrint('Error during discovery: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Check if a specific IP has the AI-Bot server
  Future<void> _checkServer(String ip) async {
    try {
      final apiService = ApiService('http://$ip:8000');
      final isHealthy = await apiService.healthCheck();
      
      if (isHealthy) {
        final serverInfo = ServerInfo(
          ipAddress: ip,
          port: 8000,
          name: 'AI-Bot Server',
        );
        _discoveredServers.add(serverInfo);
        notifyListeners();
      }
    } catch (e) {
      // Server not responding, skip
    }
  }

  /// Get local IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          // Get IPv4 address that's not loopback
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  /// Manually add server with IP and port
  void addManualServer({
    required String ipAddress,
    int port = 8000,
    String name = 'AI-Bot Server',
  }) {
    final serverInfo = ServerInfo(
      ipAddress: ipAddress,
      port: port,
      name: name,
    );
    _discoveredServers.add(serverInfo);
    notifyListeners();
  }

  /// Select server for connection
  void selectServer(ServerInfo server) {
    _selectedServer = server;
    notifyListeners();
  }

  /// Clear discovered servers
  void clearServers() {
    _discoveredServers = [];
    _selectedServer = null;
    notifyListeners();
  }

  /// Verify server connection
  Future<bool> verifyServer(ServerInfo server) async {
    try {
      final apiService = ApiService(server.url);
      return await apiService.healthCheck();
    } catch (e) {
      debugPrint('Error verifying server: $e');
      return false;
    }
  }
}