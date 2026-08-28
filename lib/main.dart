import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/auth/auth_controller.dart';
import 'src/ui/login_page.dart';
import 'src/ui/main_screen.dart';

void main() {
  runApp(const CbiApp());
}

class CbiApp extends StatefulWidget {
  const CbiApp({super.key});

  @override
  State<CbiApp> createState() => _CbiAppState();
}

class _CbiAppState extends State<CbiApp> {
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthController();
    // Reattach to a stored session before the first frame settles, so a
    // returning user does not see the login screen flash past.
    _auth.restore();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CBI HR',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => switch (_auth.status) {
          AuthStatus.restoring => const _SplashPage(),
          AuthStatus.signedOut => LoginPage(auth: _auth),
          AuthStatus.signedIn => MainScreen(auth: _auth),
        },
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F62FE),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.surface,
      fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Cairo', 'Arial'],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
