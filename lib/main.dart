/* // main.dart - إضافة مسح البيانات في بداية التطبيق
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:puresip_purchasing/pages/finished_products/services/finished_product_service.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'debug_helper.dart';

// ✅ إضافة imports للمسح
//import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LicenseNotifications.showFcmNotification(message);
}

/* /// ✅ دالة مسح جميع البيانات المخزنة
Future<void> _clearAllStoredData() async {
  try {
    safeDebugPrint('🗑️ Starting to clear all stored data...');

    // 1. مسح SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    safeDebugPrint('✅ SharedPreferences cleared');

    // 2. مسح SecureStorage
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();
    safeDebugPrint('✅ SecureStorage cleared');

    // 3. مسح التطبيق بالكامل (إذا كان هناك أي تخزين آخر)
    // 4. محاولة مسح Firebase Auth (سيؤدي إلى تسجيل الخروج)
    try {
      await FirebaseAuth.instance.signOut();
      safeDebugPrint('✅ Firebase Auth signed out');
    } catch (e) {
      safeDebugPrint('⚠️ Could not sign out: $e');
    }

    safeDebugPrint('✅ All stored data cleared successfully');
  } catch (e) {
    safeDebugPrint('❌ Error clearing data: $e');
  }
}

/// ✅ التحقق من إعادة التثبيت (مسح البيانات إذا كان التطبيق مثبتاً حديثاً)
Future<void> _checkAndClearOnReinstall() async {
  try {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    // ✅ إنشاء مفتاح خاص لتتبع تثبيت التطبيق
    const installKey = 'app_install_id';
    final currentInstallId = await secureStorage.read(key: installKey);

    if (currentInstallId == null) {
      // ✅ هذه هي المرة الأولى التي يتم فيها تشغيل التطبيق بعد التثبيت
      safeDebugPrint(
          '🆕 First launch after installation - clearing all data...');

      // إنشاء معرف تثبيت جديد
      final newInstallId = DateTime.now().millisecondsSinceEpoch.toString();
      await secureStorage.write(key: installKey, value: newInstallId);

      // مسح جميع البيانات القديمة
      await prefs.clear();
      await secureStorage.deleteAll();
      await secureStorage.write(key: installKey, value: newInstallId);

      safeDebugPrint('✅ Fresh install detected - all old data cleared');
    } else {
      safeDebugPrint('✅ App already installed - keeping data');
    }
  } catch (e) {
    safeDebugPrint('❌ Error checking reinstall: $e');
  }
}
 */
// 🚀 تهيئة التراخيص والإشعارات فقط بالخلفية
Future<void> _initSecondaryBackgroundServices() async {
  try {
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }
    await LicenseService().initialize();
    await LicenseNotifications.initialize();
    safeDebugPrint('✅ Secondary background services initialized');
  } catch (e, st) {
    safeDebugPrint('❌ Secondary services error: $e\n$st');
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.white,
        child: Center(
          child: Text(details.exceptionAsString(), textAlign: TextAlign.center),
        ),
      );
    };

    // ✅ FIRST: مسح جميع البيانات (للتأكد من أن التطبيق يبدأ بحالة نظيفة)
  //  await _clearAllStoredData();

    // ✅ SECOND: التحقق من إعادة التثبيت
 //   await _checkAndClearOnReinstall();

    // 1️⃣ تهيئة Firebase الأساسي أولاً
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
        safeDebugPrint('✅ Core Firebase initialized successfully');
      }
    } catch (e) {
      safeDebugPrint('❌ Firebase core init error: $e');
    }

    // 2️⃣ تهيئة التخزين واللغات السريعة
    await EasyLocalization.ensureInitialized();

    // 3️⃣ تشغيل بقية الإعدادات غير الحرجة بالخلفية
   // _initSecondaryBackgroundServices();
    unawaited(_initSecondaryBackgroundServices());
    unawaited(VersionChecker.init());

    await VersionChecker.init();

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('en'), // الإنجليزية
          Locale('ar'), // العربية
          Locale('fr'), // الفرنسية
          Locale('es'), // الإسبانية
          Locale('de'), // الألمانية
          Locale('tr'), // التركية
        ],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        useOnlyLangCode: true,
        child: MultiProvider(
          providers: [
            Provider<FirestoreService>(create: (_) => FirestoreService()),
            Provider<FinishedProductService>(
                create: (_) => FinishedProductService()),
            ChangeNotifierProvider(create: (_) => CompanyService()),
            ChangeNotifierProvider(create: (_) => FactoryService()),
            ChangeNotifierProvider(create: (_) => CompositionService()),
            Provider<ManufacturingService>(
                create: (_) => ManufacturingService()),
          ],
          child: const MyApp(),
        ),
      ),
    );
  }, (error, stack) {
    safeDebugPrint('❌ runZonedGuarded caught: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: 'PureSip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Cairo-Regular',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child,
        );
      },
    );
  }
}
 */

// main.dart - نسخة سريعة
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/providers/dashboard_settings_provider.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:puresip_purchasing/pages/finished_products/services/finished_product_service.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'debug_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LicenseNotifications.showFcmNotification(message);
}

Future<void> _initSecondaryBackgroundServices() async {
  try {
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    await LicenseService().initialize();
    await LicenseNotifications.initialize();
    safeDebugPrint('✅ Secondary services initialized');
  } catch (e, st) {
    safeDebugPrint('❌ Secondary services error: $e\n$st');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      safeDebugPrint('✅ Firebase initialized');
    }
  } catch (e) {
    safeDebugPrint('❌ Firebase error: $e');
  }

  // تهيئة الترجمة
  await EasyLocalization.ensureInitialized();
  
  // تشغيل الخدمات الخلفية (لا تنتظر)
  unawaited(_initSecondaryBackgroundServices());
  unawaited(VersionChecker.init());
  GoRouter.optionURLReflectsImperativeAPIs = true;  // ✅ أضف هذا

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'), Locale('ar'), Locale('fr'), 
        Locale('es'), Locale('de'), Locale('tr')
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          // ✅ Provider للإعدادات (يتم تحميله أولاً)
          ChangeNotifierProvider(create: (_) => DashboardSettingsProvider()),
          // خدمات أخرى
          Provider<FirestoreService>(create: (_) => FirestoreService()),
          Provider<FinishedProductService>(create: (_) => FinishedProductService()),
          ChangeNotifierProvider(create: (_) => CompanyService()),
          ChangeNotifierProvider(create: (_) => FactoryService()),
          ChangeNotifierProvider(create: (_) => CompositionService()),
          Provider<ManufacturingService>(create: (_) => ManufacturingService()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: 'PureSip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Cairo-Regular',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child,
        );
      },
    );
  }
}