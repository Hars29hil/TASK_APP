import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  bool _isGoogleInitialized = false;
  bool _isLogin = true; // Toggle for visual state

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Success will automatically be handled by auth state listener
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn && data.session != null) {
        _handleSuccessfulLogin();
      }
    });
  }

  Future<void> _handleSuccessfulLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Check if user profile exists
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 2. Insert if not exists
      if (profileResponse == null) {
        // Extract meta data
        final meta = user.userMetadata ?? {};
        final name =
            meta['full_name'] ??
            meta['name'] ??
            user.email?.split('@')[0] ??
            'User';
        // Note: If avatar and provider columns don't exist in Supabase, this will fail.
        // In Supabase Auth, they can just be fetched from user metadata.

        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'full_name': name,
          'email': user.email ?? '',
          'role': 'user', // Default role
          // Note: If avatar and provider columns don't exist in Supabase, this will fail.
          // In Supabase Auth, they can just be fetched from user metadata.
          // But to strictly follow the user's requirement, we will try to save them if added.
          // 'avatar_url': avatarUrl,
        });
      }

      // 3. Get FCM Token & update profile
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("Failed to get FCM token: $e");
      }

      if (fcmToken != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': fcmToken})
            .eq('id', user.id);
      }

      // Navigate to Dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error handling login: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error setting up profile: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  /// Google Sign In logic utilizing Supabase's built-in Google Auth or google_sign_in package
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Use Supabase native OAuth flow for Web (redirects the browser)
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
        );
        // Execution stops here because the browser redirects.
        return;
      }

      const webClientId =
          '105578954002-reeatjhfeu2glt1mb2nadqs8mqs7ct1d.apps.googleusercontent.com'; // Replace with real one
      const iosClientId =
          'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com'; // Replace with real one

      if (!_isGoogleInitialized) {
        await g_sign_in.GoogleSignIn.instance.initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? iosClientId
              : null,
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

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Google Sign-In Failed: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  /// Apple Sign In logic utilizing Supabase
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = Supabase.instance.client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Could not find ID Token from Apple Sign In.',
        );
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Apple Sign-In Failed: $e")));
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo or Header
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.electricBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.task_alt_rounded,
                          size: 40,
                          color: AppColors.electricBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _isLogin ? "Welcome back" : "Create an Account",
                      style: AppTypography.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? "Sign in to access your workspace"
                          : "Sign up to get started",
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.electricBlue,
                        ),
                      )
                    else ...[
                      if (_isLogin) ...[
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signInWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.electricBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              "Log In",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text("OR", style: AppTypography.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      _SocialButton(
                        text: _isLogin
                            ? "Continue with Google"
                            : "Sign up with Google",
                        iconUrl:
                            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png",
                        onPressed: _signInWithGoogle,
                      ),
                      const SizedBox(height: 16),
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform == TargetPlatform.macOS))
                        _SocialButton(
                          text: _isLogin ? "Continue with Apple" : "Sign up with Apple",
                          iconData: Icons.apple,
                          onPressed: _signInWithApple,
                        ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Don't have an account?"
                                : "Already have an account?",
                            style: AppTypography.bodySmall,
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin ? "Sign up" : "Log in",
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
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String text;
  final String? iconUrl;
  final IconData? iconData;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.text,
    this.iconUrl,
    this.iconData,
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
            if (iconUrl != null)
              Image.network(iconUrl!, width: 24, height: 24)
            else if (iconData != null)
              Icon(iconData, size: 28, color: Colors.black),
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
