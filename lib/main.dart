// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/login.dart';      // your login screen
// import 'package:flutter_application_1/sign_up_page.dart'; // use this instead if you want to start at SignUpPage

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://kmmunkvmbrfhoedeancl.supabase.co',     // 🔹 Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImttbXVua3ZtYnJmaG9lZGVhbmNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxODg2NTMsImV4cCI6MjA3Nzc2NDY1M30.KqAWue0NjnZEtnsP78d8aXNX5Db6FyBYuKTmbf8R_pU',               // 🔹 Replace with your anon key
  );

  runApp(const MyApp());
}

// Create a global Supabase client to access anywhere
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Asset Borrowing System',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF6F2F7),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black87),
        ),
      ),
      home: const LoginPage(), // or const SignUpPage()
    );
  }
}

