import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;

  // Backend URL loaded dynamically from .env
  String get _baseUrl {
    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    return 'http://localhost:5000';
  } 

  Future<void> _sendOTP() async {
    if (_emailController.text.isEmpty || _nameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        _showOTPDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed to send OTP")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTPAndRegister() async {
    setState(() => _isLoading = true);

    try {
      // 1. First, verify the OTP with your backend
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'otp': _otpController.text,
          'fullName': _nameController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // The backend has already created the user via admin.createUser
        // So we just need to log in locally to get the session
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          if (!mounted) return;
          Navigator.pop(context); // Close OTP Dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account verified and logged in!")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } catch (authError) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login failed: $authError")),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "OTP Verification failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter OTP"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("An OTP has been sent to your email."),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "6-digit OTP"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _verifyOTPAndRegister,
            child: const Text("Verify & Register"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.soft,
                ),
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create Account",
                      style: AppTypography.h1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Welcome! Please fill the form to register.",
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    // Name Field
                    Text("Full Name", style: AppTypography.labelMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: "Jane Doe",
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.electricBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Email Field
                    Text("Email", style: AppTypography.labelMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: "you@example.com",
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.electricBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    Text("Password", style: AppTypography.labelMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.electricBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
                          : ElevatedButton(
                              onPressed: _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.electricBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Register",
                                style: AppTypography.button.copyWith(color: Colors.white),
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ", style: AppTypography.bodyMedium),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Login",
                            style: AppTypography.labelLarge.copyWith(color: AppColors.electricBlue),
                          ),
                        ),
                      ],
                    ),
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
