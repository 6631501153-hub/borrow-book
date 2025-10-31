
// lib/student_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/asset_details_page.dart'; // Import the global 'supabase' client

// --- 1. Student Home Page (Stateful Widget) ---
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

// --- 2. The State Class (Contains all the logic) ---
class _StudentHomePageState extends State<StudentHomePage> {
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
  final List<String> _statuses = ['available', 'borrowed', 'pending', 'disable'];

  @override
  void initState() {
    super.initState();
    // Add listener for the search bar
    _searchController.addListener(_runFilters);
    // Fetch initial data from Supabase
    _loadInitialData();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches both assets and categories from Supabase at the same time.
  Future<void> _loadInitialData() async {
    try {
      // Run both fetches in parallel
      await Future.wait([
        _fetchAssets(),
        _fetchCategories(),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $error')),
        );
      }
    } finally {
      // Stop the loading indicator only after all data is fetched
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
    
    // Convert list of maps [{'name': 'Fiction'},...] to list of strings ['Fiction',...]
    _categoryNames =
        response.map((category) => category['name'] as String).toList();
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
        // StatefulBuilder allows the modal to update its own state
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              // Add padding to avoid the keyboard
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
                  const Text('Filter Assets',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    // Use the dynamic list from Supabase
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
                          // Clear filters in the modal
                          setModalState(() {
                            _selectedCategory = null;
                            _selectedStatus = null;
                          });
                          // Re-run filters and close modal
                          _runFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          // Apply filters and close modal
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
    // SafeArea prevents UI from going under status bar (time, battery)
    return SafeArea(
      child: Column(
        children: [
          // --- Top Bar (Search, Filter, Sort) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name....',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25.0)),
                      ),
                    ),
                  ),
                ),
                // Filter Button
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterModal,
                ),
                
                // Sort Button
                IconButton(
                  icon: Icon(
                    Icons.sort_by_alpha,
                    // Change color when active
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
              // Show loading spinner
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              // Show the grid
              : Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 items per row
                      childAspectRatio: 0.8, // Adjust height
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    // Use the filtered list
                    itemCount: _filteredAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _filteredAssets[index];
                      // Pass data to the custom card widget
                      return AssetCard(asset: asset);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

// --- 3. Custom Widget for the Asset Card ---
class AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  const AssetCard({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final imageUrl = asset['image_url'];
    final status = asset['status'] ?? 'unknown';

    return GestureDetector(
      onTap: () {
        // --- THIS IS THE LINE TO CHANGE ---
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetDetailsPage(asset: asset),
          ),
        );
        // --- END OF CHANGE ---
      },
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
                // Show image or placeholder icon
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.inventory_2, size: 50, color: Colors.grey),
              ),
            ),
            
            // --- Title & Status ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // --- Title ---
                  Text(
                    asset['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // --- Status Tag ---
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

// --- 4. Custom Widget for the Status Tag ---
class StatusTag extends StatelessWidget {
  final String status;
  const StatusTag({super.key, required this.status});

  // Get color based on status
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
        status, // "available", "borrowed", etc.
        style: TextStyle(
          color: _getColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}