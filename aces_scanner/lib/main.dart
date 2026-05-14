// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/scan_record.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local Hive database
  await Hive.initFlutter();
  Hive.registerAdapter(ScanRecordAdapter());
  await Hive.openBox<ScanRecord>('scansBox');

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