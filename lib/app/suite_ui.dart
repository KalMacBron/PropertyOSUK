import 'package:flutter/material.dart';
import 'package:property_os/app/theme.dart';

class SuiteBrand extends StatelessWidget {
  const SuiteBrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            color: PropertyOsColours.amber,
            alignment: Alignment.center,
            child: const Text('K',
                style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    color: PropertyOsColours.deepNavy)),
          ),
          if (!compact) ...[
            const SizedBox(width: 14),
            // The word mark scales down as a unit in narrow spaces and at
            // large text sizes instead of overflowing.
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROPERTYOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                              fontSize: 15)),
                      SizedBox(height: 4),
                      Text('PROPERTY OPERATIONS',
                          style: TextStyle(
                              color: Color(0xFF9DB1BF),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontSize: 11)),
                    ]),
              ),
            ),
          ],
        ],
      );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle});
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(),
            style: PropertyOsText.eyebrow.copyWith(
                color: PropertyOsColours.amberText,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.displayMedium),
        ),
        const SizedBox(height: 6),
        Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: PropertyOsColours.muted)),
      ]);
}

class SectionPanel extends StatelessWidget {
  const SectionPanel(
      {super.key, required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: PropertyOsColours.border),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ])),
          const Divider(height: 1),
          child,
        ]),
      );
}

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 24,
                    runSpacing: 18,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: PageHeading(
                          eyebrow: eyebrow,
                          title: title,
                          subtitle: subtitle,
                        ),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ],
      );
}

class SuiteEmptyState extends StatelessWidget {
  const SuiteEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;

  /// The next step, such as a button that adds the first record.
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: PropertyOsColours.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              color: PropertyOsColours.amberTint,
              child: Icon(icon, color: PropertyOsColours.amberText),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(color: PropertyOsColours.muted)),
                  if (action != null) ...[
                    const SizedBox(height: 14),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// A load failure with a way forward, used instead of a bare error message.
class SuiteErrorState extends StatelessWidget {
  const SuiteErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryAction,
  });

  final String message;
  final VoidCallback onRetry;

  /// An extra button shown after "Try again", such as "Sign out".
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: PropertyOsColours.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: PropertyOsColours.critical),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(message)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        ),
      );
}

/// A progress indicator that screen readers announce.
class SuiteLoading extends StatelessWidget {
  const SuiteLoading({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(semanticsLabel: label),
        ),
      );
}
