import 'package:flutter/material.dart';
import 'package:natproxy/auth/auth_gate.dart';
import 'package:natproxy/config/app_theme.dart';
import 'package:natproxy/config/supabase_config.dart';
import 'package:natproxy/screens/account_screen.dart';
import 'package:natproxy/screens/auth/sign_up_screen.dart';
import 'package:natproxy/screens/client_screen.dart';
import 'package:natproxy/screens/client_settings_screen.dart';
import 'package:natproxy/screens/server_screen.dart';
import 'package:natproxy/screens/server_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CDN-NETSHARE',
      theme: AppTheme.light(),
      home: const AuthGate(),
      routes: {
        '/sign-up': (context) => const SignUpScreen(),
        '/account': (context) => const AccountScreen(),
        '/server': (context) => const ServerScreen(),
        '/client': (context) => const ClientScreen(),
        '/server-settings': (context) => const ServerSettingsScreen(),
        '/client-settings': (context) => const ClientSettingsScreen(),
      },
    );
  }
}
