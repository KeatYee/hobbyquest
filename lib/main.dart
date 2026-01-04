import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Firebase Auth

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HobbyQuestApp());
}

class HobbyQuestApp extends StatelessWidget {
  const HobbyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HobbyQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controllers capture what you type
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // 2. The Logic to talk to Firebase
  Future<void> handleAuth(bool isRegistering) async {
    try {
      if (isRegistering) {
        // Create new account
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        Get.snackbar("Success", "Account Created! You can now login.");
      } else {
        // Login existing user
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        Get.snackbar("Success", "Welcome back, Hunter!");
        // TODO: Navigate to Home Screen here later
      }
    } on FirebaseAuthException catch (e) {
      // If something goes wrong (wrong password, etc.)
      Get.snackbar("Error", e.message ?? "Authentication failed", 
        backgroundColor: Colors.red.withOpacity(0.5), colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gamepad, size: 100, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text('HobbyQuest', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              
              // Email Input
              TextField(
                controller: emailController, // Connected!
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              
              // Password Input
              TextField(
                controller: passwordController, // Connected!
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity, // Make button wide
                height: 50,
                child: ElevatedButton(
                  onPressed: () => handleAuth(false), // Call Login Logic
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  child: const Text('LOGIN'),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // REGISTER BUTTON
              TextButton(
                onPressed: () => handleAuth(true), // Call Register Logic
                child: const Text('New player? Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}