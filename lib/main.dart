import 'package:flutter/material.dart';
import 'package:get/get.dart'; // GetX for navigation

void main() {
  runApp(const HobbyQuestApp());
}

class HobbyQuestApp extends StatelessWidget {
  const HobbyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HobbyQuest',
      theme: ThemeData(
        // purple (Primary Color)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const LoginScreen(), 
    );
  }
}

// Simple Placeholder for the Login Screen
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 100, color: Colors.purple),
            const SizedBox(height: 20),
            const Text(
              'HobbyQuest', 
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 50),
            // Email Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email',
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Password Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                obscureText: true, // Hides the password
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Login Button
            ElevatedButton(
              onPressed: () {
                print("Login button clicked!"); 
              },
              child: const Text('START YOUR QUEST'),
            ),
          ],
        ),
      ),
    );
  }
}