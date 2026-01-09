import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/utils/validators.dart'; // Using your custom validator file
import '../../routes/app_routes.dart'; 
import '../widgets/mascot_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // GlobalKey is needed to identify the Form and trigger validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to retrieve text from input fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  // State variables to manage UI mode and loading status
  late bool isRegisterMode;
  bool isLoading = false;
  bool isPasswordVisible = false; 

  @override
  void initState() {
    super.initState();
    // Retrieve arguments passed from the Welcome Page
    // Defaults to 'false' (Login mode) if no arguments are found
    final args = Get.arguments ?? {};
    isRegisterMode = args['isRegistering'] ?? false;
  }

  @override
  void dispose() {
    // Dispose controllers to free up memory when the widget is removed
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Main Authentication Function
  Future<void> handleAuth() async {
    print("--- AUTH PROCESS STARTED ---"); // Debug: Start

    // Step 1: Run Validation
    // This checks the rules in validators.dart (Email format, Password length)
    if (!_formKey.currentState!.validate()) {
      print("--- ERROR: Validation Failed ---"); // Debug: Validation Error
      return;
    }

    // Step 2: Dismiss Keyboard
    // This improves UX by allowing the user to see the loading state/messages
    FocusManager.instance.primaryFocus?.unfocus();

    // Step 3: Update State to Loading
    // This disables the button and shows the spinner
    print("--- STATUS: Setting Loading State ---");
    setState(() => isLoading = true);
    
    try {
      if (isRegisterMode) {
        // --- REGISTER FLOW ---
        print("--- ACTION: Attempting Registration ---"); // Debug: Action Type
        
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        
        print("--- SUCCESS: User Registered ---"); // Debug: Success
        
        if (mounted) {
          Get.snackbar(
            "Success", 
            "Character Created!", 
            backgroundColor: AppColors.success, 
            colorText: Colors.white
          );
          // Navigate to Onboarding (Removes previous routes to prevent back button issues)
          Get.offAllNamed(AppRoutes.ONBOARDING); 
        }

      } else {
        // --- LOGIN FLOW ---
        print("--- ACTION: Attempting Login ---"); // Debug: Action Type
        
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        print("--- SUCCESS: User Logged In ---"); // Debug: Success

        if (mounted) {
          Get.snackbar(
            "Welcome Back", 
            "Resuming your quest...", 
            backgroundColor: AppColors.accent, 
            colorText: Colors.white
          );
          // Navigate to Home Dashboard
          Get.offAllNamed(AppRoutes.HOME); 
        }
      }
    } on FirebaseAuthException catch (e) {
      // Step 4: Handle Specific Firebase Errors
      // This provides user-friendly messages based on the error code
      print("--- FIREBASE EXCEPTION: ${e.code} ---"); // Debug: Firebase Error Code
      
      String message = "Authentication failed.";
      if (e.code == 'user-not-found') message = "No hero found with that email.";
      if (e.code == 'wrong-password') message = "Wrong password!";
      if (e.code == 'email-already-in-use') message = "That email is already taken!";
      if (e.code == 'network-request-failed') message = "Check your internet connection!";
      if (e.code == 'invalid-email') message = "The email address is badly formatted.";
      
      Get.snackbar(
        "Error", 
        message, 
        backgroundColor: AppColors.error, 
        colorText: Colors.white
      );
        
    } catch (e) {
      // Step 5: Handle Generic Errors
      // Catches unexpected crashes or system errors
      print("--- UNKNOWN EXCEPTION: $e ---"); // Debug: Generic Error
      
      Get.snackbar(
        "Error", 
        "Something unexpected happened: $e", 
        backgroundColor: AppColors.error, 
        colorText: Colors.white
      );
        
    } finally {
      // Step 6: Reset Loading State
      // This runs regardless of success or failure to ensure the button unlocks
      print("--- STATUS: Resetting Loading State ---"); // Debug: Cleanup
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(isRegisterMode ? "Create Character" : "Resume Game"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // Connects the Form validation logic
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mascot Widget
                // Note: Emotion is hardcoded to 'happy' to prevent Rive asset crashes
                MascotWidget(
                  //emotion: isLoading ? 'thinking' : 'happy',
                  emotion: 'happy', 
                  message: isRegisterMode 
                    ? "Let's set up your profile! I need an email to save your game." 
                    : "Welcome back! Enter your login details to continue.",
                ),
                const SizedBox(height: 30),
                
                // Email Input Field
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  // Using external validator from validators.dart
                  validator: Validators.validateEmail, 
                ),
                const SizedBox(height: 20),
                
                // Password Input Field
                TextFormField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible, // Toggles text visibility
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      // Toggle Eye Icon
                      icon: Icon(isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                    ),
                  ),
                  // Using external validator from validators.dart
                  validator: Validators.validatePassword, 
                ),
                
                const SizedBox(height: 30),

                // Main Action Button (Login / Register)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    // Disable button if loading to prevent double-clicks
                    onPressed: isLoading ? null : handleAuth,
                    child: isLoading 
                      ? const SizedBox(
                          height: 24, width: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                        ) 
                      : Text(isRegisterMode ? 'START GAME' : 'LOGIN'),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Mode Toggle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isRegisterMode ? "Already have a save file?" : "New adventurer?",
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        // Reset validation errors when switching modes
                        _formKey.currentState?.reset(); 
                        setState(() => isRegisterMode = !isRegisterMode);
                      },
                      child: Text(
                        isRegisterMode ? "Login Here" : "Create Account",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}