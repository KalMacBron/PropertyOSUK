import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/router.dart';
import 'package:property_os/app/theme.dart';

class PropertyOsApp extends StatelessWidget {
  const PropertyOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'PropertyOS',
        debugShowCheckedModeBanner: false,
        theme: buildPropertyOsTheme(),
        routerConfig: propertyOsRouter,
      ),
    );
  }
}

