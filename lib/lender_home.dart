// lib/lender_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import the global 'supabase' client
import 'package:supabase_flutter/supabase_flutter.dart'; // Import for Supabase v2 syntax

class LenderHomePage extends StatefulWidget {
  const LenderHomePage({super.key});

  @override
  State<LenderHomePage> createState() => _LenderHomePageState();
}

class _LenderHomePageState extends State<LenderHomePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _assets = []; // Master list from database
  List<Map<String, dynamic>> _filteredAssets = []; // List to display on screen

  // State variables for filtering and searching
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;
  bool _isSortedAZ = false; // Tracks if sorting is active

  // Dynamic list for categories, loaded from Supabase
  List<String> _categoryNames = [];
  // Static list for statuses
  final List<String> _statuses = [
    'available',
    'borrowed',
    'pending',
    'disable',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_runFilters);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches both assets and categories from Supabase.
  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_fetchAssets(), _fetchCategories()]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $error')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches the list of assets from the 'asset' table.
  Future<void> _fetchAssets() async {
    final response = await supabase.from('asset').select();
    _assets = List<Map<String, dynamic>>.from(response);
    _filteredAssets = _assets; // Initially, show all assets
  }

  /// Fetches the list of categories from the 'categories' table.
  Future<void> _fetchCategories() async {
    final response = await supabase.from('categories').select('name');
    _categoryNames = response
        .map((category) => category['name'] as String)
        .toList();
  }

  /// Toggles the A-Z sort state and re-runs the filters.
  void _toggleSort() {
    setState(() {
      _isSortedAZ = !_isSortedAZ; // Flip the boolean
    });
    _runFilters(); // Re-apply filters and sorting
  }

  /// Applies all active filters (search, category, status) and sorting.
  void _runFilters() {
    List<Map<String, dynamic>> results = _assets;
    final searchText = _searchController.text.toLowerCase();

    // 1. Filter by Search Text (Name)
    if (searchText.isNotEmpty) {
      results = results.where((asset) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        return name.contains(searchText);
      }).toList();
    }

    // 2. Filter by Category
    if (_selectedCategory != null) {
      results = results.where((asset) {
        return asset['category'] == _selectedCategory;
      }).toList();
    }

    // 3. Filter by Status
    if (_selectedStatus != null) {
      results = results.where((asset) {
        return asset['status'] == _selectedStatus;
      }).toList();
    }

    // 4. Apply Sorting (after filtering)
    if (_isSortedAZ) {
      results.sort((a, b) {
        final nameA = a['name']?.toString().toLowerCase() ?? '';
        final nameB = b['name']?.toString().toLowerCase() ?? '';
        return nameA.compareTo(nameB); // Sorts A-Z
      });
    }

    // Update the UI with the final list
    setState(() {
      _filteredAssets = results;
    });
  }

  /// Displays the pop-up modal for filtering.
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows modal to adjust for the keyboard
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Assets',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Category Filter Dropdown (Dynamic)
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Filter by Category'),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedCategory = value;
                      });
                    },
                    items: _categoryNames.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Status Filter Dropdown (Static)
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    hint: const Text('Filter by Status'),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedStatus = value;
                      });
                    },
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons (Clear & Apply)
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
                  const SizedBox(height: 16), // Bottom padding
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // We remove the SafeArea from here because the parent
    // 'LenderMainPage' Scaffold will handle it.
    return Column(
      children: [
        // --- Top Bar (Search, Filter, Sort) ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25.0)),
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

        // --- Asset Grid ---
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _filteredAssets.length,
                  itemBuilder: (context, index) {
                    final asset = _filteredAssets[index];
                    return AssetCard(asset: asset);
                  },
                ),
              ),
      ],
    );
  }
}

// --- Custom Widget for the Asset Card ---
class AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  const AssetCard({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final imageUrl = asset['image_url'];
    final status = asset['status'] ?? 'unknown';

    return GestureDetector(
      // The onTap is empty so the lender can't borrow.
      onTap: () {},
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[300],
                ),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : const Icon(
                        Icons.inventory_2,
                        size: 50,
                        color: Colors.grey,
                      ),
              ),
            ),

            // --- Title & Status ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    asset['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  StatusTag(status: status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Widget for the Status Tag ---
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
