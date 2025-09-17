// main.dart — نسخة مُحسنة للتشخيص ومنع "الشاشة البيضاء"
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_helper.dart';

// FCM background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LicenseNotifications.showFcmNotification(message);
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final licenseService = LicenseService();
      // ضع timeout تحوطًا لو تأخرت التهيئة
      await licenseService.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          safeDebugPrint('LicenseService.initialize() timed out');
          return;
        },
      );
      await LicenseNotifications.initialize().timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          safeDebugPrint('LicenseNotifications.initialize() timed out');
          return;
        },
      );

      safeDebugPrint('Firebase initialization completed');
    }
  } catch (e, st) {
    safeDebugPrint('Firebase initialization error: $e\n$st');
    rethrow;
  }
}

Future<void> _requestPermissions() async {
  if (!kIsWeb) {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      safeDebugPrint('Permission request error: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التقاط أخطاء فلاتر وعرضها بدل الشاشة البيضاء
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    safeDebugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };

  // Error widget لعرض رسالة تظهر على الشاشة عوضًا عن white screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    safeDebugPrint('ErrorWidget: ${details.exception}\n${details.stack}');
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 12),
              const Text('An error occurred', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // احرص على تهيئة easy_localization و hive
  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();

  // إياك أن تنفذ init مرتين — نفّذها مرة واحدة
  try {
    await HiveService.init().timeout(const Duration(seconds: 8),
        onTimeout: () {
      safeDebugPrint('HiveService.init() timed out');
      // لا نرمي هنا — نتابع حتى نعرض رسالة واضحة
      return;
    });

    // جهّز الباقي (Firebase + permissions) مع حماية من الانتظار الطويل
    await Future.wait([
      _initializeFirebase().timeout(const Duration(seconds: 12), onTimeout: () {
        safeDebugPrint('_initializeFirebase() timed out');
        return;
      }),
      _requestPermissions().timeout(const Duration(seconds: 6), onTimeout: () {
        safeDebugPrint('_requestPermissions() timed out');
        return;
      }),
    ]);
  } catch (e, st) {
    safeDebugPrint('Initialization failed: $e\n$st');
    // لا ترجع / لا توقف؛ نسمح للتطبيق بالاقلاع ليعرض ErrorWidget إن احتاج
  }

  // تشغيل التطبيق ضمن runZonedGuarded لالتقاط كل الاستثناءات الغير متوقعة
  runZonedGuarded(() {
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/lang',
        fallbackLocale: const Locale('ar'),
        child: MultiProvider(
          providers: [
            // ضع هنا نفس Providers لكن تأكد أن منشئي الخدمات لا يصلون للـ Hive/Firestore في constructor بشكل متزامن
            Provider(create: (_) => /* FirestoreService() */ null),
            // ... بقيّة providers مؤقتًا أو اجعلها lazy
          ],
          child: const MyApp(),
        ),
      ),
    );
  }, (error, stack) {
    safeDebugPrint('runZonedGuarded caught error: $error\n$stack');
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
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
      builder: (context, child) {
        // حماية: لا نفرض child! — نتحقق أولاً
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child,
        );
      },
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'Cairo-Regular',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.green[800],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/* import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:puresip_purchasing/pages/finished_products/services/finished_product_service.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:puresip_purchasing/debug_helper.dart';

// دالة خلفية لمعالجة رسائل FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LicenseNotifications.showFcmNotification(message);
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // تهيئة FCM للمعالجة الخلفية
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // تهيئة خدمات التراخيص والإشعارات
      final licenseService = LicenseService();
      await licenseService.initialize();
      await LicenseNotifications.initialize();

      safeDebugPrint('Firebase initialization completed');
    }
  } catch (e) {
    safeDebugPrint('Firebase initialization error: $e');
    rethrow;
  }
}

Future<void> _requestPermissions() async {
  if (!kIsWeb) {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      // طلب أذونات إضافية للأندرويد
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      safeDebugPrint('Permission request error: $e');
    }
  }
}

/* Future<void> _loadAppResources() async {
  try {
    await Future.delayed(const Duration(milliseconds: 200));
    safeDebugPrint('App resources loaded successfully');
  } catch (e) {
    safeDebugPrint('Resource loading error: $e');
  }
} */

/* Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة كل شيء بشكل متوازي حيثما أمكن
  await Future.wait([
    EasyLocalization.ensureInitialized(),
    Hive.initFlutter(),
  ]);

  // فتح صناديق Hive بشكل متوازي
  await Future.wait([
    Hive.openBox('userData'),
    Hive.openBox('licenseBox'),
    Hive.openBox('auth'), // أضف هذا
  ]);

  try {
    // تهيئة Firebase والخدمات الأخرى بشكل متوازي
    await Future.wait([
      _initializeFirebase(),
      _requestPermissions(),
    ]);
  } catch (e) {
    safeDebugPrint('Initialization failed: $e');
  } */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // تهيئة Hive فقط - الصناديق سيتم فتحها في HiveService.init()
  await Hive.initFlutter();
 await HiveService.init();
  // تهيئة الخدمات الأخرى بشكل متوازي
  try {
    await Future.wait([
      HiveService.init(), // تهيئة صناديق Hive
      _initializeFirebase(),
      _requestPermissions(),
    ]);
  } catch (e) {
    safeDebugPrint('Initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [
          Provider<FirestoreService>(create: (_) => FirestoreService()),
          Provider<FinishedProductService>(
              create: (_) => FinishedProductService()),
          ChangeNotifierProvider(create: (_) => CompanyService()),
          ChangeNotifierProvider(create: (_) => FactoryService()),
          ChangeNotifierProvider(create: (_) => CompositionService()),
          Provider<ManufacturingService>(
            create: (_) => ManufacturingService(),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

/* Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized(); // يجب أن يتم أولًا

  await Hive.initFlutter();

 await Hive.openBox('userData');
  await Hive.openBox('licenseBox'); // الصندوق الذي تستخدمه HiveService
  
  try {
    // تهيئة Firebase أولًا لأنها قد تستخدم في ما يلي
    await _initializeFirebase();

    // ثم طلب الأذونات
    await _requestPermissions();

    // ثم تحميل الموارد الأخرى
    await _loadAppResources();
  } catch (e) {
    safeDebugPrint('Initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [
          Provider<FirestoreService>(create: (_) => FirestoreService()),
          Provider<FinishedProductService>(
              create: (_) => FinishedProductService()),
          ChangeNotifierProvider(create: (_) => CompanyService()),
          ChangeNotifierProvider(create: (_) => FactoryService()),
          ChangeNotifierProvider(create: (_) => CompositionService()),
          Provider<ManufacturingService>(
            create: (_) => ManufacturingService(),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}
 */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // اختبار الترجمة هنا للتأكد من عملها
    //safeDebugPrint('Translation test - manufacturing.shelf_life: ${'manufacturing.shelf_life'.tr()}');

    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: 'PureSip',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // يمكن تنفيذ منطق لاحق هنا بعد البناء
        });
        return MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'Cairo-Regular',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.green[800],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} */

/* import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; //show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

/* Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // تهيئة خدمات التراخيص والإشعارات
      await LicenseService().initializeForAdmin();
      await LicenseNotifications.initialize();
      
      safeDebugPrint('Firebase initialization completed');
    }
  } catch (e) {
    safeDebugPrint('Firebase initialization error: $e');
    rethrow;
  }
}
 */
// دالة خلفية لمعالجة رسائل FCM حتى عندما يكون التطبيق مغلقًا أو في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LicenseNotifications.showFcmNotification(message);
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // تهيئة خدمات التراخيص والإشعارات
      final licenseService = LicenseService();
      await licenseService
          .initialize(); // استخدم initialize() بدلاً من initializeForAdmin()

      await LicenseNotifications.initialize();

      safeDebugPrint('Firebase initialization completed');
    }
  } catch (e) {
    safeDebugPrint('Firebase initialization error: $e');
    rethrow;
  }
}

Future<void> _requestPermissions() async {
  if (!kIsWeb) {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      // ✅ طلب أذونات إضافية للأندرويد بطريقة آمنة
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      safeDebugPrint('Permission request error: $e');
    }
  }
}

Future<void> _loadAppResources() async {
  try {
    // تحميل الخطوط والموارد الأخرى
    await Future.wait([
      // يمكن إضافة المزيد من عمليات التحميل هنا
      Future.delayed(const Duration(milliseconds: 200)),
    ]);
    safeDebugPrint('App resources loaded successfully');
  } catch (e) {
    safeDebugPrint('Resource loading error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تسجيل المعالج الخلفي
//  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // await LicenseNotifications.initialize();

  try {
    // التهيئة المتوازية للخدمات
    await Future.wait([
      EasyLocalization.ensureInitialized(),
      _initializeFirebase(),
      _requestPermissions(),
      _loadAppResources(),
    ]);
  } catch (e) {
    safeDebugPrint('Initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [
          Provider<ManufacturingService>(
            create: (_) => ManufacturingService(),
          ),
          // مزودات أخرى
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
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
      builder: (context, child) {
        return MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'Cairo-Regular', // استخدام خط عربي افتراضي
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.green[800],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/* import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'router.dart';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

/* void connectToFirebaseEmulators() {
  // تأكد أنك لا تستخدم المحاكيات عند النشر للإنتاج
  const bool shouldUseEmulator = true;
  if (shouldUseEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
} */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();


  // Load Arabic font
  await _loadArabicFont();
  
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp(); // fallback
      }
    }
  } catch (e) {
    safeDebugPrint('⚠️ Firebase already initialized: $e');
  }

  // الاتصال بالمحاكيات
  // connectToFirebaseEmulators();

  // طلب إذن الإشعارات فقط على الأجهزة المحمولة
  if (!kIsWeb) {
    await requestNotificationPermission();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) => const MyApp(),
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
      theme: ThemeData(primarySwatch: Colors.green),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
    );
  }
}
Future<void> _loadArabicFont() async {
  try {
    // No need to manually load if using Cairo font declared in pubspec.yaml
    // Flutter will handle it automatically
    safeDebugPrint('Arabic fonts loaded successfully');
  } catch (e) {
    safeDebugPrint('Error loading Arabic fonts: $e');
  }
}

 */








/* import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp(); // fallback
      }
    }
  } catch (e) {
    safeDebugPrint('⚠️ Firebase already initialized: $e');
  }

  // طلب إذن الإشعارات فقط على الأجهزة المحمولة (Android/iOS)
  if (!kIsWeb) {
    await requestNotificationPermission();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) => const MyApp(),
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
      theme: ThemeData(primarySwatch: Colors.green),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
    );
  }
}
 */ */
