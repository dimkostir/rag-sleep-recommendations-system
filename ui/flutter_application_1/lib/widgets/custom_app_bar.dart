import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogout;
  final VoidCallback? onLogout;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showLogout = false,
    this.onLogout,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor:  Colors.deepPurple,
      centerTitle: true,
      actions: [
        if (actions != null) ...actions!,
        if (showLogout)
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: onLogout, 
            
          ),
      ],
    );
  }
}
