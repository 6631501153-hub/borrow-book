// lib/staff_main_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/login.dart';
import 'package:flutter_application_1/main.dart'; // For supabase

// --- UPDATED IMPORTS ---
import 'package:flutter_application_1/staff_home.dart';       // New name
import 'package:flutter_application_1/lender_dashboard.dart';// Same name
import 'package:flutter_application_1/staff_return.dart';    // New name
import 'package:flutter_application_1/staff_history.dart';

class StaffMainPage extends StatefulWidget {
  const StaffMainPage({super.key});

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const StaffHomePage(), // Index 0: Home

    // --- 2. Make sure this line is correct ---
    const LenderDashboardPage(), // Index 1: Dashboard

    const StaffReturnPage(), // Index 2: Notifications

    const StaffHistoryPage(), // Index 3: History
    
    Container(), // Index 4 (for logout action)
  ];

  void _onItemTapped(int index) async {
    if (index == 4) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view), // This is the Dashboard icon
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Return',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}