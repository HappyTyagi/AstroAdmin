import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'screens/admin_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_preferences.dart';
import 'services/push_notification_bootstrap_service.dart';
import 'services/push_token_sync_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  await PushNotificationBootstrapService.handleBackgroundPush(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('[Admin] .env load skipped: $error');
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushTokenSyncService.initialize();
    await PushNotificationBootstrapService.initialize(
      navigatorKey: appNavigatorKey,
    );
  } catch (e) {
    debugPrint('[Admin] Firebase init failed: $e');
  }
  await AppPreferences.init();
  runApp(const AstroAdminApp());
}

class AstroAdminApp extends StatelessWidget {
  const AstroAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPreferences.themeModeNotifier,
      builder: (BuildContext context, ThemeMode themeMode, Widget? _) {
        return MaterialApp(
          title: 'AstroAdmin',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          theme: AdminAppTheme.lightTheme,
          darkTheme: AdminAppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final width = mediaQuery.size.width;
            final isTablet = width >= 600;
            final maxWidth = isTablet ? 900.0 : width;
            return MediaQuery(
              data: mediaQuery,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const AdminHomeScreen(),
          },
        );
      },
    );
  }
}
