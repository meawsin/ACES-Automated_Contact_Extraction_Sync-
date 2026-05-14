// lib/services/sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/scan_record.dart';
import 'app_settings.dart';

enum SyncResult { saved, duplicate, conflict, error }

class ConflictInfo {
  final String conflictType; // 'designation_change' or 'company_change'
  final String message;
  final Map<String, dynamic> existing;
  final Map<String, dynamic> incoming;
  final int rowNumber;
  final List<dynamic> resolvedRow;

  const ConflictInfo({
    required this.conflictType,
    required this.message,
    required this.existing,
    required this.incoming,
    required this.rowNumber,
    required this.resolvedRow,
  });
}

class SyncResponse {
  final SyncResult result;
  final String message;
  final ConflictInfo? conflict;

  const SyncResponse({
    required this.result,
    required this.message,
    this.conflict,
  });
}

class SyncService {
  static String get _syncEndpoint => '${AppSettings.apiUrl}/api/sync-contact';
  static String get _resolveEndpoint => '${AppSettings.apiUrl}/api/resolve-conflict';

  /// Attempt to sync a single ScanRecord to Excel via Laravel.
  static Future<SyncResponse> syncRecord(ScanRecord record) async {
    try {
      final response = await http.post(
        Uri.parse(_syncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name':         record.name,
          'designation':  record.designation ?? '',
          'organisation': record.organization ?? '',
          'mobile':       record.phone,
          'email':        record.email,
          'telephone':    '',
          'fax':          '',
          'address':      '',
          'links':        '',
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      final status = data['status'] as String;

      switch (status) {
        case 'saved':
          return SyncResponse(result: SyncResult.saved, message: data['message']);

        case 'duplicate':
          return SyncResponse(result: SyncResult.duplicate, message: data['message']);

        case 'conflict':
          return SyncResponse(
            result: SyncResult.conflict,
            message: data['message'],
            conflict: ConflictInfo(
              conflictType: data['conflict_type'],
              message:      data['message'],
              existing:     Map<String, dynamic>.from(data['existing']),
              incoming:     Map<String, dynamic>.from(data['incoming']),
              rowNumber:    data['row_number'],
              resolvedRow:  List<dynamic>.from(data['resolved_row']),
            ),
          );

        default:
          return SyncResponse(result: SyncResult.error, message: data['message'] ?? 'Unknown error');
      }
    } catch (e) {
      return SyncResponse(result: SyncResult.error, message: e.toString());
    }
  }

  /// Send the user's conflict resolution decision to Laravel.
  static Future<bool> resolveConflict({
    required String action, // 'update' or 'new'
    required int rowNumber,
    required List<dynamic> resolvedRow,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_resolveEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action':       action,
          'row_number':   rowNumber,
          'resolved_row': resolvedRow,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      return data['status'] == 'saved';
    } catch (e) {
      return false;
    }
  }

  /// Sync all unsynced records in the Hive box.
  /// Returns a summary: { synced, skipped, conflicts, errors }
  static Future<Map<String, int>> syncAll({
    required Function(ScanRecord record, ConflictInfo conflict) onConflict,
  }) async {
    final box = Hive.box<ScanRecord>('scan_records');
    final unsynced = box.values.where((r) => !r.isSynced).toList();

    int synced = 0, skipped = 0, conflicts = 0, errors = 0;

    for (final record in unsynced) {
      final result = await syncRecord(record);

      switch (result.result) {
        case SyncResult.saved:
          record.isSynced = true;
          await record.save();
          synced++;
          break;

        case SyncResult.duplicate:
          // Already in Excel — mark as synced so we don't keep retrying
          record.isSynced = true;
          await record.save();
          skipped++;
          break;

        case SyncResult.conflict:
          conflicts++;
          await onConflict(record, result.conflict!);
          break;

        case SyncResult.error:
          errors++;
          break;
      }
    }

    return {'synced': synced, 'skipped': skipped, 'conflicts': conflicts, 'errors': errors};
  }
}