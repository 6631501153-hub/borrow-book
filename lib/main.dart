// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/signup.dart';
 // <-- Fixed import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ --- PASTE YOUR URL AND ANON KEY HERE --- ⚠️
  await Supabase.initialize(
    url: 'https://wjlgarghubrdrnzresym.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqbGdhcmdodWJyZHJuenJlc3ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3MjM1ODksImV4cCI6MjA3NzI5OTU4OX0.xvB1FWm4bbFI6y6qgqLg2itwkmz50XO-WMwq1XLZUUM',
  );
  // ⚠️ --- (Find this in Supabase: Settings > API > Project API keys) --- ⚠️

  runApp(const MyApp());
}

// Get a global reference to the Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Borrow App',
      home: LoginPage(), // <-- Fixed class name
    );
  }
}