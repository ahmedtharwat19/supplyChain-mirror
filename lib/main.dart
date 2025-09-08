import 'package:easy_localization/easy_localization.dart';
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
import 'firebase_options.dart';
import 'router.dart';
import 'services/license_service.dart';
import 'notifications/license_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

      debugPrint('Firebase initialization completed');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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
      debugPrint('Permission request error: $e');
    }
  }
}

Future<void> _loadAppResources() async {
  try {
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('App resources loaded successfully');
  } catch (e) {
    debugPrint('Resource loading error: $e');
  }
}

Future<void> main() async {
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
    debugPrint('Initialization failed: $e');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // اختبار الترجمة هنا للتأكد من عملها
    //debugPrint('Translation test - manufacturing.shelf_life: ${'manufacturing.shelf_life'.tr()}');

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
}

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
      
      debugPrint('Firebase initialization completed');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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

      debugPrint('Firebase initialization completed');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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
      debugPrint('Permission request error: $e');
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
    debugPrint('App resources loaded successfully');
  } catch (e) {
    debugPrint('Resource loading error: $e');
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
    debugPrint('Initialization failed: $e');
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
    debugPrint('⚠️ Firebase already initialized: $e');
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
    debugPrint('Arabic fonts loaded successfully');
  } catch (e) {
    debugPrint('Error loading Arabic fonts: $e');
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
    debugPrint('⚠️ Firebase already initialized: $e');
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
