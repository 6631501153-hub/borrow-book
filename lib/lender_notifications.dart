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
  String? _error;

  List<Map<String, dynamic>> _requests = [];
  String _lenderName = 'lender name';

  @override
  void initState() {
    super.initState();
    _fetchLenderName();
    _fetchPendingRequests();
  }

  // -------------------- Data --------------------

  Future<void> _fetchLenderName() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final row = await supabase
          .from('users')
          .select('name')
          .eq('id', uid)
          .maybeSingle();

      final name = (row?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        setState(() => _lenderName = name);
      }
    } catch (_) {
      // keep default
    }
  }

  /// Fetch pending borrow requests + asset info,
  /// then in a second query fetch all student names.
  Future<void> _fetchPendingRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1) pending requests with asset join (this was working)
      final resp = await supabase
          .from('borrow_history')
          .select(
            'id, asset_id, user_id, status, borrow_date, return_date, '
            'asset:asset!inner(name, serial_number)',
          )
          .eq('status', 'pending')
          .order('borrow_date', ascending: true);

      final list =
          List<Map<String, dynamic>>.from(resp as List<dynamic>);

      // 2) collect unique user_ids
      final uids = list
          .map((r) => r['user_id'])
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      Map<String, String> nameMap = {};
      if (uids.isNotEmpty) {
        // 3) fetch names in one go (no FK join needed)
        final userRows = await supabase
            .from('users')
            .select('id, name')
            .inFilter('id', uids);

        nameMap = {
          for (final row in userRows as List<dynamic>)
            (row['id'] as String): (row['name'] ?? '').toString(),
        };
      }

      // 4) attach student_name field to each request
      for (final r in list) {
        final uid = r['user_id'] as String?;
        r['student_name'] =
            uid == null || (nameMap[uid] ?? '').isEmpty
                ? 'Unknown'
                : nameMap[uid];
      }

      setState(() {
        _requests = list;
      });
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- APPROVE / REJECT (direct updates) ----------

  Future<void> _approve(Map<String, dynamic> row) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _showSnack('Not logged in.');
      return;
    }

    final assetId = row['asset_id'];
    if (assetId == null) {
      _showSnack('Missing asset id.');
      return;
    }

    try {
      // 1) update borrow_history
      await supabase.from('borrow_history').update({
        'status': 'approved',
        'lender_id': currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
        'rejected_reason': null,
      }).eq('id', row['id']);

      // 2) mark asset as borrowed
      await supabase
          .from('asset')
          .update({'status': 'borrowed'}).eq('id', assetId);

      await _fetchPendingRequests();
      _showSnack('Request approved.');
    } on PostgrestException catch (e) {
      _showSnack('Failed to approve: ${e.message}');
    } catch (e) {
      _showSnack('Failed to approve: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _showSnack('Not logged in.');
      return;
    }

    final assetId = row['asset_id'];
    if (assetId == null) {
      _showSnack('Missing asset id.');
      return;
    }

    // Ask for reason first
    final reason = await _askRejectReason();
    if (reason == null || reason.trim().isEmpty) {
      // cancelled or empty → do nothing
      return;
    }
    final cleanedReason = reason.trim();

    try {
      // 1) update borrow_history with status + reason
      await supabase.from('borrow_history').update({
        'status': 'rejected',
        'lender_id': currentUserId,
        'approved_at': null,
        'returned_at': null,
        'rejected_reason': cleanedReason,
      }).eq('id', row['id']);

      // 2) free up asset again
      await supabase
          .from('asset')
          .update({'status': 'available'}).eq('id', assetId);

      await _fetchPendingRequests();
      _showSnack('Request rejected.');
    } on PostgrestException catch (e) {
      _showSnack('Failed to reject: ${e.message}');
    } catch (e) {
      _showSnack('Failed to reject: $e');
    }
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Not available this week',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return '-';
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
                      fontSize: 44,
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

            // Search + Filter Row (UI only)
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
                        child: Icon(Icons.search,
                            size: 18, color: Colors.black54),
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
                    child: const Icon(Icons.filter_list,
                        size: 18, color: Colors.black87),
                  ),
                ],
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _requests.isEmpty
                          ? const Center(
                              child: Text(
                                'No pending requests.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchPendingRequests,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 2, 12, 10),
                                itemCount: _requests.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 20,
                                  thickness: 0.8,
                                  color: Colors.black87,
                                ),
                                itemBuilder: (context, i) {
                                  final r = _requests[i];

                                  final book =
                                      (r['asset']?['name'] ?? '').toString();
                                  final idText =
                                      (r['asset']?['serial_number'] ??
                                              r['asset_id'] ??
                                              'xxxxx')
                                          .toString();
                                  final borrow = _fmtDate(r['borrow_date']);
                                  final due = _fmtDate(r['return_date']);
                                  final studentName =
                                      (r['student_name'] ?? 'Unknown')
                                          .toString();

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _Cell(text: book, flex: 3, maxLines: 2),
                                      _Cell(text: idText, flex: 1),
                                      _Cell(text: borrow, flex: 2),
                                      _Cell(text: due, flex: 2),
                                      _Cell(
                                          text: studentName,
                                          flex: 2), // real student name
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
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

// ====== Cells & buttons ======

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
          style: const TextStyle(
            fontSize: 13,
            height: 1.15,
            color: Colors.black87,
          ),
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
