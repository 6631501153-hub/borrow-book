// lib/admin_setup.dart
import 'package:supabase/supabase.dart'; // <-- Make sure there is no typo here
import 'dart:io'; // Used for exit()

const supabaseUrl = 'https://wjlgarghubrdrnzresym.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqbGdhcmdodWJyZHJuenJlc3ltIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTcyMzU4OSwiZXhwIjoyMDc3Mjk5NTg5fQ.3I7ggDFxwbx6i91pN8B4-duxLWoU6fCyIIuzw2UebGs';

// Get the client instance
final client = SupabaseClient(supabaseUrl, supabaseServiceKey);

// --- Reusable Function to Create Any User ---
Future<void> createUser({
  required String email,
  required String password,
  required String universityId,
  required String name,
  required String role,
}) async {
  try {
    print('Attempting to create "$role" user ($email)...');

    // 1. Create the secure auth user using the ADMIN method
    final authResponse = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true, // Automatically confirm the email
      ),
    );
    
    final userId = authResponse.user?.id;

    // 2. Create the public profile
    if (userId != null) {
      await client.from('users').insert({
        'id': userId,
        'university_id': universityId,
        'name': name,
        'role': role
      });
      print('✅ User "$role" ($email) created successfully!');
    } else {
      print('Auth user created for $email, but ID was null.');
    }
  } catch (e) {
    print('❌ Error creating user "$role" ($email): $e');
  }
}

Future<void> main() async {
  print('Admin script started. Connecting to Supabase...');

  // --- Call the function to create your users ---
  await createUser(
    email: 'lender2@test.com',
    password: '123456',
    universityId: 'LENDER002',
    name: 'Ms. Lender',
    role: 'lender',
  );

  await createUser(
    email: 'staff2@test.com',
    password: '123456',
    universityId: 'STAFF002',
    name: 'Mr. Staff',
    role: 'staff',
  );

  print('\nAdmin script finished.');
  exit(0); // Exit the script
}