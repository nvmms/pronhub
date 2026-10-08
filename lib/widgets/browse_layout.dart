import 'package:pronhub/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';

class BrowseAction {
  const BrowseAction(
    this.label,
    this.icon,
    this.onTap, {
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

class BrowseLayout extends StatelessWidget {
  const BrowseLayout({
    super.key,
    required this.title,
    required this.actions,
    this.bottomActions = const [],
    required this.child,
  });

  final String title;
  final List<BrowseAction> actions;
  final List<BrowseAction> bottomActions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showHeading = !context.isPhone;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = context.isPhone;
        Widget actionTile(BrowseAction action) {
          if (compact) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                mouseCursor: SystemMouseCursors.click,
                avatar: Icon(
                  action.icon,
                  size: 18,
                  color: action.selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                label: Text(action.label),
                backgroundColor: action.selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLow,
                side: BorderSide.none,
                onPressed: action.onTap,
              ),
            );
          }
          return Material(
            color: Colors.transparent,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(action.icon, size: 20),
              title: Text(action.label),
              selected: action.selected,
              selectedColor: scheme.onPrimaryContainer,
              selectedTileColor: scheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: action.onTap,
            ),
          );
        }

        final navigation = [for (final action in actions) actionTile(action)];
        final bottomNavigation = [
          for (final action in bottomActions) actionTile(action),
        ];
        final heading = Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
        if (compact) {
          return Column(
            children: [
              if (showHeading) heading,
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...navigation,
                    if (bottomNavigation.isNotEmpty) const SizedBox(width: 16),
                    ...bottomNavigation,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          );
        }
        return Row(
          children: [
            Container(
              width: 216,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeading) heading,
                  Expanded(child: ListView(children: navigation)),
                  if (bottomNavigation.isNotEmpty) ...[
                    const Divider(),
                    ...bottomNavigation,
                  ],
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
