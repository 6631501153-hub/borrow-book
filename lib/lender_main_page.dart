// lib/lender_main_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/lender_history.dart';
import 'package:flutter_application_1/lender_home.dart';
import 'package:flutter_application_1/lender_notifications.dart';
import 'package:flutter_application_1/lender_dashboard.dart'; // <-- 1. Make sure this import is here
import 'package:flutter_application_1/login.dart';
import 'package:flutter_application_1/main.dart';

class LenderMainPage extends StatefulWidget {
  const LenderMainPage({super.key});

  @override
  State<LenderMainPage> createState() => _LenderMainPageState();
}

class _LenderMainPageState extends State<LenderMainPage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const LenderHomePage(), // Index 0: Home

    // --- 2. Make sure this line is correct ---
    const LenderDashboardPage(), 
    const LenderNotificationsPage(),
    const LenderHistoryPage(),
    const Center(
      child: Text('Lender History Page (Coming Soon)'),
    ), // Index 3: History
    
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
            icon: Icon(Icons.notifications),
            label: 'Requests',
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