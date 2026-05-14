// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_record.dart';
import 'package:intl/intl.dart'; // Add 'intl' to pubspec for date formatting
import 'scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<ScanRecord> scansBox = Hive.box<ScanRecord>('scansBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACES Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings to update Laravel API URL
            },
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

          // Convert to list and sort by newest first
          List<ScanRecord> recentScans = box.values.toList()
            ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

          return ListView.builder(
            itemCount: recentScans.length,
            padding: const EdgeInsets.only(bottom: 80), // Padding for the FAB
            itemBuilder: (context, index) {
              final scan = recentScans[index];
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
                    '${scan.name} - ${scan.designation}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${scan.organization} • $timeFormatted'),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );
        },
        icon: const Icon(Icons.document_scanner),
        label: const Text(
          'Scan New Card',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}