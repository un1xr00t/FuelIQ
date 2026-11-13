import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'fuel_theme.dart';

class FuelPage extends StatelessWidget {
  const FuelPage({
    super.key,
    required this.title,
    required this.children,
    this.header,
    this.silver = false,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? header;
  final bool silver;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final ink = silver
        ? FuelTheme.pearlInk
        : FuelTheme.resolve(context, FuelTheme.ink);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final titleStyle = title == 'FuelIQ'
        ? FuelTheme.wordmark
        : FuelTheme.heading;
    final headerRadius = BorderRadius.vertical(bottom: Radius.circular(42));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: !silver && dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: silver ? headerRadius : null,
                  gradient: silver
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF5F5F4), Color(0xFFDBDBDA)],
                        )
                      : null,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: FuelTheme.contentWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          silver ? 20 : 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                if (canPop)
                                  FuelCircleButton(
                                    icon: CupertinoIcons.chevron_back,
                                    label: 'Back',
                                    color: ink,
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                  )
                                else
                                  const SizedBox(width: 44),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: titleStyle.copyWith(color: ink),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                trailing ?? const SizedBox(width: 44),
                              ],
                            ),
                            if (header case final content?) ...[
                              const SizedBox(height: 10),
                              content,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(12, 12, 12, 28),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FuelIconTile(icon),
            const SizedBox(height: FuelTheme.gap),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: FuelTheme.heading,
              ),
            ),
            const SizedBox(height: FuelTheme.compact),
            Text(
              message,
              textAlign: TextAlign.center,
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
  const FuelSurface({super.key, required this.child, this.glow = false});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final border = FuelTheme.resolve(context, FuelTheme.border);
    final surface = FuelTheme.resolve(context, FuelTheme.surface);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FuelTheme.radius),
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF515355),
                  Color(0xFF1B1C1D),
                  Color(0xFF141516),
                  Color(0xFF424445),
                ],
                stops: [0, .36, .64, 1],
              )
            : LinearGradient(colors: [border, border]),
      ),
      child: Padding(
        padding: const EdgeInsets.all(.8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FuelTheme.radius - .8),
            gradient: glow
                ? RadialGradient(
                    center: const Alignment(0, 1.15),
                    radius: 1.2,
                    colors: [
                      dark ? const Color(0xFF143820) : const Color(0xFFDAEEE0),
                      surface,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [dark ? const Color(0xFF171819) : surface, surface],
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class FuelCircleButton extends StatelessWidget {
  const FuelCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .05),
      border: Border.all(width: .8, color: color.withValues(alpha: .24)),
    ),
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      foregroundColor: color,
      onPressed: onPressed,
      child: Icon(icon, size: 18, semanticLabel: label),
    ),
  );
}

class FuelDivider extends StatelessWidget {
  const FuelDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: .7,
    margin: const EdgeInsets.symmetric(horizontal: FuelTheme.inset),
    color: FuelTheme.resolve(context, FuelTheme.border),
  );
}

class FuelPanel extends StatelessWidget {
  const FuelPanel({super.key, required this.children, this.glow = false});

  final List<Widget> children;
  final bool glow;

  @override
  Widget build(BuildContext context) => FuelSurface(
    glow: glow,
    child: Padding(
      padding: const EdgeInsets.all(FuelTheme.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class FuelAction extends StatelessWidget {
  const FuelAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: FuelTheme.resolve(context, FuelTheme.surface),
      gradient: onPressed == null
          ? null
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF53B96A),
                FuelTheme.actionStart,
                FuelTheme.actionEnd,
                Color(0xFF379F53),
              ],
              stops: [0, .18, .83, 1],
            ),
      border: Border.all(
        color: onPressed == null
            ? FuelTheme.resolve(context, FuelTheme.border)
            : const Color(0xFF3E9C59),
      ),
      borderRadius: BorderRadius.circular(100),
    ),
    child: CupertinoButton(
      minimumSize: const Size(44, 52),
      borderRadius: BorderRadius.circular(100),
      foregroundColor: const Color(0xFFFFFFFF),
      disabledColor: FuelTheme.resolve(context, FuelTheme.surface),
      padding: const EdgeInsets.symmetric(
        horizontal: FuelTheme.inset,
        vertical: FuelTheme.gap,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: FuelTheme.rowTitle.copyWith(
          color: onPressed == null
              ? FuelTheme.resolve(context, FuelTheme.muted)
              : const Color(0xFFFFFFFF),
        ),
      ),
    ),
  );
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
          border: Border.all(
            width: .7,
            color: FuelTheme.resolve(context, FuelTheme.border),
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          icon,
          size: 21,
          color: FuelTheme.resolve(context, FuelTheme.ink),
        ),
      ),
    );
  }
}
