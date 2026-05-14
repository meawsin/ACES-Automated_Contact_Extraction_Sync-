import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 0)
class ScanRecord extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String? organization;

  @HiveField(2)
  String? designation;

  @HiveField(3)
  DateTime scannedAt;

  @HiveField(4)
  bool isSynced;

  // --- NEW FIELDS ---
  @HiveField(5)
  String phone;

  @HiveField(6)
  String email;

  ScanRecord({
    required this.name,
    required this.organization,
    required this.designation,
    required this.scannedAt,
    this.isSynced = false,
    this.phone = '',
    this.email = '',
  });
}