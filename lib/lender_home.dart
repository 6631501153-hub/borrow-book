// lib/lender_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LenderHomePage extends StatefulWidget {
  const LenderHomePage({super.key});

  @override
  State<LenderHomePage> createState() => _LenderHomePageState();
}

class _LenderHomePageState extends State<LenderHomePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _filteredAssets = [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;
  bool _isSortedAZ = false;

  List<String> _categoryNames = [];
  final List<String> _statuses = ['available', 'borrowed', 'pending', 'disable'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_runFilters);

    // ALWAYS refresh asset list when this page appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // Data loading
  // ------------------------------------------------

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchAssetsWithHistory(),
        _fetchCategories(),
      ]);
      _runFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Normalize asset.status from DB
  String _normalizeAssetStatus(String s) {
    final v = s.trim().toLowerCase();
    // for lender we keep 'disable' as-is (student used 'disabled')
    return v;
  }

  /// Combine raw asset.status + latest borrow_history status for that asset.
  ///
  /// Rules (from lender's perspective):
  ///   - latest bh: pending  -> 'pending'
  ///   - latest bh: approved/borrowed -> 'borrowed'
  ///   - latest bh: returned/rejected/cancelled -> 'available'
  ///   - if asset is 'disable' -> always 'disable'
  ///   - if no bh -> use raw asset.status
  String _statusFromBorrowHistory(String rawAssetStatus, String? bhStatus) {
    final base = _normalizeAssetStatus(rawAssetStatus);

    // If asset is disabled, we always show disable
    if (base == 'disable') return 'disable';

    if (bhStatus == null) return base;

    final s = bhStatus.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return 'pending';
      case 'approved':
      case 'borrowed':
        return 'borrowed';
      case 'returned':
      case 'rejected':
      case 'cancelled':
        return 'available';
      default:
        return base;
    }
  }

  /// Fetch assets and merge with latest borrow_history status (GLOBAL, not per user).
  Future<void> _fetchAssetsWithHistory() async {
    // 1) fetch all assets
    final assetResp = await supabase.from('asset').select();
    final assets = List<Map<String, dynamic>>.from(assetResp);

    // 2) fetch all borrow_history rows ordered by time
    final bhResp = await supabase
        .from('borrow_history')
        .select('asset_id, status, borrow_date')
        .order('borrow_date', ascending: true); // older -> newer

    final Map<dynamic, String> lastStatusByAssetId = {};
    for (final row in (bhResp as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final aid = m['asset_id'];
      final stat = (m['status'] ?? '').toString();
      if (aid != null) {
        // last row (newest) wins because of ascending order
        lastStatusByAssetId[aid] = stat;
      }
    }

    // 3) build merged list with UI status
    _assets = assets.map((asset) {
      final id = asset['id'];
      final rawStatus = (asset['status'] ?? '').toString();
      final latestBhStatus = lastStatusByAssetId[id];

      final uiStatus = _statusFromBorrowHistory(rawStatus, latestBhStatus);

      return {
        ...asset,
        'status': uiStatus, // override for UI
      };
    }).toList();

    _filteredAssets = _assets;
  }

  Future<void> _fetchCategories() async {
    final response = await supabase.from('categories').select('name');
    _categoryNames =
        response.map<String>((e) => e['name'].toString()).toList();
  }

  // ------------------------------------------------
  // Filters / sorting
  // ------------------------------------------------

  void _toggleSort() {
    setState(() => _isSortedAZ = !_isSortedAZ);
    _runFilters();
  }

  void _runFilters() {
    List<Map<String, dynamic>> results = [..._assets];

    final searchText = _searchController.text.toLowerCase();

    // Search
    if (searchText.isNotEmpty) {
      results = results.where((asset) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        return name.contains(searchText);
      }).toList();
    }

    // Category
    if (_selectedCategory != null) {
      results = results.where((asset) {
        return asset['category'] == _selectedCategory;
      }).toList();
    }

    // Status (case insensitive)
    if (_selectedStatus != null) {
      final selected = _selectedStatus!.toLowerCase();
      results = results.where((asset) {
        final st = (asset['status'] ?? '').toString().toLowerCase();
        return st == selected;
      }).toList();
    }

    // Sort A–Z
    if (_isSortedAZ) {
      results.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });
    }

    setState(() => _filteredAssets = results);
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Filter by Category'),
                  onChanged: (v) {
                    setModalState(() => _selectedCategory = v);
                  },
                  items: _categoryNames
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  hint: const Text('Filter by Status'),
                  onChanged: (v) {
                    setModalState(() => _selectedStatus = v);
                  },
                  items: _statuses
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCategory = null;
                          _selectedStatus = null;
                        });
                        _runFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        _runFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar + filter & sort
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterModal,
              ),
              IconButton(
                icon: Icon(
                  Icons.sort_by_alpha,
                  color: _isSortedAZ
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                onPressed: _toggleSort,
              ),
            ],
          ),
        ),

        _isLoading
            ? const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            : Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _filteredAssets.length,
                    itemBuilder: (context, i) {
                      return AssetCard(asset: _filteredAssets[i]);
                    },
                  ),
                ),
              ),
      ],
    );
  }
}

class AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  const AssetCard({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final imageUrl = asset['image_url'];
    final status = (asset['status'] ?? '').toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          Expanded(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  )
                : const Icon(Icons.inventory_2,
                    size: 60, color: Colors.grey),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  asset['name'] ?? 'No Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                StatusTag(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String status;
  const StatusTag({super.key, required this.status});

  Color _color() {
    switch (status.toLowerCase()) {
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
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
