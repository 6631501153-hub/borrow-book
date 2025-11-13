import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:intl/intl.dart';

class LenderHistoryPage extends StatefulWidget {
  const LenderHistoryPage({super.key});
  @override
  State<LenderHistoryPage> createState() => _LenderHistoryPageState();
}

class _LenderHistoryPageState extends State<LenderHistoryPage> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];

  int _totalBorrowed = 0;
  int _currentlyBorrowing = 0;

  final _searchController = TextEditingController();
  String _selectedStatus = 'All'; // All | borrowed | returned

  String _lenderName = 'lender name';

  @override
  void initState() {
    super.initState();
    _fetchLenderName();
    _load();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Lender name ----------

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
    } catch (_) {}
  }

  // ---------- Load history (with student names) ----------

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _allHistory = [];
        _filteredHistory = [];
        _totalBorrowed = 0;
        _currentlyBorrowing = 0;
        return;
      }

      // 1) base history rows for this lender
      final resp = await supabase
          .from('borrow_history')
          .select(
            'id, user_id, lender_id, asset_id, status, '
            'borrow_date, return_date, '
            'asset:asset!inner(name)',
          )
          // if you want ALL rows you can see, comment this line out
          .eq('lender_id', user.id)
          .order('borrow_date', ascending: false);

      final rawRows = List<Map<String, dynamic>>.from(resp);

      // 2) collect distinct student user_ids
      final userIds = <String>{
        for (final r in rawRows)
          if (r['user_id'] != null) r['user_id'].toString(),
      };

      // 3) lookup names from users table
      final Map<String, String> userNameById = {};
      if (userIds.isNotEmpty) {
        try {
          final ures = await supabase
              .from('users')
              .select('id, name')
              .inFilter('id', userIds.toList());

          for (final u in (ures as List)) {
            final id = u['id']?.toString();
            final nm = (u['name'] ?? '').toString().trim();
            if (id != null && id.isNotEmpty) {
              userNameById[id] = nm.isEmpty ? 'N/A' : nm;
            }
          }
        } catch (_) {
          // if blocked by RLS, names will stay as 'N/A'
        }
      }

      // 4) stitch: add a "student_name" field per row
      _allHistory = rawRows
          .map((r) => {
                ...r,
                'student_name':
                    userNameById[r['user_id']?.toString()] ?? 'N/A',
              })
          .toList();

      _calc();
      _applyFilters();
    } catch (_) {
      // on error keep whatever we had; could also clear
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Map raw DB status → UI status
  // approved  -> borrowed
  // returned  -> returned
  // others    -> '' (ignored in history)
  String _toUiStatus(dynamic raw) {
    final s = (raw ?? '').toString().toLowerCase();
    if (s == 'approved') return 'borrowed';
    if (s == 'returned') return 'returned';
    return ''; // rejected, pending, etc → not shown
  }

  void _calc() {
    final valid = _allHistory
        .where((h) {
          final ui = _toUiStatus(h['status']);
          return ui == 'borrowed' || ui == 'returned';
        })
        .toList();

    _totalBorrowed = valid.length;
    _currentlyBorrowing =
        valid.where((h) => _toUiStatus(h['status']) == 'borrowed').length;
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();

    var list = _allHistory.where((h) {
      final uiStatus = _toUiStatus(h['status']);
      return uiStatus == 'borrowed' || uiStatus == 'returned';
    }).toList();

    if (_selectedStatus != 'All') {
      list = list
          .where((h) => _toUiStatus(h['status']) == _selectedStatus)
          .toList();
    }

    if (q.isNotEmpty) {
      list = list
          .where((h) =>
              (h['asset']?['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(q))
          .toList();
    }

    setState(() => _filteredHistory = list);
  }

  String _fmtDateTwoLines(dynamic v) {
    if (v == null) return 'N/A';
    try {
      final d = DateTime.parse(v.toString());
      return '${DateFormat('dd/MM/').format(d)}\n${DateFormat('yyyy').format(d)}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerGrey = Color(0xFFD9D9D9);
    const chipBlue = Color(0xFF3085F4);
    const statusGreen = Color(0xFF69C76E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + lender name
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 4),
                child: Row(
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        height: 1,
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

              // Stats card
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 8),
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

              // Search + Filter
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
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'borrowed',
                    selected: _selectedStatus == 'borrowed',
                    onTap: () {
                      setState(() => _selectedStatus = 'borrowed');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'returned',
                    selected: _selectedStatus == 'returned',
                    onTap: () {
                      setState(() => _selectedStatus = 'returned');
                      _applyFilters();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Table header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: headerGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    _HeaderCell('book name', flex: 3),
                    _HeaderCell('Date', flex: 2),
                    _HeaderCell('student\nname', flex: 2),
                    _HeaderCell('Returned\nTo', flex: 2),
                    _HeaderCell('status', flex: 2, alignEnd: true),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // List
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                      separatorBuilder: (_, __) => const Divider(
                        height: 20,
                        thickness: 1,
                        color: Colors.black87,
                      ),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, i) {
                        final h = _filteredHistory[i];

                        final book =
                            (h['asset']?['name'] ?? 'unknown').toString();
                        final date2 = _fmtDateTwoLines(h['borrow_date']);
                        final student =
                            (h['student_name'] ?? 'N/A').toString();

                        final uiStatus = _toUiStatus(h['status']);
                        final returnedTo =
                            (uiStatus == 'returned') ? 'staff' : 'N/A';

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  book,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87),
                                  softWrap: true,
                                  maxLines: 2,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  date2,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  student,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  returnedTo,
                                  style:
                                      const TextStyle(fontSize: 14),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _SolidStatusPill(
                                    status: uiStatus,
                                    blue: chipBlue,
                                    green: statusGreen,
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
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Small UI helpers ---

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
            fontSize: 13,
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
    final filled = selected && filledColor != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? filledColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: Colors.black87, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: filled ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SolidStatusPill extends StatelessWidget {
  final String status; // borrowed | returned
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
    final bg =
        s == 'borrowed' ? blue : (s == 'returned' ? green : Colors.grey);
    final label = s.isEmpty ? 'unknown' : s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
