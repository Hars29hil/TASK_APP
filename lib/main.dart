import 'package:flutter/material.dart';
import 'screens/registration_screen.dart';
import 'screens/dashboard_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(); // Default looks for .env
    debugPrint(".env loaded successfully");
  } catch (e) {
    debugPrint("CRITICAL: Error loading .env file: $e");
  }

  // Initialize Supabase with safety checks
  final url = dotenv.maybeGet('SUPABASE_URL');
  final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

  if (url != null && anonKey != null) {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    } catch (e) {
      debugPrint("Error initializing Supabase: $e");
    }
  } else {
    debugPrint("CRITICAL: Supabase keys are missing from .env!");
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    
    // Register background handler BEFORE runApp
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Request permission and setup other listeners
    await _setupFCM();
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

Future<void> _setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Request Permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  debugPrint("User granted permission: ${settings.authorizationStatus}");

  // Get FCM Token and print it as requested
  try {
    String? token = await messaging.getToken();
    debugPrint("FCM Token: $token");
  } catch (e) {
    debugPrint("Error getting FCM token: $e");
  }

  // Helper function to update token in Supabase
  Future<void> updateTokenInDB(String userId) async {
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint("Updating FCM Token in DB: $token");
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }

  // 3. Update token immediately if user is already logged in
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    updateTokenInDB(currentUser.id);
  }

  // 4. Listen for Auth State Changes (Login/Logout)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final userId = data.session?.user.id;
    if (userId != null) {
      updateTokenInDB(userId);
    }
  });

  // 5. Handle Foreground Messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Foreground message: ${message.notification?.title}");
    // You could show a local notification here if needed
  });

  // 6. Handle Notification Taps (when app is in background but not terminated)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("Notification tapped: ${message.data}");
  });

  // 7. Handle initial message (when app was terminated)
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint("App launched from terminated state via notification: ${initialMessage.data}");
  }
}

// Global background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if there is an active session
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anand Swami App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: session != null ? const DashboardScreen() : const RegistrationScreen(),
    );
  }
}
