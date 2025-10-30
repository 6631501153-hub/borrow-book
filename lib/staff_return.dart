// lib/staff_return.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffReturnPage extends StatefulWidget {
  const StaffReturnPage({super.key});

  @override
  State<StaffReturnPage> createState() => _StaffReturnPageState();
}

class _StaffReturnPageState extends State<StaffReturnPage> {
  late Future<List<Map<String, dynamic>>> _borrowedItemsFuture;

  @override
  void initState() {
    super.initState();
    _borrowedItemsFuture = _fetchBorrowedItems();
  }

  void _refreshItems() {
    setState(() {
      _borrowedItemsFuture = _fetchBorrowedItems();
    });
  }

  /// Fetches all items currently 'borrowed' (i.e., pending return)
  Future<List<Map<String, dynamic>>> _fetchBorrowedItems() async {
    // This query fetches the borrow history records that are currently 'borrowed'
    // and joins the asset name and the student's name for display.
    try {
      final response = await supabase
          .from('borrow_history')
          .select(
            // Joins three tables:
            // 1. borrow_history (*)
            // 2. asset!inner (selects all asset columns)
            // 3. users (selects student full_name)
            '*, asset!inner(name), student:user_id(full_name)'
          )
          .eq('status', 'borrowed') // Only get items currently borrowed/in circulation
          .order('return_date', ascending: true); // Show items due soonest first

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      // Catch specific Supabase errors. This is common if RLS is wrong.
      debugPrint('Error fetching borrowed items: ${e.message}');
      rethrow; 
    } catch (e) {
      debugPrint('General error fetching borrowed items: $e');
      rethrow;
    }
  }

  // Action taken when Staff clicks the 'Return' button
  void _processReturn(Map<String, dynamic> historyItem) async {
    final historyId = historyItem['id'];
    final assetId = historyItem['asset_id'];
    final currentStaffId = supabase.auth.currentUser!.id;

    // Show confirmation dialog before processing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Text('Confirm return for "${historyItem['asset']['name']}" from ${historyItem['student']['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 1. Update borrow_history record status to 'returned'
      await supabase
          .from('borrow_history')
          .update({
            'status': 'returned',
            'return_date': DateTime.now().toIso8601String(), // Optional: Update actual return date
            'staff_id': currentStaffId, // Record which staff member processed the return
          })
          .eq('id', historyId);

      // 2. Update the asset status back to 'available'
      await supabase
          .from('asset')
          .update({'status': 'available'})
          .eq('id', assetId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset successfully returned!')),
        );
      }

      // 3. Refresh the list to remove the returned item
      _refreshItems();
      
    } catch (error) {
      debugPrint('Return process failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process return.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return'),
        actions: [
          // Display Staff Name (Placeholder)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: Text('Staff name', style: TextStyle(color: Theme.of(context).primaryColor))),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Search and Filter Bar ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.filter_list, size: 30),
              ],
            ),
          ),

          // --- Table Headers ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Book Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Borrow Date', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- List of Borrowed Items ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _borrowedItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No assets currently borrowed.'));
                }

                final items = snapshot.data!;

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ReturnItemRow(
                      item: item,
                      onReturn: () => _processReturn(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper Widget for a single row in the return list
class _ReturnItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onReturn;

  const _ReturnItemRow({required this.item, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    // Extract and format data
    final bookName = item['asset']['name'] ?? 'Unknown Asset';
    final studentName = item['student']['full_name'] ?? 'Unknown Student';
    final borrowDate = _formatDate(item['borrow_date']);
    final returnDate = _formatDate(item['return_date']);
    final assetId = item['asset_id']?.toString() ?? 'N/A';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(bookName, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 1, child: Text(assetId)),
              Expanded(flex: 2, child: Text(borrowDate)),
              Expanded(flex: 2, child: Text(returnDate)),
              Expanded(flex: 2, child: Text(studentName, overflow: TextOverflow.ellipsis)),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text('return', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString as String);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }
}