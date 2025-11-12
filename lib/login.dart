// lib/login.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import the global 'supabase' client

// --- THIS IS THE FIX ---
// Add imports for all your pages
import 'package:flutter_application_1/student_main_page.dart' as student_page; // <-- For students
import 'package:flutter_application_1/signup.dart'; 

// --- END OF FIX ---


    

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _hidePw = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;

    setState(() => _loading = true);
    try {
      // Sign in with Supabase Auth
      await supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const student_page.StudentMainPage()),
      );
    } catch (e) {
      _alert(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _alert(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alert'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F2F7); // soft pastel like your screenshot

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    const Icon(Icons.bookmark, size: 80, color: Colors.black87),
                    const SizedBox(height: 36),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: _hidePw,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const UnderlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePw ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _hidePw = !_hidePw),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 28),

                    // Log in button (pill shape)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          elevation: 0,
                          backgroundColor: Colors.white.withOpacity(0.7),
                          foregroundColor: const Color(0xFF5A4FBF),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Create new account
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              ),
                      child: const Text(
                        'Create new account',
                        style: TextStyle(
                          color: Color(0xFF5A4FBF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}






