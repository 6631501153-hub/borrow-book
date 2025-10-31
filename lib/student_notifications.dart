
// lib/student_notifications.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});

  @override
  State<StudentNotificationsPage> createState() =>
      _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        _requests = [];
      } else {
        // IMPORTANT: alias + inner join — same pattern as other pages
        final resp = await supabase
            .from('borrow_history')
            .select(
              'id, status, borrow_date, return_date, '
              'asset:asset!inner(id, name, image_url)',
            )
            .eq('user_id', uid)
            .neq('status', 'returned')
            .order('borrow_date', ascending: false);

        _requests = List<Map<String, dynamic>>.from(resp);
      }
    } on PostgrestException catch (e) {
      // Show the error but still render a demo so the screen isn't blank
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetch error: ${e.message}')),
        );
      }
      _requests = [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      _requests = [];
    } finally {
      // If nothing came back, show one demo card so UI isn't empty
      if (_requests.isEmpty) {
        _requests = [
          {
            'id': -1,
            'status': 'pending',
            'borrow_date': '2025-01-01T23:59:00.000Z',
            'return_date': '2025-01-01T23:59:00.000Z',
            'asset': {
              'id': -1,
              'name': 'Mobile application Development',
              'image_url': '', // keep grey box like the mock
            },
          },
        ];
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    // Ignore cancel for demo row
    if (request['id'] == -1) return;

    final requestId = request['id'];
    final assetId = request['asset']['id'];
    try {
      await supabase.from('borrow_history').delete().eq('id', requestId);
      await supabase.from('asset').update({'status': 'available'}).eq('id', assetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled.'), backgroundColor: Colors.green),
        );
      }
      _fetchRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final r = _requests[index];
                  return _RequestCardAndActions(
                    request: r,
                    onCancel: () => _cancelRequest(r),
                  );
                },
              ),
            ),
    );
  }
}

// ===== Card + Cancel button (button OUTSIDE the card) =====
class _RequestCardAndActions extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onCancel;
  const _RequestCardAndActions({
    required this.request,
    required this.onCancel,
  });

  String _fmtTime(String iso) =>
      DateFormat('HH.mm').format(DateTime.parse(iso).toLocal());
  String _fmtDate(String iso) =>
      DateFormat('dd/MM/yyyy').format(DateTime.parse(iso).toLocal());

  @override
  Widget build(BuildContext context) {
    final asset = request['asset'] as Map<String, dynamic>? ?? {};
    final imageUrl = (asset['image_url'] ?? '').toString();
    final name = (asset['name'] ?? 'No name').toString();
    final status = (request['status'] ?? '').toString().toLowerCase();

    final borrowIso = (request['borrow_date'] ?? '').toString();
    final returnIso = (request['return_date'] ?? '').toString();

    // Colors like the mock
    const cardBg = Color(0xFFEFFFFF); // pale cyan
    const yellow = Color(0xFFFFEB3B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (grey box if no URL)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                const Text('request date',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(borrowIso.isEmpty ? '—' : _fmtTime(borrowIso),
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 18),
                    Text(borrowIso.isEmpty ? '—' : _fmtDate(borrowIso),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),

                const Text('return date',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(returnIso.isEmpty ? '—' : _fmtTime(returnIso),
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 18),
                    Text(returnIso.isEmpty ? '—' : _fmtDate(returnIso),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),

                const SizedBox(height: 22),

                // Yellow circle … + status text
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: yellow, width: 3),
                      ),
                      child: const Icon(Icons.more_horiz, color: yellow, size: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status.isEmpty ? 'pending' : status,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (status == 'pending')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('cancel',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}