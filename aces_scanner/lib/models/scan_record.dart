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

  @HiveField(5)
  String phone;

  @HiveField(6)
  String email;

  // BUG FIX: Added missing fields that Gemini extracts but were previously discarded.
  // These are appended as new HiveFields (7–10) so existing Hive data is not broken.
  @HiveField(7)
  String telephone;

  @HiveField(8)
  String fax;

  @HiveField(9)
  String address;

  @HiveField(10)
  String links;

  ScanRecord({
    required this.name,
    required this.organization,
    required this.designation,
    required this.scannedAt,
    this.isSynced = false,
    this.phone = '',
    this.email = '',
    this.telephone = '',
    this.fax = '',
    this.address = '',
    this.links = '',
  });
}