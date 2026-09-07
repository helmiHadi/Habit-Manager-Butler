import 'dart:async';
import 'dart:convert';
import 'package:butler_backend_client/butler_backend_client.dart';

class CloudSyncService {
  final Client client;

  CloudSyncService(this.client);

  Future<void> pushConfigToCloud(Map<String, dynamic> config, String pairingCode) async {
    try {
      final jsonPayload = jsonEncode(config);
      await client.sync.pushConfig(pairingCode, jsonPayload);
      print('=== ☁️ CLOUD SYNC (PARENT): Fast-Poll config pushed successfully ===');
    } catch (e) {
      print('=== ☁️ CLOUD SYNC (PARENT Error): Failed to push config: $e ===');
    }
  }

  // Top-level payload diff-check state.
  // Stores the raw JSON string of the last payload that was actually yielded.
  // Declared at instance level so it persists across loop iterations.
  String? _lastRawPayload;

  Stream<Map<String, dynamic>> listenToCloudConfig(String pairingCode) async* {
    print('=== ☁️ CLOUD SYNC (CHILD): Started fast-polling on channel $pairingCode ===');

    while (true) {
      try {
        final payload = await client.sync.getConfig(pairingCode);

        if (payload != null) {
          // ── TOP-LEVEL DIFF CHECK ──────────────────────────────────────────
          // Compare the raw JSON string BEFORE deserialising.
          // If the server returned the exact same blob as last time, skip
          // everything: no jsonDecode, no yield, no "Config arrived" log,
          // no notifyListeners() downstream.
          if (payload == _lastRawPayload) {
            // Identical payload — silent skip, no logging.
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          // Payload changed — update cache and propagate downstream.
          _lastRawPayload = payload;
          final config = jsonDecode(payload) as Map<String, dynamic>;
          yield config;
        }
      } catch (e) {
        print('=== ☁️ CLOUD SYNC (CHILD Warning): Network drop during poll: $e ===');
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> pushAppListToCloud(List<Map<String, dynamic>> apps, String pairingCode) async {
    try {
      final jsonPayload = jsonEncode(apps);
      await client.sync.pushAppList(pairingCode, jsonPayload);
      print('=== ☁️ CLOUD SYNC (CHILD): App list pushed successfully ===');
    } catch (e) {
      print('=== ☁️ CLOUD SYNC (CHILD Error): Failed to push app list: $e ===');
    }
  }

  Future<String?> getChildAppList(String pairingCode) async {
    try {
      return await client.sync.getChildAppList(pairingCode);
    } catch (e) {
      print('=== ☁️ CLOUD SYNC (PARENT Error): Failed to get child app list: $e ===');
      return null;
    }
  }

  /// Retrieves the last config JSON saved for this pairing code so the Parent
  /// dashboard can restore previously set limits (fixes "Parent Amnesia").
  Future<String?> getCloudConfig(String pairingCode) async {
    try {
      return await client.sync.getConfig(pairingCode);
    } catch (e) {
      print('=== ☁️ CLOUD SYNC (PARENT Error): Failed to fetch saved config: $e ===');
      return null;
    }
  }
}
