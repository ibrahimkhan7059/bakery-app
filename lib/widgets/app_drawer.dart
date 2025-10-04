import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/my_orders_screen.dart'; // Import MyOrdersScreen

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isLoggedIn = false;
  String _userName = 'Guest';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkLoginStatus(); // Refresh login status when drawer opens
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Try both possible token keys for compatibility
    final token = prefs.getString('authToken') ?? prefs.getString('auth_token');
    final userName = prefs.getString('user_name');

    print('AppDrawer - Token found: ${token != null}');
    print('AppDrawer - User name: $userName');

    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _userName = userName ?? 'Guest';
    });
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove both possible token keys for cleanup
      await prefs.remove('authToken');
      await prefs.remove('auth_token');
      await prefs.remove('user_name');
      await prefs.remove('user_id');
      await prefs.remove('user_email');

      print('AppDrawer - Logout completed, all keys cleared');

      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userName = 'Guest';
        });

        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Logout error: $e');
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About BakeHub'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Logo/Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.cake,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App Name & Version
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'BakeHub',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  'BakeHub is your ultimate destination for fresh, delicious baked goods. From artisanal breads to custom cakes, we bring the best of bakery delights right to your doorstep.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Features
                const Text(
                  'Features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Browse wide variety of baked goods\n'
                  '• AI-powered cake matching system\n'
                  '• Real-time order tracking\n'
                  '• Custom cake orders\n'
                  '• Secure payment options\n'
                  '• User-friendly interface',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Contact Info
                const Text(
                  'Contact Us:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Email: support@bakehub.com\n'
                  'Phone: +1 (555) 123-4567\n'
                  'Website: www.bakehub.com',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Copyright
                const Center(
                  child: Text(
                    '© 2025 BakeHub. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 35,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isLoggedIn ? 'Welcome!' : 'Hello!',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isLoggedIn ? _userName : 'BakeHub Customer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),

                // Profile (only show if logged in)
                if (_isLoggedIn)
                  ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: theme.primaryColor,
                    ),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),

                // Orders (only show if logged in)
                if (_isLoggedIn)
                  ListTile(
                    leading: Icon(
                      Icons.receipt_long_outlined,
                      color: theme.primaryColor,
                    ),
                    title: const Text('My Orders'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyOrdersScreen(),
                        ),
                      );
                    },
                  ),

                // Favorites (only show if logged in)
                if (_isLoggedIn)
                  ListTile(
                    leading: Icon(
                      Icons.favorite_outline,
                      color: theme.primaryColor,
                    ),
                    title: const Text('Favorites'),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to favorites
                    },
                  ),

                // Notifications (only show if logged in)
                if (_isLoggedIn)
                  ListTile(
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: theme.primaryColor,
                    ),
                    title: const Text('Notifications'),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to notifications
                    },
                  ),

                // About
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: theme.primaryColor,
                  ),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog();
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Login/Logout at bottom
          Container(
            padding: const EdgeInsets.all(16),
            child: _isLoggedIn
                ? ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content:
                              const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _logout();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : ListTile(
                    leading: Icon(
                      Icons.login,
                      color: theme.primaryColor,
                    ),
                    title: Text(
                      'Login',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/signin');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
