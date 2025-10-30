// lib/asset_details_page.dart
// --- Make sure all these imports are at the top ---
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // This import is still needed!

// ... (Your AssetDetailsPage widget is unchanged) ...
class AssetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> asset;
  const AssetDetailsPage({super.key, required this.asset});

  @override
  State<AssetDetailsPage> createState() => _AssetDetailsPageState();
}


// --- REPLACE YOUR OLD STATE CLASS WITH THIS NEW ONE ---
class _AssetDetailsPageState extends State<AssetDetailsPage> {
  // --- A. State Variables ---
  DateTime? _selectedReturnDate;
  bool _isLoading = false;

  // --- B. Computed Getters ---
  bool get _isAvailable => widget.asset['status'] == 'available';
  bool get _canSubmit =>
      _isAvailable && _selectedReturnDate != null && !_isLoading;

  // --- C. Core Logic & Actions ---

  Future<void> _pickDate() async {
    if (!_isAvailable) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedReturnDate = pickedDate;
      });
    }
  }

  /// Validates and submits the borrow request to Supabase.
  Future<void> _submitRequest() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      // --- 1. RULE 1: Check if user already borrowed today ---
      // This is the new, corrected code for Supabase v2
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      // Use the new .count() method. This replaces .select()
      final count = await supabase
          .from('borrow_history')
          .count(CountOption.exact) // This is the new way
          .eq('user_id', userId)
          .gte('borrow_date', startOfToday.toIso8601String())
          .lt('borrow_date', startOfTomorrow.toIso8601String());

      // Check the count
      if (count > 0) {
        // User already has a request today. Show an error.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only make one borrow request per day.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Stop the function
      }

      // --- 2. If all checks pass, create the request ---

      // 1. Insert into 'borrow_history'
      await supabase.from('borrow_history').insert({
        'user_id': userId,
        'asset_id': widget.asset['id'],
        'return_date': _selectedReturnDate!.toIso8601String(),
        'status': 'pending'
      });

      // 2. Update the asset's status to 'pending'
      await supabase
          .from('asset')
          .update({'status': 'pending'})
          .eq('id', widget.asset['id']);

      // 3. Show success and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to the home page
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always stop the loading spinner
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- D. Build Method (The main UI) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requestment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildRequestBox(),
        ),
      ),
    );
  }

  // --- E. UI Helper Widgets (All unchanged) ---

  Widget _buildRequestBox() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImage(),
          const SizedBox(height: 16),
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildInteractionSection(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = widget.asset['image_url'];
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[300],
      ),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(imageUrl, fit: BoxFit.cover)
          : const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        Text(
          widget.asset['name'] ?? 'No Name',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Center(child: StatusTag(status: widget.asset['status'] ?? 'unknown')),
      ],
    );
  }

  Widget _buildInteractionSection() {
    if (_isAvailable) {
      return _buildDatePicker();
    } else {
      return _buildNotAvailableText();
    }
  }

  Widget _buildDatePicker() {
    final formattedDate = _selectedReturnDate == null
        ? 'Select return date'
        : DateFormat('dd/MM/yyyy').format(_selectedReturnDate!);

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 16,
                color:
                    _selectedReturnDate == null ? Colors.grey[600] : Colors.black,
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _canSubmit ? _submitRequest : null,
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Text('Submit a request', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildNotAvailableText() {
    return Text(
      'This item is currently "${widget.asset['status']}" and cannot be requested.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: Colors.red[700],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ... (Your StatusTag widget is unchanged) ...
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}