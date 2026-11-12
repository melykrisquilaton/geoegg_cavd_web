
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/presentation/login_screen.dart';

const String supabaseUrl =
    String.fromEnvironment('SUPABASE_URL');

const String supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'GeoEgg: Supabase configuration is missing. '
      'Run with --dart-define-from-file=supabase.env.json',
    );
  }

  if (!supabaseUrl.startsWith('https://')) {
    throw StateError('GeoEgg: Invalid Supabase URL.');
  }

  if (supabasePublishableKey.startsWith('sb_secret_')) {
    throw StateError(
      'GeoEgg: Never use a Supabase secret key in the web application.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  debugPrint('GEOEGG CAVD WEB: Supabase initialized.');

  runApp(const GeoEggWebApp());
}

class GeoEggWebApp extends StatelessWidget {
  const GeoEggWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GeoEgg CAVD Administration',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE96B32),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F4),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
