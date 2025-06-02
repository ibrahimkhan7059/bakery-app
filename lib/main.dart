// import 'package:bake_hub/screens/splash_screen.dart'; // Removed for now
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const BakeHubApp());
}

class BakeHubApp extends StatelessWidget {
  const BakeHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakeHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.bakePanelTheme,
      home: const SplashScreen(), // Changed back to SplashScreen
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        // Add other routes here if needed
      },
    );
  }
}
