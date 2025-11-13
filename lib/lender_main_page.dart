import 'package:flutter/material.dart';
import 'package:flutter_application_1/lender_history.dart';
import 'package:flutter_application_1/lender_home.dart';
import 'package:flutter_application_1/lender_notifications.dart';
import 'package:flutter_application_1/login.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/lender_dashboard.dart';

class LenderMainPage extends StatefulWidget {
  const LenderMainPage({super.key});
  @override
  State<LenderMainPage> createState() => _LenderMainPageState();
}

class _LenderMainPageState extends State<LenderMainPage> {
  int _selectedIndex = 0;

  bool _checkingRole = true;
  String? _roleError;

  @override
  void initState() {
    super.initState();
    _ensureLenderRole();
  }

  Future<void> _ensureLenderRole() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        _goLogin();
        return;
      }
      // Fetch role from your users table (id UUID, role TEXT)
      final rows = await supabase.from('users').select('role').eq('id', uid).limit(1);
      String? role;
      if (rows is List && rows.isNotEmpty) {
        role = (rows.first['role'] as String?)?.toLowerCase();
      }
      if (role != 'lender') {
        _goLogin();
        return;
      }
    } catch (e) {
      _roleError = e.toString();
    } finally {
      if (mounted) setState(() => _checkingRole = false);
    }
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  late final List<Widget> _pages = <Widget>[
    const LenderHomePage(),          // 0: Home
    const LenderDashboardPage(),     // 1: Dashboard
    const LenderNotificationsPage(), // 2: Requests
    const LenderHistoryPage(),       // 3: History
    const SizedBox.shrink(),         // 4: Logout action placeholder
  ];

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      _handleLogout();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _roleError == null
            ? _pages[_selectedIndex]
            : Center(
                child: Text(
                  'Role check failed.\n$_roleError',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
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