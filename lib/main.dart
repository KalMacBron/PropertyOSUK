import 'package:flutter/widgets.dart';
import 'package:property_os/app/property_os_app.dart';
import 'package:property_os/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(const PropertyOsApp());
}
