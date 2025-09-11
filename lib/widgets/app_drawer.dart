import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final token = prefs.getString('authToken');
    final userName = prefs.getString('user_name');

    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _userName = userName ?? 'Guest';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _isLoggedIn = false;
      _userName = 'Guest';
    });

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                      // TODO: Navigate to profile
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
                      // TODO: Navigate to orders
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

                // Settings
                ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: theme.primaryColor,
                  ),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to settings
                  },
                ),

                // Help & Support
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: theme.primaryColor,
                  ),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to help
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
                    // TODO: Show about dialog
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
