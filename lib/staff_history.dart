// lib/staff_history.dart
import 'package:flutter/material.dart';

class StaffHistoryPage extends StatelessWidget {
  const StaffHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    const green = Color(0xFF22C55E);
    const yellow = Color(0xFFF2B84B);
    const midGrey = Color(0xFFE0E0E0);

    final rows = const [
      _HistoryRow(
        title: 'mobile application development',
        dateTwoLines: '10/01/\n2025',
        student: 'student',
        approvedBy: 'lender',
        returnedTo: 'N/A',
        statusText: 'borrowed',
        statusColor: blue,
      ),
      _HistoryRow(
        title: 'mobile application development',
        dateTwoLines: '09/01/\n2025',
        student: 'student',
        approvedBy: 'lender',
        returnedTo: 'staff',
        statusText: 'returned',
        statusColor: green,
      ),
      _HistoryRow(
        title: 'mobile application development',
        dateTwoLines: '08/01/\n2025',
        student: 'student',
        approvedBy: 'lender',
        returnedTo: 'staff',
        statusText: 'returned',
        statusColor: green,
      ),
      _HistoryRow(
        title: 'mobile application development',
        dateTwoLines: '10/01/\n2025',
        student: 'student',
        approvedBy: 'lender',
        returnedTo: 'N/A',
        statusText: 'borrowed',
        statusColor: blue,
      ),
      _HistoryRow(
        title: 'mobile application development',
        dateTwoLines: '10/01/\n2025',
        student: 'student',
        approvedBy: 'lender',
        returnedTo: 'N/A',
        statusText: 'late',
        statusColor: yellow,
        darkTextOnPill: true,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: const [
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Staff name',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search + filter chips (shrunk)
              Row(
                children: const [
                  Expanded(child: _SearchField()),
                  SizedBox(width: 8),
                  _IconBox(icon: Icons.filter_list),
                  SizedBox(width: 8),
                  _FilterChipLike(label: 'All', selected: true),
                  SizedBox(width: 6),
                  _FilterChipLike(label: 'borrowed'),
                  SizedBox(width: 6),
                  _FilterChipLike(label: 'returned'),
                  SizedBox(width: 6),
                  _FilterChipLike(label: 'late'),
                ],
              ),
              const SizedBox(height: 10),

              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: midGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    _HeaderCell('book name', flex: 3),
                    _HeaderCell('Date', flex: 2),
                    _HeaderCell('Student', flex: 2),
                    _HeaderCell('Approved', flex: 2),
                    _HeaderCell('Returned', flex: 2),
                    _HeaderCell('status', flex: 2, alignEnd: true),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Rows (compact)
              ...[
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  const Divider(thickness: 0.8, height: 14, color: Colors.black87),
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- UI helpers ----------

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.search, size: 18, color: Colors.black54),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: Colors.black87),
    );
  }
}

class _FilterChipLike extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChipLike({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF3B82F6) : Colors.white;
    final fg = selected ? Colors.white : Colors.black;
    final border = selected ? Colors.transparent : Colors.black54;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
          maxLines: 2,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String title;
  final String dateTwoLines;
  final String student;
  final String approvedBy;
  final String returnedTo;
  final String statusText;
  final Color statusColor;
  final bool darkTextOnPill;

  const _HistoryRow({
    required this.title,
    required this.dateTwoLines,
    required this.student,
    required this.approvedBy,
    required this.returnedTo,
    required this.statusText,
    required this.statusColor,
    this.darkTextOnPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: Text(title, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(dateTwoLines, style: const TextStyle(fontSize: 12, height: 1.1))),
          Expanded(flex: 2, child: Text(student, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(approvedBy, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(returnedTo, style: const TextStyle(fontSize: 12))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: darkTextOnPill ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}