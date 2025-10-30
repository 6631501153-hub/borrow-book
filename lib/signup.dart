// lib/signup.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import the global 'supabase' client
import 'package:flutter_application_1/student_main_page.dart'; // Import the StudentMainPage

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // --- CHANGED --- Renamed _usernameController
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController(); // <-- Renamed
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  Future<void> _onSignUpPressed() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // --- CHANGED --- Pass the student ID to the function
    final error = await _handleStudentSignUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      studentId: _studentIdController.text.trim(), // <-- Renamed
    );

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StudentMainPage()),
        );
      }
    } else {
      _showErrorDialog(error);
    }
  }

  // --- CHANGED --- Updated the function parameter and insert query
  Future<String?> _handleStudentSignUp({
    required String email,
    required String password,
    required String name,
    required String studentId, // <-- Renamed
  }) async {
    try {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      final newUserId = authResponse.user?.id;

      if (newUserId != null) {
        await supabase.from('users').insert({
          'id': newUserId,
          'university_id': studentId, // <-- Renamed (Database column)
          'name': name,
          'role': 'student' 
        });
        debugPrint('Student sign up successful!');
        return null; 
      }
      return 'Sign up complete, but no user ID returned.';
    } catch (e) {
      debugPrint('Error during student sign up: $e');
      return e.toString(); 
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
            mainAxisAlignment:MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 80),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),

              // --- CHANGED --- Updated controller and label
              TextField(
                controller: _studentIdController, // <-- Renamed
                decoration: const InputDecoration(labelText: 'Student ID'), // <-- Renamed
              ),
              const SizedBox(height: 12),
              
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
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmPasswordObscured,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordObscured =
                            !_isConfirmPasswordObscured;
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
                onPressed: _isLoading ? null : _onSignUpPressed,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign up'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}