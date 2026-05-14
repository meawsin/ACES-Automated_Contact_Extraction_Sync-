// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/scan_record.dart';
import '../services/sync_service.dart';
import 'scanner_screen.dart';
import 'manual_entry_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;

  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);

    final summary = await SyncService.syncAll(
      onConflict: (record, conflict) async {
        if (!mounted) return;
        await _showConflictDialog(record, conflict);
      },
    );

    if (!mounted) return;
    setState(() => _isSyncing = false);

    final synced    = summary['synced']!;
    final skipped   = summary['skipped']!;
    final conflicts = summary['conflicts']!;
    final errors    = summary['errors']!;

    String msg;
    Color color;

    if (synced == 0 && skipped == 0 && conflicts == 0 && errors == 0) {
      msg   = 'Nothing to sync — all records are up to date.';
      color = Colors.grey;
    } else {
      final parts = <String>[];
      if (synced > 0)    parts.add('$synced synced');
      if (skipped > 0)   parts.add('$skipped already in Excel');
      if (conflicts > 0) parts.add('$conflicts resolved');
      if (errors > 0)    parts.add('$errors failed');
      msg   = parts.join(', ');
      color = errors > 0 ? Colors.orange : Colors.green;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _showConflictDialog(ScanRecord record, ConflictInfo conflict) async {
    final isDesignation = conflict.conflictType == 'designation_change';

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isDesignation ? 'Role Change Detected' : 'Company Change Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.message, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _conflictRow('Was', isDesignation
                ? conflict.existing['designation']
                : conflict.existing['organisation']),
            _conflictRow('Now', isDesignation
                ? conflict.incoming['designation']
                : conflict.incoming['organisation']),
          ],
        ),
        actions: isDesignation
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'skip'),
                  child: const Text('Keep Old'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  child: const Text('Update'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  child: const Text('Same Person — Update'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'new'),
                  child: const Text('New Entry'),
                ),
              ],
      ),
    );

    if (action == null || action == 'skip') return;

    final success = await SyncService.resolveConflict(
      action:      action,
      rowNumber:   conflict.rowNumber,
      resolvedRow: conflict.resolvedRow,
    );

    if (success) {
      record.isSynced = true;
      await record.save();
    }
  }

  Widget _conflictRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Box<ScanRecord> scansBox = Hive.box<ScanRecord>('scan_records');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACES'),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  tooltip: 'Sync to Excel',
                  onPressed: _syncAll,
                ),
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: 'Add Manually',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: scansBox.listenable(),
        builder: (context, Box<ScanRecord> box, _) {
          if (box.values.isEmpty) {
            return const Center(
              child: Text(
                'No recent scans.\nTap below to start!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final recentScans = box.values.toList()
            ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

          return ListView.builder(
            itemCount: recentScans.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final scan          = recentScans[index];
              final timeFormatted = DateFormat('MMM d, h:mm a').format(scan.scannedAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    '${scan.name} - ${scan.designation ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${scan.organization ?? ''} • $timeFormatted'),
                        const SizedBox(height: 4),
                        Text('📞 ${scan.phone}',  style: const TextStyle(fontSize: 12)),
                        Text('✉️ ${scan.email}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  trailing: Icon(
                    scan.isSynced ? Icons.check_circle : Icons.sync_problem,
                    color: scan.isSynced ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        icon:            const Icon(Icons.document_scanner),
        label:           const Text('Scan New Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}