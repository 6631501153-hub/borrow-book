// // lib/student_main_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/login.dart'; // To go back to login on logout
import 'package:flutter_application_1/main.dart'; // For supabase
import 'package:flutter_application_1/student_home.dart'; // Your page with the grid
// We will create these two placeholder pages next
import 'package:flutter_application_1/student_notifications.dart';
import 'package:flutter_application_1/student_history.dart';
class StudentMainPage extends StatefulWidget {
  const StudentMainPage({super.key});

  @override
  State<StudentMainPage> createState() => _StudentMainPageState();
}

class _StudentMainPageState extends State<StudentMainPage> {
  // This keeps track of which tab is active (0 = Home)
  int _selectedIndex = 0;

  // This is the list of pages the bottom bar will switch between
  static const List<Widget> _pages = <Widget>[
    StudentHomePage(), // Index 0
    StudentNotificationsPage(), // Index 1
    StudentHistoryPage(), // Index 2
    // Index 3 is the logout button, it doesn't need a page
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      // If "Logout" is tapped
      _signOut();
    } else {
      // If Home, Bell, or History is tapped
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut(); // Logs the user out
    
    // Go back to the login page
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body is the content of the active tab
      body: _pages.elementAt(_selectedIndex),
      
      // This is your new bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
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
        // This is what makes the active icon have a different color
        selectedItemColor: Colors.blue, // You can change this color
        unselectedItemColor: Colors.grey, // The color for inactive icons
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensures all 4 icons show
      ),
    );
  }
}

