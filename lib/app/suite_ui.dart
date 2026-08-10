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
                    fontFamily: 'Georgia',
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    color: PropertyOsColours.deepNavy)),
          ),
          if (!compact) ...[
            const SizedBox(width: 14),
            const Column(
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
                          letterSpacing: 1.5,
                          fontSize: 9)),
                ]),
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
            style: const TextStyle(
                color: PropertyOsColours.amberText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(fontSize: 42)),
        const SizedBox(height: 6),
        Text(subtitle,
            style:
                const TextStyle(color: PropertyOsColours.muted, fontSize: 16)),
      ]);
}

class SectionPanel extends StatelessWidget {
  const SectionPanel(
      {super.key, required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: PropertyOsColours.border)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontFamily: 'Georgia',
                                color: PropertyOsColours.ink)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              color: PropertyOsColours.muted, fontSize: 12)),
                  ])),
          const Divider(height: 1),
          child,
        ]),
      );
}
