import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'core/l10n/app_locale.dart';
import 'core/l10n/l10n.dart';
import 'core/l10n/language_switch.dart';
import 'core/pwa/pwa_detector.dart';
import 'core/pwa/widgets/pwa_root_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro');
  await initializeDateFormatting('en');
  final savedLocale = await AppLocaleController.loadSaved();
  Intl.defaultLocale = savedLocale.languageCode;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    await NotificationService().init();

    if (!kIsWeb) {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          'Foreground message: ${message.notification?.title}',
        );
      });
    } else {
      await _initWebMessaging();
    }
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith(
          (ref) => AppLocaleController(savedLocale),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Web FCM: supported on desktop/Android browsers; limited on iOS installed PWA.
Future<void> _initWebMessaging() async {
  if (pwaIsIosDevice() && !pwaIsStandalone()) {
    debugPrint('FCM: skip token on iOS Safari — install PWA for best experience');
    return;
  }

  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    debugPrint('FCM Web Token: $token');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Web foreground: ${message.notification?.title}');
    });
  } catch (e) {
    debugPrint('Web FCM init skipped: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp(
      title: 'CafeFlow',
      locale: locale,
      supportedLocales: const [Locale('ro'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return L10nScope(
          l10n: L10n(locale),
          child: AppLanguageLayer(
            child: PwaRootShell(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
