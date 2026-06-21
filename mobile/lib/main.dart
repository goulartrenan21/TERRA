import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:            const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // Firebase is optional in dev (no google-services.json needed to run the app)
  try {
    await Firebase.initializeApp();
  } catch (_) {
    debugPrint('[firebase] initialization skipped — add google-services.json to enable push');
  }

  runApp(const ProviderScope(child: TerraApp()));
}

class TerraApp extends ConsumerWidget {
  const TerraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TERRA',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light(),
      darkTheme:  AppTheme.dark(),
      themeMode:  ThemeMode.system,
      routerConfig: router,
    );
  }
}
