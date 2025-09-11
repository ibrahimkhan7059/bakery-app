import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;
  final bool showTitle;

  const GlobalAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.bottom,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      elevation: 0,
      backgroundColor: theme.primaryColor,
      automaticallyImplyLeading: false,  // Changed to false
      toolbarHeight: 70,
      leading: showBackButton 
          ? Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              ),
            )
          : null,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: theme.colorScheme.surface,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      title: showTitle ? Padding(
        padding: const EdgeInsets.only(left: 8),  // Adjusted padding for left alignment
        child: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ) : null,
      centerTitle: false,  // Changed to false to align title to start
      actions: actions ?? [
        Container(
          height: 40,
          width: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
        ),
      ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(bottom?.preferredSize.height ?? 0 + 70);
} 