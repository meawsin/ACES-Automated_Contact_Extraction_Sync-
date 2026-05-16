// lib/screens/manual_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/scan_record.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name        = '';
  String _org         = '';
  String _designation = '';
  String _phone       = '';
  String _email       = '';
  String _telephone   = '';
  String _fax         = '';
  String _address     = '';
  String _links       = '';

  bool _isSaving = false;

  static const _navy = Color(0xFF0D1B2A);
  static const _teal = Color(0xFF00C2A8);

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    final newRecord = ScanRecord(
      name:         _name,
      organization: _org,
      designation:  _designation,
      phone:        _phone,
      email:        _email,
      telephone:    _telephone,
      fax:          _fax,
      address:      _address,
      links:        _links,
      scannedAt:    DateTime.now(),
      isSynced:     false,
    );

    final scansBox = Hive.box<ScanRecord>('scan_records');
    await scansBox.add(newRecord);

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact saved!'),
        backgroundColor: Color(0xFF00875A),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Contact',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Required', Icons.person_outline),
            const SizedBox(height: 10),
            _field(
              label:    'Full Name *',
              hint:     'e.g. Mohammed Al-Rashid',
              icon:     Icons.badge_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              onSaved:  (v) => _name = v!.trim(),
            ),
            const SizedBox(height: 12),
            _field(
              label:   'Organization',
              hint:    'Company or institution',
              icon:    Icons.business_outlined,
              onSaved: (v) => _org = v?.trim() ?? '',
            ),
            const SizedBox(height: 12),
            _field(
              label:   'Designation / Title',
              hint:    'e.g. Senior Manager',
              icon:    Icons.work_outline,
              onSaved: (v) => _designation = v?.trim() ?? '',
            ),

            const SizedBox(height: 20),
            _sectionHeader('Contact', Icons.contacts_outlined),
            const SizedBox(height: 10),

            _field(
              label:       'Mobile Number',
              hint:        '+880 1XXX-XXXXXX',
              icon:        Icons.smartphone_outlined,
              keyboardType: TextInputType.phone,
              validator:   (v) {
                if ((v == null || v.trim().isEmpty) && _email.isEmpty) {
                  return 'Enter at least a phone or email';
                }
                return null;
              },
              onSaved: (v) => _phone = v?.trim() ?? '',
            ),
            const SizedBox(height: 12),
            _field(
              label:       'Email Address',
              hint:        'name@company.com',
              icon:        Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator:   (v) {
                if (v != null && v.isNotEmpty) {
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                }
                return null;
              },
              onSaved: (v) => _email = v?.trim() ?? '',
            ),
            const SizedBox(height: 12),
            _field(
              label:       'Telephone (landline)',
              hint:        'e.g. +880-2-XXXXXXXX',
              icon:        Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onSaved:     (v) => _telephone = v?.trim() ?? '',
            ),
            const SizedBox(height: 12),
            _field(
              label:       'Fax',
              hint:        'Fax number (if any)',
              icon:        Icons.print_outlined,
              keyboardType: TextInputType.phone,
              onSaved:     (v) => _fax = v?.trim() ?? '',
            ),

            const SizedBox(height: 20),
            _sectionHeader('Additional', Icons.more_horiz),
            const SizedBox(height: 10),

            _field(
              label:    'Address',
              hint:     'Street, city, postal code',
              icon:     Icons.location_on_outlined,
              maxLines: 2,
              onSaved:  (v) => _address = v?.trim() ?? '',
            ),
            const SizedBox(height: 12),
            _field(
              label:       'Website / LinkedIn / Links',
              hint:        'https://...',
              icon:        Icons.link,
              keyboardType: TextInputType.url,
              onSaved:     (v) => _links = v?.trim() ?? '',
            ),

            const SizedBox(height: 28),
            _buildSaveButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _teal),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _teal,
                letterSpacing: 1.2)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: _teal.withValues(alpha: 0.2), thickness: 1)),
      ],
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        hintStyle: const TextStyle(color: Color(0xFFBDC8D3), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8899AA)),
      ),
      keyboardType:  keyboardType,
      maxLines:      maxLines,
      validator:     validator,
      onSaved:       onSaved,
      style:         const TextStyle(fontSize: 14, color: _navy),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined, size: 20),
        label: Text(_isSaving ? 'Saving…' : 'Save Contact',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}