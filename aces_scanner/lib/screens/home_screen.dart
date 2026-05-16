// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/scan_record.dart';
import '../services/sync_service.dart';
import 'scanner_screen.dart';
import 'manual_entry_screen.dart';
import 'settings_screen.dart';

// ── Filter options ────────────────────────────────────────────────────────────
enum CardFilter { all, pending, synced }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool       _isSyncing = false;
  bool       _isDark    = false;
  CardFilter _filter    = CardFilter.all;

  // ── Theme colours ─────────────────────────────────────────────────────────
  static const _teal        = Color(0xFF00C2A8);
  static const _navyLight   = Color(0xFF0D1B2A);
  static const _navyDark    = Color(0xFF0A1520);
  static const _bgLight     = Color(0xFFF5F7FA);
  static const _bgDark      = Color(0xFF111A24);
  static const _cardLight   = Color(0xFFFFFFFF);
  static const _cardDark    = Color(0xFF1A2634);
  static const _borderLight = Color(0xFFE4E8EF);
  static const _borderDark  = Color(0xFF243040);
  static const _textLight   = Color(0xFF0D1B2A);
  static const _textDark    = Color(0xFFE8EEF4);
  static const _subLight    = Color(0xFF6B7A8D);
  static const _subDark     = Color(0xFF8899AA);

  Color get _navy   => _isDark ? _navyDark   : _navyLight;
  Color get _bg     => _isDark ? _bgDark     : _bgLight;
  Color get _card   => _isDark ? _cardDark   : _cardLight;
  Color get _border => _isDark ? _borderDark : _borderLight;
  Color get _text   => _isDark ? _textDark   : _textLight;
  Color get _sub    => _isDark ? _subDark    : _subLight;

  // ── Sync ──────────────────────────────────────────────────────────────────
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

    if (synced == 0 && skipped == 0 && conflicts == 0 && errors == 0) {
      _snack('Everything is already up to date.', Colors.grey.shade700);
      return;
    }

    final parts = <String>[];
    if (synced    > 0) parts.add('$synced added');
    if (skipped   > 0) parts.add('$skipped up to date');
    if (conflicts > 0) parts.add('$conflicts resolved');
    if (errors    > 0) parts.add('$errors failed');

    _snack(parts.join(' · '),
        errors > 0 ? Colors.orange.shade700 : const Color(0xFF00875A));
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteRecord(ScanRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Contact',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
        content: Text(
          'Remove "${record.name}" from this device? '
          'This does not delete them from the sheet.',
          style: TextStyle(color: _sub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await record.delete();
  }

  // ── Conflict dialog ───────────────────────────────────────────────────────
  Future<void> _showConflictDialog(ScanRecord record, ConflictInfo conflict) async {
    final isDesignation = conflict.conflictType == 'designation_change';

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isDesignation ? 'Role Change Detected' : 'Company Change Detected',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: _text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.message,
                style: TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14, color: _text)),
            const SizedBox(height: 12),
            _conflictRow('Was', isDesignation
                ? conflict.existing['designation'] as String?
                : conflict.existing['organisation'] as String?),
            _conflictRow('Now', isDesignation
                ? conflict.incoming['designation'] as String?
                : conflict.incoming['organisation'] as String?),
          ],
        ),
        // BUG FIX: Both buttons are now ElevatedButton so they are equally
        // visible. The primary action is teal, the secondary is outlined.
        actions: isDesignation
            ? [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'skip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sub,
                    side: BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Keep Old'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  child: const Text('Update'),
                ),
              ]
            : [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sub,
                    side: BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Same Person'),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(label,
                style: TextStyle(
                    color: _sub, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value ?? '—',
                style: TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13, color: _text)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final box = Hive.box<ScanRecord>('scan_records');

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<ScanRecord> b, _) {
          final allScans = b.values.toList()
            ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

          final filtered = allScans.where((s) {
            if (_filter == CardFilter.synced)  return s.isSynced;
            if (_filter == CardFilter.pending) return !s.isSynced;
            return true;
          }).toList();

          final synced   = allScans.where((s) => s.isSynced).length;
          final unsynced = allScans.length - synced;

          return Column(
            children: [
              if (allScans.isNotEmpty) _buildStatsAndFilter(allScans.length, synced, unsynced),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(allScans.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildCard(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _teal, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.document_scanner, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('ACES',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(width: 5),
          const Text('Scanner',
              style: TextStyle(color: Color(0xFF607080), fontSize: 13,
                  fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        // Dark mode toggle
        IconButton(
          icon: Icon(
            _isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: Colors.white),
          tooltip: _isDark ? 'Light mode' : 'Dark mode',
          onPressed: () => setState(() => _isDark = !_isDark),
        ),
        _isSyncing
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                tooltip: 'Sync to Sheet',
                onPressed: _syncAll,
              ),
        IconButton(
          icon: const Icon(Icons.edit_note_outlined, color: Colors.white),
          tooltip: 'Add Manually',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManualEntryScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.tune_outlined, color: Colors.white),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStatsAndFilter(int total, int synced, int unsynced) {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats chips
          Row(
            children: [
              _statChip('$total', 'Total', const Color(0xFF607080)),
              const SizedBox(width: 8),
              _statChip('$synced', 'Synced', _teal),
              if (unsynced > 0) ...[
                const SizedBox(width: 8),
                _statChip('$unsynced', 'Pending', Colors.orange.shade400),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Filter tabs
          Row(
            children: [
              _filterTab('All',     CardFilter.all),
              const SizedBox(width: 8),
              _filterTab('Pending', CardFilter.pending),
              const SizedBox(width: 8),
              _filterTab('Synced',  CardFilter.synced),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.75), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _filterTab(String label, CardFilter value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _teal : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ScanRecord scan) {
    final isSynced    = scan.isSynced;
    final accentColor = isSynced ? _teal : Colors.orange.shade400;
    final initials    = _initials(scan.name);
    final time        = DateFormat('MMM d, h:mm a').format(scan.scannedAt);

    return Dismissible(
      key: ValueKey(scan.key),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Remove', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteRecord(scan);
        return false; // we handle deletion inside _deleteRecord
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: _isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _text.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: TextStyle(
                          color: _text, fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(scan.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: _text)),
                          ),
                          Text(time,
                              style: TextStyle(fontSize: 10.5, color: _sub)),
                        ],
                      ),
                      if (scan.designation?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(scan.designation!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: _teal,
                                fontWeight: FontWeight.w600)),
                      ],
                      if (scan.organization?.isNotEmpty == true) ...[
                        const SizedBox(height: 1),
                        Text(scan.organization!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: _sub)),
                      ],
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        children: [
                          if (scan.phone.isNotEmpty)
                            _miniChip(Icons.phone_outlined, scan.phone),
                          if (scan.email.isNotEmpty)
                            _miniChip(Icons.mail_outline, scan.email,
                                maxWidth: 160),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Sync icon + swipe hint
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSynced
                          ? Icons.check_circle_rounded
                          : Icons.pending_outlined,
                      color: accentColor, size: 20),
                    const SizedBox(height: 6),
                    Icon(Icons.swipe_left_outlined,
                        color: _sub.withValues(alpha: 0.4), size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text, {double? maxWidth}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _sub),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 120),
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: _sub)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.document_scanner_outlined,
                size: 38, color: _teal),
          ),
          const SizedBox(height: 18),
          Text(
            isEmpty ? 'No contacts yet' : 'No ${_filter.name} contacts',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 8),
          Text(
            isEmpty
                ? 'Tap the button below to scan your first card'
                : 'Change the filter above to see other contacts',
            style: TextStyle(fontSize: 13, color: _sub),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ScannerScreen())),
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: _teal.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.document_scanner, size: 20),
        label: const Text('Scan New Card',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}