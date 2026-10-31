import 'package:flutter/material.dart';

/// The 4-tab navigation bar (plan §5): Home / Chat / Us / Plans.
/// Visuals come from navigationBarTheme (accent indicator, Inter labels).
enum AppTab { home, chat, us, plans }

class AppBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onTap;
  final int? chatBadge;

  const AppBottomNav({
    super.key,
    required this.current,
    required this.onTap,
    this.chatBadge,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (i) => onTap(AppTab.values[i]),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: _ChatIcon(badge: chatBadge, selected: false),
          selectedIcon: _ChatIcon(badge: chatBadge, selected: true),
          label: 'Chat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.photo_album_outlined),
          selectedIcon: Icon(Icons.photo_album_rounded),
          label: 'Us',
        ),
        const NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event_rounded),
          label: 'Plans',
        ),
      ],
    );
  }
}

class _ChatIcon extends StatelessWidget {
  final int? badge;
  final bool selected;

  const _ChatIcon({required this.badge, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    if (badge == null || badge == 0) {
      return Icon(selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, size: 24, color: color);
    }
    return Badge(
      label: Text('$badge'),
      backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      textColor: Theme.of(context).colorScheme.surface,
      child: Icon(selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, size: 24, color: color),
    );
  }
}
