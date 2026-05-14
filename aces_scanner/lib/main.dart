// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/scan_record.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 1. Register adapters FIRST, before opening any box
  Hive.registerAdapter(ScanRecordAdapter());

  // 2. Open the typed box ONCE
  try {
    await Hive.openBox<ScanRecord>('scan_records');
  } catch (e) {
    print('Error opening Hive box: $e');
    await Hive.deleteBoxFromDisk('scan_records');
    await Hive.openBox<ScanRecord>('scan_records');
  }

  runApp(const ACESApp());
}

class ACESApp extends StatelessWidget {
  const ACESApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACES Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Modern UI components
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}