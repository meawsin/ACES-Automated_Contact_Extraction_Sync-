// lib/models/scan_record.dart
import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 0)
class ScanRecord extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String organization;

  @HiveField(2)
  final String designation;

  @HiveField(3)
  final DateTime scannedAt;

  @HiveField(4)
  final bool isSynced;

  ScanRecord({
    required this.name,
    required this.organization,
    required this.designation,
    required this.scannedAt,
    this.isSynced = true,
  });
}