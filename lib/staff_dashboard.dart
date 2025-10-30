// lib/staff_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // For supabase
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  // This Future will hold our data
  late final Future<Map<String, int>> _dashboardData;

  @override
  void initState() {
    super.initState();
    // Initialize the data fetch on startup
    _dashboardData = _fetchDashboardData();
  }

  /// Fetches ALL assets and counts them by status (suitable for Staff/Admin)
  Future<Map<String, int>> _fetchDashboardData() async {
    // STAFF Dashboard must NOT filter by user ID.
    // It is designed to see the status of the entire inventory.
    try {
      final response = await supabase.from('asset').select('status');

      // Initialize counters
      int total = 0;
      int borrowed = 0;
      int available = 0;
      int pending = 0;
      int disable = 0;

      // Loop through the results and count
      for (var asset in response) {
        total++; // Count total
        final status = asset['status'] as String?;
        switch (status) {
          case 'borrowed':
            borrowed++;
            break;
          case 'available':
            available++;
            break;
          case 'pending':
            pending++;
            break;
          case 'disable':
            disable++;
            break;
        }
      }

      // Return the data as a map
      return {
        'total': total,
        'borrowed': borrowed,
        'available': available,
        'pending': pending,
        'disable': disable,
      };
    } catch (e) {
      // Re-throw the error so FutureBuilder can catch and display it
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _dashboardData,
      builder: (context, snapshot) {
        // --- 1. Loading State ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- 2. Error State ---
        if (snapshot.hasError) {
          debugPrint('Staff Dashboard Fetch Error: ${snapshot.error}');
          return Center(child: Text('Error loading data: ${snapshot.error}. Check RLS policy on "asset" table.'));
        }

        // --- 3. No Data State ---
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No asset data found.'));
        }

        // --- 4. Success State ---
        final data = snapshot.data!;
        final total = data['total'] ?? 0;
        final borrowed = data['borrowed'] ?? 0;
        final available = data['available'] ?? 0;
        final pending = data['pending'] ?? 0;
        final disable = data['disable'] ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Title ---
              const Text(
                'Staff Dashboard (All Assets)', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // --- Total Box ---
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'total book : $total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),

              // --- Stat Boxes Grid ---
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'borrowed $borrowed',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'available $available',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'pending $pending',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'disable $disable',
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper widget to build one of the colored stat cards
  Widget _buildStatCard(String text, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}