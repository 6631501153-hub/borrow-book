// lib/student_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/asset_details_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  /// all assets from DB and the filtered set to render
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _shown = [];

  /// filters / sort
  String? _statusFilter;              // null => all
  String? _categoryFilter;            // null => all
  bool _sortAsc = true;

  /// dynamic categories (from DB)
  List<String> _categories = [];
  /// allowed statuses (UI)
  static const List<String> _statuses = [
    'available', 'borrowed', 'pending', 'disabled'
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilters);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------- Data ----------------------

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Join category name via FK (asset.category_id -> categories.id)
      final rows = await supabase
          .from('asset')
          .select('id,name,status,image_url,category:categories(name)')
          .order('name', ascending: true);

      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => {
                'id'        : m['id'],
                'name'      : m['name'],
                'image_url' : (m['image_url'] ?? '').toString(),
                'status'    : _normalizeStatus((m['status'] ?? '').toString()),
                'category'  : (m['category'] is Map && (m['category']?['name']) != null)
                    ? m['category']['name'].toString()
                    : null,
              })
          .toList();

      _all = list;

      // collect distinct categories for filter
      _categories = _all
          .map((m) => (m['category'] ?? '') as String)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizeStatus(String s) {
    final v = s.toLowerCase();
    return v == 'disable' ? 'disabled' : v;
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = List<Map<String, dynamic>>.from(_all);

    // search
    if (q.isNotEmpty) {
      list = list
          .where((m) => (m['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(q))
          .toList();
    }

    // status
    if (_statusFilter != null) {
      list = list.where((m) => m['status'] == _statusFilter).toList();
    }

    // category
    if (_categoryFilter != null) {
      list = list.where((m) => (m['category'] ?? '') == _categoryFilter).toList();
    }

    // sort
    list.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return _sortAsc ? an.compareTo(bn) : bn.compareTo(an);
    });

    setState(() => _shown = list);
  }

  Future<void> _openDetails(Map<String, dynamic> asset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssetDetailsPage(asset: asset)),
    );
    // When returning, reload from DB to reflect new statuses (e.g., pending)
    await _load();
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F2F7);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Student'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Search + Filter + Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black12.withOpacity(.1),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 22, color: Colors.black87),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Search',
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => _applyFilters(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Filter',
                  icon: const Icon(Icons.filter_alt_outlined),
                  onPressed: () async {
                    final res = await showModalBottomSheet<_FilterResult>(
                      context: context,
                      builder: (_) => _FilterSheet(
                        categories: _categories,
                        statuses: _statuses,
                        currentCategory: _categoryFilter,
                        currentStatus: _statusFilter,
                      ),
                    );
                    if (res != null) {
                      setState(() {
                        _categoryFilter = res.category;
                        _statusFilter = res.status;
                      });
                      _applyFilters();
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Sort A–Z',
                  icon: const Icon(Icons.sort_by_alpha),
                  onPressed: () {
                    setState(() => _sortAsc = !_sortAsc);
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_shown.isEmpty) return const Center(child: Text('No assets yet.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 18, crossAxisSpacing: 18, childAspectRatio: 0.9),
        itemCount: _shown.length,
        itemBuilder: (_, i) => _AssetCard(
          asset: _shown[i],
          onTap: () => _openDetails(_shown[i]),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onTap;
  const _AssetCard({required this.asset, required this.onTap});

  Color _badge(String s) {
    switch (s) {
      case 'available': return const Color(0xFF43A047); // green
      case 'borrowed' : return const Color(0xFF1E88E5); // blue
      case 'pending'  : return const Color(0xFFF9A825); // amber
      case 'disabled' : return const Color(0xFFE53935); // red
      default         : return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (asset['status'] ?? '').toString();
    final img = (asset['image_url'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.lightBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: img.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(img, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.image, size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),

            // name
            Text(
              (asset['name'] ?? 'Unnamed').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // status pill
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _badge(status),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for filters
class _FilterSheet extends StatefulWidget {
  final List<String> categories;
  final List<String> statuses;
  final String? currentCategory;
  final String? currentStatus;
  const _FilterSheet({
    required this.categories,
    required this.statuses,
    required this.currentCategory,
    required this.currentStatus,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _cat;
  String? _st;

  @override
  void initState() {
    super.initState();
    _cat = widget.currentCategory;
    _st  = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filter Assets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _cat,
              hint: const Text('Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _cat = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _st,
              hint: const Text('Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...widget.statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _st = v),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const _FilterResult(null, null)),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _FilterResult(_cat, _st)),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterResult {
  final String? category;
  final String? status;
  const _FilterResult(this.category, this.status);
}