import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'models/auth_state.dart';
import 'models/ui_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_scaffold.dart';
import 'screens/notifications_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env failed to load: $e');
  }

  const dartDefineKey = String.fromEnvironment('GROQ_API_KEY');
  final dotenvKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final resolvedKey = dartDefineKey.isNotEmpty ? dartDefineKey : dotenvKey;

  if (resolvedKey.isEmpty) {
    throw Exception(
      '\n\n'
      '════════════════════════════════════════\n'
      '  GROQ_API_KEY is missing or empty!\n'
      '  Fix one of the following:\n'
      '  1) Add to pubspec.yaml assets: - .env\n'
      '     and ensure .env contains: GROQ_API_KEY=gsk_xxx\n'
      '  2) Run with: flutter run --dart-define=GROQ_API_KEY=gsk_xxx\n'
      '════════════════════════════════════════\n',
    );
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Multi-State Setup ──────────────────────────────────────────
  // Wiring: AppState created first, passed as callback to AuthState, 
  // then linked back via attachAuthState(). This provides clean 
  // unidirectional dependency for logic and bidirectional access 
  // for the UI via Providers.
  final appState = AppState();
  final uiState = UiState();
  
  final authState = AuthState(
    firestoreService: appState.firestoreService,
    onAuthChanged: (uid) async {
      await appState.onAuthChanged(uid);
      if (uid == null) uiState.clearForSignOut();
    },
  );

  appState.attachAuthState(authState);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: uiState),
      ],
      child: const SkillSyncApp(),
    ),
  );
}

class SkillSyncApp extends StatelessWidget {
  const SkillSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch UiState for theme changes
    final isLight = context.watch<UiState>().isLightMode;

    return MaterialApp(
      title: 'SkillSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(isLight: isLight),
      darkTheme: AppTheme.buildTheme(isLight: isLight),
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: AppColors.bg,
          systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ));
        return child!;
      },
      home: const _AuthGate(),
      routes: {
        '/notifications': (_) => const NotificationsScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final app = context.watch<AppState>();

    if (!_splashDone) {
      return SplashScreen(
        onComplete: () => setState(() => _splashDone = true),
      );
    }

    if (auth.authLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Color(0xFFA855F7)),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: auth.isLoggedIn
          ? (app.profileInitialized 
              ? (app.profile?.onboardingComplete == true || app.skills.isNotEmpty
                  ? const MainScaffold(key: ValueKey('app'))
                  : const MainScaffold(key: ValueKey('onboarding')))
              : Scaffold(
                  backgroundColor: AppColors.bg,
                  body: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFA855F7)),
                  ),
                ))
          : LoginScreen(key: const ValueKey('login'), onLogin: () {}),
    );
  }
}
