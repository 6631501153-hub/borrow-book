// lib/student_history.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // For supabase
import 'package:intl/intl.dart'; // For date formatting

class LenderHistoryPage extends StatefulWidget {
  const LenderHistoryPage({super.key});

  @override
  State<LenderHistoryPage> createState() => _LenderHistoryPageState();
}

class _LenderHistoryPageState extends State<LenderHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];

  // Stats
  int _totalBorrowed = 0;
  int _currentlyBorrowing = 0;

  // Filters
  final _searchController = TextEditingController();
  String _selectedStatus = 'All'; // 'All', 'borrowed', 'returned'

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
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchHistory();
      _calculateStats();
      _runFilters();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches 'borrowed' and 'returned' items from the database
  Future<void> _fetchHistory() async {
    final userId = supabase.auth.currentUser!.id;

    // --- THIS IS THE ONLY CHANGE ---
    // We now select 'lender_id' and alias it as 'approver'
    // so the rest of the code doesn't need to change.
    final response = await supabase
        .from('borrow_history')
        .select(
          '*, asset(*), approver:lender_id!users(full_name), returner:staff_id!users(full_name)',
        )
        .eq('user_id', userId)
        .inFilter('status', ['borrowed', 'returned'])
        .order('borrow_date', ascending: false);
    // --- END OF CHANGE ---

    _allHistory = List<Map<String, dynamic>>.from(response);
  }

  void _calculateStats() {
    _totalBorrowed = _allHistory.length;
    _currentlyBorrowing = _allHistory
        .where((h) => h['status'] == 'borrowed')
        .length;
  }

  void _runFilters() {
    List<Map<String, dynamic>> results = _allHistory;
    final searchQuery = _searchController.text.toLowerCase();

    if (_selectedStatus != 'All') {
      results = results.where((h) {
        return h['status'] == _selectedStatus;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      results = results.where((h) {
        final assetName = h['asset']['name']?.toString().toLowerCase() ?? '';
        return assetName.contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredHistory = results;
    });
  }

  // --- All the build methods below are unchanged ---

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStats(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterToggles(),
            const SizedBox(height: 16),
            _buildListHeader(),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            'History',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          // TODO: Get student name dynamically
          Text(
            'Lender name',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('total book borrowing:', _totalBorrowed),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('currently borrowing:', _currentlyBorrowing),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 97, 97, 97),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildFilterToggles() {
    final filters = ['All', 'borrowed', 'returned'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: filters.map((status) {
        final isSelected = _selectedStatus == status;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(status),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedStatus = status;
              });
              _runFilters();
            },
            selectedColor: Colors.blue,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'book name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Borrower',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Returned To',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_filteredHistory.isEmpty) {
      return const Expanded(child: Center(child: Text('No history found.')));
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: ListView.builder(
          itemCount: _filteredHistory.length,
          itemBuilder: (context, index) {
            final item = _filteredHistory[index];
            return _HistoryItemRow(historyItem: item);
          },
        ),
      ),
    );
  }
}

// --- Custom Row Widget (No changes needed here) ---
// This widget still works because our query renames 'lender_id'
// to 'approver' before it gets to the app.
class _HistoryItemRow extends StatelessWidget {
  final Map<String, dynamic> historyItem;

  const _HistoryItemRow({required this.historyItem});

  @override
  Widget build(BuildContext context) {
    final asset = historyItem['asset'];
    final status = historyItem['status'];
    final bookName = asset['name'] ?? 'No Name';

    final date = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.parse(historyItem['borrow_date']));

    final approverData = historyItem['approver'] as Map?; // This still works
    final returnerData = historyItem['returner'] as Map?;

    final approverName = approverData?['full_name'] ?? 'N/A';
    final returnerName = status == 'returned'
        ? (returnerData?['full_name'] ?? 'N/A')
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color.fromARGB(255, 101, 97, 97)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(bookName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(flex: 2, child: Text(date)),
          Expanded(
            flex: 2,
            child: Text(approverName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(returnerName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(flex: 2, child: StatusTag(status: status)),
        ],
      ),
    );
  }
}

// --- StatusTag Widget (Unchanged) ---
class StatusTag extends StatelessWidget {
  final String status;
  const StatusTag({super.key, required this.status});

  Color _getColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'borrowed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'disable':
        return Colors.red;
      case 'returned':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _getColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
