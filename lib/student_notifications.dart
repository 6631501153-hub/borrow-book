// lib/student_notifications.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// lib/student_notifications.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_application_1/main.dart';
// import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});

  @override
  State<StudentNotificationsPage> createState() =>
      _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  /// Tracks which request-id is being cancelled to disable its button
  final Set<int> _busyIds = {};

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
        // Join asset columns; exclude returned & cancelled
        final resp = await supabase
            .from('borrow_history')
            .select(
              'id, status, borrow_date, return_date, '
              'asset:asset!inner(id, name, image_url)',
            )
            .eq('user_id', uid)
            .not('status', 'in', ['returned', 'cancelled']) // <-- FIXED
            .order('borrow_date', ascending: false);

        _requests = List<Map<String, dynamic>>.from(resp);
      }
    } on PostgrestException catch (e) {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final int id = (request['id'] as num).toInt();
    if (_busyIds.contains(id)) return;

    final assetId = request['asset']?['id'];
    if (assetId == null) return;

    // Optimistic UI: remove immediately, but keep a copy to restore on failure
    final prevList = List<Map<String, dynamic>>.from(_requests);
    setState(() {
      _busyIds.add(id);
      _requests.removeWhere((r) => (r['id'] as num).toInt() == id);
    });

    try {
      // 1) Mark the borrow as cancelled (soft delete)
      await supabase
          .from('borrow_history')
          .update({'status': 'cancelled'})
          .eq('id', id);

      // 2) Flip the asset back to available
      await supabase.from('asset').update({'status': 'available'}).eq('id', assetId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _requests = prevList);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _requests = prevList);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: _requests.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No active requests')),
                        SizedBox(height: 120),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final r = _requests[index];
                        final isBusy =
                            _busyIds.contains((r['id'] as num).toInt());
                        return _RequestCardAndActions(
                          request: r,
                          busy: isBusy,
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
  final bool busy;
  const _RequestCardAndActions({
    required this.request,
    required this.onCancel,
    required this.busy,
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
                // Image
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
                      child: const Icon(Icons.more_horiz,
                          color: yellow, size: 20),
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
                onPressed: busy ? null : onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'cancel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
