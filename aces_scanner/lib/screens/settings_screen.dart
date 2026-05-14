// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: AppSettings.apiUrl);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await AppSettings.setApiUrl(_apiUrlController.text.trim());

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Reset all settings to their defaults?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AppSettings.resetToDefaults();
    if (!mounted) return;
    setState(() {
      _apiUrlController.text = AppSettings.apiUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to defaults.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section: Backend ───────────────────────────────────────
              const Text(
                'Backend Configuration',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://192.168.0.148:8000',
                  helperText: 'No trailing slash. Used for all API calls.',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.dns_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                    onPressed: () => _apiUrlController.clear(),
                  ),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'URL is required';
                  final uri = Uri.tryParse(val.trim());
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL (include http:// or https://)';
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Live preview of the full endpoint
              ValueListenableBuilder(
                valueListenable: _apiUrlController,
                builder: (context, _, __) {
                  final url = _apiUrlController.text.trim();
                  final endpoint = url.isEmpty ? '...' : '$url/api/parse-card';
                  return Text(
                    'Parse endpoint: $endpoint',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Save Button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Info Card ──────────────────────────────────────────────
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Make sure your device and the Laravel server are on the same network. '
                          'For production, use your server\'s public URL with https://.',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}