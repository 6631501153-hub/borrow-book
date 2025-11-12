import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // global 'supabase' client

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _isLoading = false;
  bool _hidePw = true;
  bool _hidePw2 = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;

    if (_pwCtrl.text != _pw2Ctrl.text) {
      _alert('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1) Sign up with Supabase Auth and include metadata.
      //    Your DB trigger on auth.users will copy these into public.users
      //    and link via the same UUID (FK).
      await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
        data: {
          'name': _nameCtrl.text.trim(),
          'university_id': _studentIdCtrl.text.trim(),
        },
      );

      if (!mounted) return;

      // 2) Tell the user and go back to Sign In
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please sign in.'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(); // back to Sign In page
    } catch (e) {
      _alert(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final email = v.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return ok ? null : 'Invalid email';
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF6F2F7); // pastel background

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    const Icon(Icons.person, size: 80, color: Colors.black87),
                    const SizedBox(height: 28),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: UnderlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),

                    // Student ID
                    TextFormField(
                      controller: _studentIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Student ID',
                        border: UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 12),

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
                          onPressed: () =>
                              setState(() => _hidePw = !_hidePw),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.length < 6)
                              ? 'At least 6 characters'
                              : null,
                    ),
                    const SizedBox(height: 12),

                    // Confirm password
                    TextFormField(
                      controller: _pw2Ctrl,
                      obscureText: _hidePw2,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        border: const UnderlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePw2
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _hidePw2 = !_hidePw2),
                        ),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 28),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
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
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign up'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Log In link
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Already have an account? Log in',
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

