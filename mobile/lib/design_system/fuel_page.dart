import 'package:flutter/cupertino.dart';

import 'fuel_theme.dart';

class FuelPage extends StatelessWidget {
  const FuelPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            automaticBackgroundVisibility: false,
            backgroundColor: FuelTheme.canvas,
            border: null,
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              bottom: false,
              minimum: const EdgeInsets.fromLTRB(
                FuelTheme.inset,
                FuelTheme.gap,
                FuelTheme.inset,
                FuelTheme.sectionGap,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: FuelTheme.contentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FuelEmptyState extends StatelessWidget {
  const FuelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FuelSurface(
      child: Padding(
        padding: const EdgeInsets.all(FuelTheme.inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FuelIconTile(icon),
            const SizedBox(height: FuelTheme.inset),
            Semantics(
              header: true,
              child: Text(title, style: FuelTheme.heading),
            ),
            const SizedBox(height: FuelTheme.compact),
            Text(
              message,
              style: FuelTheme.body.copyWith(
                color: FuelTheme.resolve(context, FuelTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FuelSurface extends StatelessWidget {
  const FuelSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FuelTheme.resolve(context, FuelTheme.surface),
        border: Border.all(color: FuelTheme.resolve(context, FuelTheme.border)),
        borderRadius: BorderRadius.circular(FuelTheme.radius),
      ),
      child: child,
    );
  }
}

class FuelIconTile extends StatelessWidget {
  const FuelIconTile(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: FuelTheme.resolve(context, FuelTheme.accentSurface),
          borderRadius: BorderRadius.circular(FuelTheme.gap),
        ),
        child: Icon(
          icon,
          size: 21,
          color: FuelTheme.resolve(context, FuelTheme.accent),
        ),
      ),
    );
  }
}
