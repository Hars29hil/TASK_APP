import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _isGoogleInitialized = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isLogin) {
        // --- LOGIN FLOW ---
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        // --- REGISTRATION FLOW ---
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );

        final user = response.user;
        if (user != null) {
          // Immediately create user profile in public.profiles table
          try {
            await supabase.from('profiles').insert({
              'id': user.id,
              'full_name': name,
              'email': email,
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (dbError) {
            debugPrint("Database profile creation failed: $dbError");
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registration successful! Please log in."),
              backgroundColor: AppColors.emerald,
            ),
          );
          setState(() {
            _isLogin = true;
            _isLoading = false;
            _passwordController.clear();
          });
        }
      }
    } catch (e) {
      debugPrint("Authentication Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AuthException ? e.message : "Authentication failed: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
        );
        return;
      }

      const webClientId = '641104976519-dm4mmkivc48b7c9jg1e2o93umupjmhse.apps.googleusercontent.com';
      const iosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com'; // or null

      if (!_isGoogleInitialized) {
        await g_sign_in.GoogleSignIn.instance.initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
          serverClientId: webClientId,
        );
        _isGoogleInitialized = true;
      }

      final googleUser = await g_sign_in.GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) {
        throw 'Google Sign-In failed: user object is null';
      }

      // Check / Create profile row in profiles table
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        final meta = user.userMetadata ?? {};
        final name = meta['full_name'] ?? meta['name'] ?? user.email?.split('@')[0] ?? 'User';
        final avatarUrl = meta['avatar_url'] ?? meta['picture'] ?? '';

        await supabase.from('profiles').insert({
          'id': user.id,
          'full_name': name,
          'email': user.email ?? '',
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Sign-In Failed: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 48.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Headers
                      Text(
                        _isLogin ? "Welcome Back" : "Create Account",
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? "Sign in to access your workspace"
                            : "Register to start managing tasks",
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: CircularProgressIndicator(
                            color: AppColors.electricBlue,
                          ),
                        )
                      else ...[
                        // Full Name Input (Register Only)
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              hintText: "John Doe",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Please enter your name";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Input
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email",
                            hintText: "name@example.com",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return "Please enter your email";
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Input
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "••••••••",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Please enter your password";
                            }
                            if (val.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.electricBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isLogin ? "Log In" : "Register",
                              style: AppTypography.button.copyWith(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Divider OR
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text("OR", style: AppTypography.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Sign-In Button
                        _SocialButton(
                          text: "Continue with Google",
                          iconUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png",
                          onPressed: _signInWithGoogle,
                        ),
                        const SizedBox(height: 24),

                        // View Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "Don't have an account?" : "Already have an account?",
                              style: AppTypography.bodySmall,
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _formKey.currentState?.reset();
                                });
                              },
                              child: Text(
                                _isLogin ? "Register" : "Log In",
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.electricBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String text;
  final String iconUrl;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.text,
    required this.iconUrl,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(iconUrl, width: 24, height: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: AppTypography.button.copyWith(
                color: AppColors.ink,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
