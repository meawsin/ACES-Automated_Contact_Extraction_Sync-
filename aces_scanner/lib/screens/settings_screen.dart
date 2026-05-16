// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey        = GlobalKey<FormState>();
  late TextEditingController _apiUrlCtrl;
  bool _isSaving        = false;

  static const _navy = Color(0xFF0D1B2A);
  static const _teal = Color(0xFF00C2A8);

  @override
  void initState() {
    super.initState();
    _apiUrlCtrl = TextEditingController(text: AppSettings.apiUrl);
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await AppSettings.setApiUrl(_apiUrlCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: Color(0xFF00875A),
      ),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Settings',
            style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
        content: const Text('Reset all settings to their defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppSettings.resetToDefaults();
    if (!mounted) return;
    setState(() => _apiUrlCtrl.text = AppSettings.apiUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to defaults.')),
    );
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
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset',
                style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            _buildSectionCard(
              icon:  Icons.dns_outlined,
              title: 'Backend Configuration',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _apiUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      hintText:  'http://192.168.0.148:8080',
                      helperText: 'No trailing slash. Used for all API calls.',
                      prefixIcon: const Icon(Icons.link, size: 18,
                          color: Color(0xFF8899AA)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18,
                            color: Color(0xFF8899AA)),
                        onPressed: () => _apiUrlCtrl.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect:  false,
                    style: const TextStyle(fontSize: 14, color: _navy),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'URL is required';
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'Include http:// or https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder(
                    valueListenable: _apiUrlCtrl,
                    builder: (_, _, _) {
                      final url      = _apiUrlCtrl.text.trim();
                      final endpoint = url.isEmpty ? '…' : '$url/api/parse-card';
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _teal.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.api_outlined, size: 14, color: _teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                endpoint,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _teal,
                                    fontFamily: 'monospace'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isSaving ? 'Saving…' : 'Save Settings',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionCard(
              icon:  Icons.info_outline,
              title: 'Network Note',
              child: Text(
                'Your device and the Laravel server must be on the same Wi-Fi network. '
                'For production, use a public HTTPS URL.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
              ),
            ),

            const SizedBox(height: 16),

            // App version info
            Center(
              child: Text(
                'ACES Scanner v1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String   title,
    required Widget   child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: _teal),
              const SizedBox(width: 6),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}