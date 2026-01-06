import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/color_constants.dart';
import '../../routes/app_routes.dart'; // Import Routes
import '../widgets/mascot_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  // Logic variables
  late bool isRegisterMode;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // ✅ Read the arguments passed from Welcome Page
    // If no arguments (default), assume Login mode (false)
    final args = Get.arguments ?? {};
    isRegisterMode = args['isRegistering'] ?? false;
  }

  Future<void> handleAuth() async {
    setState(() => isLoading = true);
    
    try {
      if (isRegisterMode) {
        // REGISTER
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        Get.snackbar("Success", "Character Created!", backgroundColor: AppColors.success, colorText: Colors.white);
        
        // ✅ Go to Onboarding (Named Route)
        Get.offAllNamed(AppRoutes.ONBOARDING); 
      } else {
        // LOGIN
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        Get.snackbar("Welcome Back", "Resuming your quest...", backgroundColor: AppColors.accent, colorText: Colors.white);
        
        // TODO: Get.offAllNamed(AppRoutes.HOME);
      }
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Oops!", e.message ?? "Something went wrong.", 
        backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRegisterMode ? "Create Character" : "Resume Game"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            MascotWidget(
              emotion: isRegisterMode ? 'happy' : 'thinking',
              message: isRegisterMode 
                ? "A new adventurer! Enter your details to start." 
                : "Welcome back, Hunter! Enter your credentials.",
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55, // Taller button
              child: ElevatedButton(
                onPressed: isLoading ? null : handleAuth,
                child: isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(isRegisterMode ? 'START GAME' : 'LOGIN'),
              ),
            ),
            
            const SizedBox(height: 15),
            
            TextButton(
              onPressed: () {
                setState(() => isRegisterMode = !isRegisterMode);
              },
              child: Text(
                isRegisterMode ? 'Already have a save file? Login' : 'New player? Create Account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}