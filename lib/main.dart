// lib/main.dart

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
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
  
  // ✅ تهيئة Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      safeDebugPrint('✅ Firebase initialized');
        if (kDebugMode) {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(false);
  }
    }
  } catch (e) {
    safeDebugPrint('❌ Firebase error: $e');
  }

  // ✅ تهيئة الترجمة
  await EasyLocalization.ensureInitialized();

  // ✅ طلب الأذونات عند بدء التطبيق تم إزالته:
  // الطريقة الجديدة لا تحتاج طلب صلاحيات يدوي خالص — شاشة تثبيت
  // أندرويد القياسية تطلب ما يلزم تلقائيًا فقط عند الحاجة الفعلية.

  // ✅ تشغيل الخدمات الخلفية (لا تنتظر)
  unawaited(_initSecondaryBackgroundServices());
  unawaited(VersionChecker.init());

  // ✅ طباعة رابط التحميل للتأكد
  final downloadUrl = VersionChecker.getDownloadUrlAndroid();
  safeDebugPrint('📥 Main - Download URL: $downloadUrl');
  
  GoRouter.optionURLReflectsImperativeAPIs = true;

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
          ChangeNotifierProvider(create: (_) => DashboardSettingsProvider()),
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