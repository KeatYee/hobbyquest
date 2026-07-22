import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../widgets/mascot_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _currentGoogleUser;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventSubscription;

  bool _isInitialized = false;

  late bool isRegisterMode;
  bool isLoading = false;
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();

    final args = Get.arguments ?? {};
    isRegisterMode = args['isRegistering'] ?? false;
  }

  /// Initialize Google Sign-In and listen to authentication events
  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();

      _authEventSubscription = _googleSignIn.authenticationEvents.listen((
        event,
      ) {
        if (!mounted) return;

        setState(() {
          _currentGoogleUser = switch (event) {
            GoogleSignInAuthenticationEventSignIn() => event.user,
            GoogleSignInAuthenticationEventSignOut() => null,
          };
        });
        print(
          "--- GOOGLE AUTH EVENT: ${_currentGoogleUser?.email ?? 'signed out'} ---",
        );
      });

      _isInitialized = true;
      print("--- GOOGLE SIGN-IN INITIALIZED ---");
    } catch (e) {
      print("--- ERROR: Failed to initialize Google Sign-In: $e ---");
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _authEventSubscription?.cancel();

    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleAuth() async {
    print("--- AUTH PROCESS STARTED ---");

    if (!_formKey.currentState!.validate()) {
      print("--- ERROR: Validation Failed ---");
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    print("--- STATUS: Setting Loading State ---");
    setState(() => isLoading = true);

    try {
      if (isRegisterMode) {
        print("--- ACTION: Attempting Registration ---");

        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        print("--- SUCCESS: User Registered ---");

        if (mounted) {
          AppDialogs.success("Success", "Character Created!");
          Get.offAllNamed(AppRoutes.ONBOARDING);
        }
      } else {
        print("--- ACTION: Attempting Login ---");

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        print("--- SUCCESS: User Logged In ---");

        if (mounted) {
          AppDialogs.info("Welcome Back", "Resuming your quest...");
          await Get.find<AuthController>().checkUserStatus();
        }
      }
    } on FirebaseAuthException catch (e) {
      print("--- FIREBASE EXCEPTION: ${e.code} ---");

      String message = "Authentication failed.";
      if (e.code == 'user-not-found')
        message = "No user found with that email.";
      if (e.code == 'wrong-password') message = "Wrong password!";
      if (e.code == 'email-already-in-use')
        message = "That email is already taken!";
      if (e.code == 'network-request-failed')
        message = "Check your internet connection!";
      if (e.code == 'invalid-email')
        message = "The email address is badly formatted.";

      AppDialogs.error("Error", message);
    } catch (e) {
      print("--- UNKNOWN EXCEPTION: $e ---");

      AppDialogs.error("Error", "Something unexpected happened: $e");
    } finally {
      print("--- STATUS: Resetting Loading State ---");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleGoogleSignIn() async {
    print("--- GOOGLE SIGN-IN STARTED ---");

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => isLoading = true);

    try {
      if (!_isInitialized) {
        await Future.delayed(const Duration(seconds: 1));
      }

      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate(scopeHint: ['email', 'profile']);
        print("--- GOOGLE AUTHENTICATE COMPLETED ---");
      } else {
        throw Exception(
          'This platform does not support Google Sign-In authenticate()',
        );
      }

      int attempts = 0;
      while (_currentGoogleUser == null && attempts < 5) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      final googleUser = _currentGoogleUser;

      if (googleUser == null) {
        print("--- GOOGLE SIGN-IN CANCELLED ---");
        return;
      }

      print("--- GOOGLE USER: ${googleUser.email} ---");

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      print("--- FIREBASE SIGN-IN SUCCESS ---");

      if (mounted) {
        AppDialogs.info("Welcome", "Google account linked successfully.");

        await Get.find<AuthController>().checkUserStatus();
      }
    } on FirebaseAuthException catch (e) {
      print("--- FIREBASE AUTH EXCEPTION: ${e.code} ---");

      String message = "Google sign-in failed.";
      if (e.code == 'account-exists-with-different-credential') {
        message = "That email is already linked to another sign-in method.";
      } else if (e.code == 'network-request-failed') {
        message = "Check your internet connection!";
      }

      AppDialogs.error("Error", message);
    } catch (e) {
      print("--- GOOGLE SIGN-IN EXCEPTION: $e ---");

      AppDialogs.error("Error", "Something unexpected happened: $e");
    } finally {
      print("--- GOOGLE SIGN-IN COMPLETE ---");
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
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotWidget(
                  emotion: 'happy',
                  message: isRegisterMode
                      ? "Let's set up your profile! I need an email to save your game."
                      : "Welcome back! Enter your login details to continue.",
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => isPasswordVisible = !isPasswordVisible,
                      ),
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleAuth,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.textOnPrimary,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(isRegisterMode ? 'START GAME' : 'LOGIN'),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : handleGoogleSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('CONTINUE WITH GOOGLE'),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isRegisterMode
                          ? "Already have a save file?"
                          : "New adventurer?",
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
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
