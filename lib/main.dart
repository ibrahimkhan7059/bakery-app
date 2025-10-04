// import 'package:bake_hub/screens/splash_screen.dart'; // Removed for now
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/search_screen.dart';
import 'screens/bulk_order_screen.dart';
import 'screens/cake_customization_screen.dart';
import 'screens/custom_cake_options_screen.dart';
import 'screens/ai_matching_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/payment_demo_screen.dart'; // Payment demo screen
import 'theme/app_theme.dart';
import 'screens/product_detail_screen.dart'; // Import the ProductDetailScreen
import 'models/product.dart'; // Import the Product model

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style globally for smooth transitions
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Enable smooth system UI transitions
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.bottom],
  );

  runApp(const BakeHubApp());
}

class BakeHubApp extends StatelessWidget {
  const BakeHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakeHub',
      theme: AppTheme.bakePanelTheme,
      home: const SplashScreen(),
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/cart': (context) => const CartScreen(),
        '/bulk-order': (context) => const BulkOrderScreen(),
        '/cake-customization': (context) => const CakeCustomizationScreen(),
        '/custom-cake-options': (context) => const CustomCakeOptionsScreen(),
        '/ai-matching': (context) => const AIMatchingScreen(),
        '/menu': (context) => const MenuScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/product-detail': (context) {
          final product = ModalRoute.of(context)!.settings.arguments as Product;
          return ProductDetailScreen(product: product);
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
