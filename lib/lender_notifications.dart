
// lib/lender_notifications.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Supabase client
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LenderNotificationsPage extends StatefulWidget {
  const LenderNotificationsPage({super.key});

  @override
  State<LenderNotificationsPage> createState() =>
      _LenderNotificationsPageState();
}

class _LenderNotificationsPageState extends State<LenderNotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _lenderName = 'lender name';

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
    _fetchLenderName();
  }

  // -------------------- Data --------------------

  Future<void> _fetchLenderName() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final row = await supabase
          .from('users')
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      final name = (row?['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) setState(() => _lenderName = name);
    } catch (_) {}
  }

  Future<void> _fetchPendingRequests() async {
    setState(() => _isLoading = true);
    try {
      final resp = await supabase
          .from('borrow_history')
          .select(
              'id, asset_id, status, borrow_date, return_due_date, asset:asset!inner(name)')
          .eq('status', 'pending')
          .order('borrow_date', ascending: true);
      setState(() => _requests = List<Map<String, dynamic>>.from(resp));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    try {
      await supabase
          .from('borrow_history')
          .update({
            'status': 'borrowed',
            'lender_id': supabase.auth.currentUser?.id,
          })
          .eq('id', row['id']);
      await supabase
          .from('asset')
          .update({'status': 'borrowed'}).eq('id', row['asset_id']);
      _fetchPendingRequests();
    } catch (_) {}
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    try {
      await supabase
          .from('borrow_history')
          .update({
            'status': 'rejected',
            'lender_id': supabase.auth.currentUser?.id,
          })
          .eq('id', row['id']);
      await supabase
          .from('asset')
          .update({'status': 'available'}).eq('id', row['asset_id']);
      _fetchPendingRequests();
    } catch (_) {}
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '10/01/2025';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(v));
    } catch (_) {
      return '10/01/2025';
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    const headerGrey = Color(0xFFD9D9D9);
    const pillGreen = Color(0xFF22C55E);
    const pillRed = Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 44, // smaller title
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _lenderName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Search + Filter Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E6E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.search, size: 18, color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.filter_list, size: 18, color: Colors.black87),
                  ),
                ],
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: headerGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    _HeaderCell('book name', flex: 3),
                    _HeaderCell('id', flex: 1),
                    _HeaderCell('Borrow\nDate', flex: 2),
                    _HeaderCell('Return\ndue\ndate', flex: 2),
                    _HeaderCell('Student\nName', flex: 2),
                    _HeaderCell('approve', flex: 2, alignEnd: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // List of Requests
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchPendingRequests,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                        itemCount: _requests.isEmpty ? 3 : _requests.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 20,
                          thickness: 0.8,
                          color: Colors.black87,
                        ),
                        itemBuilder: (context, i) {
                          final r = (_requests.isEmpty)
                              ? {
                                  'asset': {'name': 'mobile application Deverlopment'},
                                  'asset_id': 'xxxxx',
                                  'borrow_date': null,
                                  'return_due_date': null,
                                }
                              : _requests[i];

                          final book = (r['asset']?['name'] ?? '').toString();
                          final idText = (r['asset_id'] ?? 'xxxxx').toString();
                          final borrow = _fmtDate(r['borrow_date']);
                          final due = _fmtDate(r['return_due_date']);

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _Cell(text: book, flex: 3, maxLines: 2),
                              _Cell(text: idText, flex: 1),
                              _Cell(text: borrow, flex: 2),
                              _Cell(text: due, flex: 2),
                              const _Cell(text: 'student', flex: 2),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _Pill(
                                        label: 'approve',
                                        color: pillGreen,
                                        onTap: () => _approve(r),
                                      ),
                                      const SizedBox(height: 6),
                                      _Pill(
                                        label: 'reject',
                                        color: pillRed,
                                        onTap: () => _reject(r),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== Shrunk versions of components ======
class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final int? maxLines;
  const _Cell({required this.text, this.flex = 1, this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.15, color: Colors.black87),
          softWrap: true,
          maxLines: maxLines,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool alignEnd;
  const _HeaderCell(this.text, {this.flex = 1, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          softWrap: true,
          overflow: TextOverflow.visible,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 70,
          minHeight: 28,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}