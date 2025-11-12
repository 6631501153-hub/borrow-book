// lib/student_history.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:intl/intl.dart';

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({super.key});

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  bool _isLoading = true;

  // Raw data from Supabase (enriched locally with names)
  List<Map<String, dynamic>> _allHistory = [];
  // After search/status filters
  List<Map<String, dynamic>> _filteredHistory = [];

  int _totalBorrowed = 0;
  int _currentlyBorrowing = 0;
  String _studentName = 'Student name';

  final _searchController = TextEditingController();
  String _selectedStatus = 'All'; // All | borrowed | returned

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_runFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchStudentName(),
        _fetchHistory(),
      ]);
      _calculateStats();
      _runFilters();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fetch current user's display name.
  /// Order:
  ///   1) public.users.name (if RLS allows)
  ///   2) auth.user.user_metadata.name / full_name
  ///   3) auth.user.email
  Future<void> _fetchStudentName() async {
    final authUser = supabase.auth.currentUser;
    final uid = authUser?.id;
    if (uid == null) return;

    String? name;

    // 1) public.users.name
    try {
      final row = await supabase
          .from('users')
          .select('name')
          .eq('id', uid)
          .maybeSingle();
      final dbName = row?['name']?.toString().trim();
      if (dbName != null && dbName.isNotEmpty) {
        name = dbName;
      }
    } catch (_) {
      // ignore; may be blocked by RLS
    }

    // 2) Auth metadata (common when you put name at sign-up)
    if (name == null || name.isEmpty) {
      final meta = authUser?.userMetadata ?? {};
      final metaName = (meta['name'] ?? meta['full_name'])?.toString().trim();
      if (metaName != null && metaName.isNotEmpty) {
        name = metaName;
      }
    }

    // 3) Fallback to email
    name ??= authUser?.email ?? 'Student';

    setState(() => _studentName = name!);
  }

  /// Map DB status to the UI label used in the design.
  /// DB: approved -> UI: borrowed
  String _mapStatusForUI(String? dbStatus) {
    final s = (dbStatus ?? '').toLowerCase();
    if (s == 'approved') return 'borrowed';
    return s;
  }

  /// Pull history for the current user.
  /// Strategy:
  /// 1) fetch bare rows (no embeds) with ids & status
  /// 2) look up asset names by asset_id
  /// 3) (best effort) look up approver/returner names; if RLS blocks, show N/A
  Future<void> _fetchHistory() async {
    _allHistory = [];
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1) base rows
    List<Map<String, dynamic>> rows = [];
    try {
      final res = await supabase
          .from('borrow_history')
          .select('id, borrow_date, status, asset_id, lender_id, staff_id')
          .eq('user_id', userId)
          .inFilter('status', ['approved', 'returned'])
          .order('borrow_date', ascending: false);
      rows = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      rows = [];
    }

    if (rows.isEmpty) {
      _allHistory = [];
      return;
    }

    // Collect ids
    final assetIds = <dynamic>{
      for (final r in rows) r['asset_id']
    }..removeWhere((e) => e == null);

    final lenderIds = <dynamic>{
      for (final r in rows) r['lender_id']
    }..removeWhere((e) => e == null);

    final staffIds = <dynamic>{
      for (final r in rows) r['staff_id']
    }..removeWhere((e) => e == null);

    // 2) asset names
    final assetNameById = <dynamic, String>{};
    try {
      if (assetIds.isNotEmpty) {
        final ares = await supabase
            .from('asset')
            .select('id, name')
            .inFilter('id', assetIds.toList());
        for (final a in (ares as List)) {
          assetNameById[a['id']] = (a['name'] ?? '—').toString();
        }
      }
    } catch (_) {}

    // 3) users (best effort; may be blocked by RLS)
    final userNameById = <dynamic, String>{};
    try {
      final allUserIds = <dynamic>{...lenderIds, ...staffIds}.toList();
      if (allUserIds.isNotEmpty) {
        final ures = await supabase
            .from('users')
            .select('id, name, full_name')
            .inFilter('id', allUserIds);
        for (final u in (ures as List)) {
          final n = (u['name'] ?? u['full_name'] ?? 'N/A').toString();
          userNameById[u['id']] = n.isEmpty ? 'N/A' : n;
        }
      }
    } catch (_) {
      // leave as N/A
    }

    // 4) stitch everything + compute UI status
    _allHistory = rows.map((r) {
      final uiStatus = _mapStatusForUI(r['status']?.toString());
      final assetId = r['asset_id'];
      final lenderId = r['lender_id'];
      final staffId = r['staff_id'];

      return {
        'borrow_date': r['borrow_date'],
        'status': r['status'],
        '_ui_status': uiStatus,
        'asset': {
          'name': assetNameById[assetId] ?? '—',
        },
        'approver':
            lenderId == null ? null : {'name': userNameById[lenderId] ?? 'N/A'},
        'returner':
            staffId == null ? null : {'name': userNameById[staffId] ?? 'N/A'},
      };
    }).toList();
  }

  void _calculateStats() {
    _totalBorrowed = _allHistory.length;
    _currentlyBorrowing =
        _allHistory.where((h) => h['_ui_status'] == 'borrowed').length;
  }

  void _runFilters() {
    var results = List<Map<String, dynamic>>.from(_allHistory);
    final q = _searchController.text.toLowerCase();

    if (_selectedStatus != 'All') {
      results =
          results.where((h) => (h['_ui_status'] ?? '') == _selectedStatus).toList();
    }

    if (q.isNotEmpty) {
      results = results
          .where((h) =>
              (h['asset']?['name'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }

    setState(() => _filteredHistory = results);
  }

  String _fmtDateTwoLines(dynamic v) {
    if (v == null) return 'N/A';
    try {
      final d = (v is String) ? DateTime.parse(v) : (v as DateTime);
      return '${DateFormat('dd/MM/').format(d)}\n${DateFormat('yyyy').format(d)}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerGrey = Color(0xFFD9D9D9);
    const chipBlue = Color(0xFF3085F4);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Row(
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    // user name at upper-right
                    Flexible(
                      child: Text(
                        _studentName,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats card
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E6E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _statLine('total book borrowing:', _totalBorrowed),
                    const SizedBox(height: 4),
                    _statLine('currently borrowing:', _currentlyBorrowing),
                  ],
                ),
              ),

              // Search + filters
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFFE6E6E6),
                        suffixIcon: const Icon(Icons.search,
                            size: 18, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'All',
                    selected: _selectedStatus == 'All',
                    filledColor: chipBlue,
                    onTap: () {
                      setState(() => _selectedStatus = 'All');
                      _runFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'borrowed',
                    selected: _selectedStatus == 'borrowed',
                    filledColor: chipBlue,
                    onTap: () {
                      setState(() => _selectedStatus = 'borrowed');
                      _runFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'returned',
                    selected: _selectedStatus == 'returned',
                    filledColor: chipBlue,
                    onTap: () {
                      setState(() => _selectedStatus = 'returned');
                      _runFilters();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Header row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: headerGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    _HeaderCell('book name', flex: 3),
                    _HeaderCell('Date', flex: 2),
                    _HeaderCell('Approved\nBy', flex: 2),
                    _HeaderCell('Returned\nTo', flex: 2),
                    _HeaderCell('status', flex: 2, alignEnd: true),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // History list
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_filteredHistory.isEmpty)
                const Expanded(child: Center(child: Text('No history found.')))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadInitialData,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 4),
                      separatorBuilder: (_, __) => const Divider(
                        height: 18,
                        thickness: 1,
                        color: Colors.black87,
                      ),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, i) {
                        final h = _filteredHistory[i];

                        final book = (h['asset']?['name'] ?? '—').toString();
                        final date2 = _fmtDateTwoLines(h['borrow_date']);

                        String _nameFrom(dynamic node) {
                          if (node == null) return 'N/A';
                          final m = Map<String, dynamic>.from(node as Map);
                          return (m['name'] ?? m['full_name'] ?? 'N/A').toString();
                        }

                        final approver = _nameFrom(h['approver']);
                        final uiStatus = (h['_ui_status'] ?? '').toString();
                        final returnedTo =
                            uiStatus == 'returned' ? _nameFrom(h['returner']) : 'N/A';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  book,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  softWrap: true,
                                  maxLines: 2,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  date2,
                                  style: const TextStyle(fontSize: 13, height: 1.1),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(approver,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(returnedTo,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _SolidStatusPill(
                                    status: uiStatus,
                                    blue: const Color(0xFF3085F4),
                                    green: const Color(0xFF69C76E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statLine(String label, int value) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// === Helper widgets ===
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
          maxLines: 2,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? filledColor;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.filledColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color whenSelected = filledColor ?? const Color(0xFF3085F4);
    final bool isFilled = selected;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isFilled ? whenSelected : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isFilled ? null : Border.all(color: Colors.black87, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isFilled ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SolidStatusPill extends StatelessWidget {
  final String status; // expects UI status
  final Color blue;
  final Color green;
  const _SolidStatusPill({
    required this.status,
    required this.blue,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final bg = s == 'borrowed' ? blue : (s == 'returned' ? green : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        s.isEmpty ? '—' : s,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}