// lib/login.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import the global 'supabase' client

// --- THIS IS THE FIX ---
// Add imports for all your pages
import 'package:flutter_application_1/student_main_page.dart'; // <-- For students
import 'package:flutter_application_1/lender_main_page.dart';
import 'package:flutter_application_1/signup.dart'; 
import 'package:flutter_application_1/staff_main_page.dart';
// --- END OF FIX ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true; 

  Future<void> _signInAndNavigate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Sign in the user
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final userId = authResponse.user?.id;
      if (userId == null) {
        throw Exception('Login successful, but no user ID found.');
      }

      // 2. Fetch the user's role from your 'users' table
      final userProfile = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      
      final role = userProfile['role'];

      // 3. Navigate based on the role
      if (mounted) {
        switch (role) {
          // --- THIS IS THE FIX ---
          case 'student':
            Navigator.of(context).pushReplacement(
              // Go to the main page with the nav bar
              MaterialPageRoute(builder: (context) => const StudentMainPage()), 
            );
            break;
          // --- END OF FIX ---
          case 'lender':
            Navigator.of(context).pushReplacement(
              // CORRECT: This page has the Scaffold
              MaterialPageRoute(builder: (context) => const LenderMainPage()), 
            );
            break;
          case 'staff':
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const StaffMainPage()),
            );
            break;
          default:
            _showErrorDialog('Unknown role: $role');
        }
      }

    } catch (error) {
      _showErrorDialog('Login failed: ${error.toString()}');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Alert'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book, size: 80),
              const SizedBox(height: 20),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: _isPasswordObscured, 
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _signInAndNavigate,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Log in'),
              ),
              
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                  );
                },
                child: const Text('Create new account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}