import 'package:serverpod/serverpod.dart';

final Map<String, String> _memoryCache = {};

class SyncEndpoint extends Endpoint {
  Future<void> pushConfig(Session session, String pairingCode, String payload) async {
    _memoryCache['config_$pairingCode'] = payload;
  }

  Future<String?> getConfig(Session session, String pairingCode) async {
    return _memoryCache['config_$pairingCode'];
  }

  Future<void> pushAppList(Session session, String pairingCode, String payload) async {
    _memoryCache['apps_$pairingCode'] = payload;
  }

  Future<String?> getChildAppList(Session session, String pairingCode) async {
    return _memoryCache['apps_$pairingCode'];
  }
}
