import 'package:flutter/material.dart';

/// Type-led AppBar wrapper (plan §4: transparent, Fraunces title via theme,
/// no glass). Screens compose their own leading widgets when they need more
/// than the default back button.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool implyLeading;
  final PreferredSizeWidget? bottom;
  final double elevation;

  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.implyLeading = true,
    this.bottom,
    this.elevation = 0,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: implyLeading,
      bottom: bottom,
    );
  }
}
