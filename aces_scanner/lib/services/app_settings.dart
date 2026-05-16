// lib/services/app_settings.dart
import 'package:hive/hive.dart';

class AppSettings {
  static const String _boxName = 'app_settings';
  static const String _apiUrlKey = 'api_url';
  static const String _defaultApiUrl = 'http://192.168.0.148:8000';

  static Box get _box => Hive.box(_boxName);

  // The box name, used in main.dart to open it
  static String get boxName => _boxName;

  // Read the API base URL (falls back to default if not set)
  static String get apiUrl {
    return _box.get(_apiUrlKey, defaultValue: _defaultApiUrl) as String;
  }

  // Full endpoint for card parsing
  static String get parseCardEndpoint => '$apiUrl/api/parse-card';

  // Save the API base URL
  static Future<void> setApiUrl(String url) async {
    // Strip trailing slash for consistency
    final cleaned = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await _box.put(_apiUrlKey, cleaned);
  }

  // Reset to defaults
  static Future<void> resetToDefaults() async {
    await _box.delete(_apiUrlKey);
  }
}