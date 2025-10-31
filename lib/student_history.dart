
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

  // Demo dataset (for visual consistency)
  static const _demoRows = [
    {
      'status': 'borrowed',
      'borrow_date': '2025-01-10',
      'asset': {'name': 'mobile application development'},
      'approver': {'full_name': 'lender'},
      'returner': null,
    },
    {
      'status': 'returned',
      'borrow_date': '2025-01-09',
      'asset': {'name': 'mobile application development'},
      'approver': {'full_name': 'lender'},
      'returner': {'full_name': 'staff'},
    },
    {
      'status': 'returned',
      'borrow_date': '2025-01-08',
      'asset': {'name': 'mobile application development'},
      'approver': {'full_name': 'lender'},
      'returner': {'full_name': 'staff'},
    },
  ];

  List<Map<String, dynamic>> _allHistory =
      List<Map<String, dynamic>>.from(_demoRows);
  List<Map<String, dynamic>> _filteredHistory =
      List<Map<String, dynamic>>.from(_demoRows);

  int _totalBorrowed = _demoRows.length;
  int _currentlyBorrowing =
      _demoRows.where((h) => h['status'] == 'borrowed').length;

  final _searchController = TextEditingController();
  String _selectedStatus = 'All';

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
      await _fetchHistory();
      if (_allHistory.isEmpty) {
        _allHistory = List<Map<String, dynamic>>.from(_demoRows);
      }
      _calculateStats();
      _runFilters();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('borrow_history')
          .select(
              'borrow_date,status, asset(name), approver:lender_id!inner(full_name), returner:staff_id(full_name)')
          .eq('user_id', userId)
          .inFilter('status', ['borrowed', 'returned'])
          .order('borrow_date', ascending: false);
      _allHistory = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _allHistory = [];
    }
  }

  void _calculateStats() {
    _totalBorrowed = _allHistory.length;
    _currentlyBorrowing =
        _allHistory.where((h) => h['status'] == 'borrowed').length;
  }

  void _runFilters() {
    var results = _allHistory;
    final q = _searchController.text.toLowerCase();

    if (_selectedStatus != 'All') {
      results = results.where((h) => h['status'] == _selectedStatus).toList();
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
      final d = DateTime.parse(v as String);
      return '${DateFormat('dd/MM/').format(d)}\n${DateFormat('yyyy').format(d)}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerGrey = Color(0xFFD9D9D9);
    const chipBlue = Color(0xFF3085F4);
    const tagGreen = Color(0xFF69C76E);

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
                  children: const [
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Spacer(),
                    Text('Student name',
                        style:
                            TextStyle(fontSize: 14, color: Colors.black87)),
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
                    _statLine('total book borrowing :', _totalBorrowed),
                    const SizedBox(height: 4),
                    _statLine('currently borrowing :', _currentlyBorrowing),
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
                    onTap: () {
                      setState(() => _selectedStatus = 'borrowed');
                      _runFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'returned',
                    selected: _selectedStatus == 'returned',
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
                          height: 18, thickness: 1, color: Colors.black87),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, i) {
                        final h = _filteredHistory[i];
                        final book =
                            (h['asset']?['name'] ?? 'mobile application development')
                                .toString();
                        final date2 = _fmtDateTwoLines(h['borrow_date']);
                        final approver =
                            (h['approver']?['full_name'] ?? 'N/A').toString();
                        final status = (h['status'] ?? '').toString();
                        final returnedTo = status == 'returned'
                            ? (h['returner']?['full_name'] ?? 'N/A').toString()
                            : 'N/A';

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
                                child: Text(date2,
                                    style: const TextStyle(
                                        fontSize: 13, height: 1.1)),
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
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _SolidStatusPill(
                                    status: status,
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
          child: Text('$value',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
            fontSize: 12,
            color: filled ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SolidStatusPill extends StatelessWidget {
  final String status;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        s,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}