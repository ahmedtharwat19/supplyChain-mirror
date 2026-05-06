// services/app_initializer_service.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/services/firestore_date_services.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AppInitializerService {
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final UserSubscriptionService _subscriptionService =
      UserSubscriptionService();

  Future<InitializationResult> initializeApp() async {
    try {
      safeDebugPrint('🚀 Starting app initialization...');

      // 1. تهيئة التخزين المحلي
      safeDebugPrint('💾 Initializing local storage...');
      await HiveService.init();

      // 2. التحقق من بيانات المصادقة
      safeDebugPrint('🔐 Checking authentication data...');
      final hasAuthData = await HiveService.hasAuthData();
      final hasLicense = await HiveService.getLicense() != null;

      if (!hasAuthData) {
        safeDebugPrint('❌ No auth data found, redirecting to login');
        return InitializationResult(shouldNavigateTo: '/login');
      }

      // 3. التحقق من الاتصال بالإنترنت
      safeDebugPrint('🌐 Checking internet connection...');
      final hasInternet = await _checkInternetConnection();

      if (hasAuthData && hasLicense) {
        safeDebugPrint('✅ User has auth data and license');

        // جلب البيانات في الخلفية
        _fetchUserDataInBackground();

        final authData = await HiveService.getAuthData();
        return InitializationResult(
          shouldNavigateTo: '/dashboard',
          extraData: authData,
        );
      }

      if (hasInternet) {
        safeDebugPrint('📡 Internet available, checking subscription...');
        final subscriptionResult =
            await _subscriptionService.checkUserSubscription();

        if (subscriptionResult.isValid && !subscriptionResult.isExpired) {
          safeDebugPrint('✅ Valid subscription found');

          if (subscriptionResult.licenseId != null) {
            await HiveService.saveLicense(subscriptionResult.licenseId!);
          }

          _fetchUserDataInBackground();

          return InitializationResult(shouldNavigateTo: '/dashboard');
        } else {
          safeDebugPrint(
              '⚠️ Subscription issue: ${subscriptionResult.timeLeftFormatted}');

          if (subscriptionResult.timeLeftFormatted != null &&
              subscriptionResult.timeLeftFormatted!.contains('device')) {
            return InitializationResult(
              shouldNavigateTo: '/license/request',
              showMessage: subscriptionResult.timeLeftFormatted!,
            );
          }

          return InitializationResult(shouldNavigateTo: '/license/request');
        }
      } else {
        safeDebugPrint('📴 No internet, using cached data');
        final authData = await HiveService.getAuthData();
        return InitializationResult(
          shouldNavigateTo: '/dashboard',
          extraData: authData,
          showMessage: 'no_internet'.tr(),
        );
      }
    } catch (e) {
      safeDebugPrint('❌ App initialization failed: $e');

      // Fallback: التحقق من وجود بيانات مصادقة محلية
      final hasAuthData = await HiveService.hasAuthData();
      return InitializationResult(
        shouldNavigateTo: hasAuthData ? '/dashboard' : '/login',
      );
    }
  }

/*   Future<void> _fetchUserDataInBackground() async {
    try {
      safeDebugPrint('🔄 Fetching user data in background...');
      await _firestoreService.fetchAllUserData();
      safeDebugPrint('✅ Background data fetch completed');
    } catch (e) {
      safeDebugPrint('⚠️ Background data fetch failed: $e');
    }
  } */

/* Future<void> _fetchUserDataInBackground() async {
  try {
    safeDebugPrint('🔄 Fetching user data in background...');
    
    // ✅ حفظ الاسم الحالي قبل جلب البيانات
    final currentName = await HiveService.getUserName();
    safeDebugPrint('📝 Current name before fetch: $currentName');
    
    await _firestoreService.fetchAllUserData();
    
        // ✅ استعادة الاسم إذا تم مسحه
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ إذا تم مسح الاسم، استرجاعه
    final newName = await HiveService.getUserName();
    if ((newName == null || newName.isEmpty || newName == 'User') && 
        currentName != null && currentName.isNotEmpty && currentName != 'User') {
      safeDebugPrint('⚠️ Name was cleared during fetch, restoring to: $currentName');
      await HiveService.saveUserName(currentName);
    }
    
    safeDebugPrint('✅ Background data fetch completed');
  } catch (e) {
    safeDebugPrint('⚠️ Background data fetch failed: $e');
  }
} 
 */

Future<void> _fetchUserDataInBackground() async {
  try {
    safeDebugPrint('🔄 Fetching user data in background...');
    
       // ✅ تشخيص قبل الجلب
    await HiveService.debugUserName();

    // ✅ حفظ الاسم الحالي قبل جلب البيانات
    final currentName = await HiveService.getUserName();
    safeDebugPrint('📝 Current name before fetch: "$currentName"');
    
    // ✅ حفظ جميع بيانات المستخدم الحالية كنسخة احتياطية
    final userBox = Hive.box('userBox');
    final backupData = Map<String, dynamic>.from(userBox.toMap());
    safeDebugPrint('📦 Created backup of userBox with ${backupData.keys.length} keys');
    
    await _firestoreService.fetchAllUserData();
    
    // ✅ انتظار حتى تكتمل الكتابة
    await Future.delayed(const Duration(milliseconds: 500));
    
        
    // ✅ تشخيص بعد الجلب
    await HiveService.debugUserName();
    
    // ✅ التحقق من الاسم بعد الجلب
    final newName = await HiveService.getUserName();
    safeDebugPrint('📝 Name after fetch: "$newName"');
    
    // ✅ إذا تم مسح الاسم، استرجاعه من النسخة الاحتياطية
    if ((newName == null || newName.isEmpty || newName == 'User' || newName == 'null') && 
        currentName != null && currentName.isNotEmpty && currentName != 'User' && currentName != 'null') {
      safeDebugPrint('⚠️ Name was cleared during fetch!');
      safeDebugPrint('   - Old name: "$currentName"');
      safeDebugPrint('   - New name: "$newName"');
      safeDebugPrint('🔄 Restoring name to: "$currentName"');
      await HiveService.saveUserName(currentName);
      
      // ✅ التحقق من نجاح الاستعادة
      final restoredName = await HiveService.getUserName();
      safeDebugPrint('✅ Name after restore: "$restoredName"');
    } else if (newName == 'Ahmed') {
      safeDebugPrint('✅ Name is correct: "$newName"');
    } else {
      safeDebugPrint('⚠️ Unexpected name value: "$newName"');
    }
    
    // ✅ طباعة جميع مفاتيح userBox للتشخيص
    final allKeys = userBox.keys.toList();
    safeDebugPrint('📦 userBox keys after fetch: $allKeys');
    
    safeDebugPrint('✅ Background data fetch completed');
  } catch (e) {
    safeDebugPrint('⚠️ Background data fetch failed: $e');
  }
}

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      // ✅ Fix: Check if NONE is NOT inside the list
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      safeDebugPrint('❌ Connectivity check failed: $e');
      return false;
    }
  }
}

class InitializationResult {
  final String shouldNavigateTo;
  final dynamic extraData;
  final String? showMessage;

  InitializationResult({
    required this.shouldNavigateTo,
    this.extraData,
    this.showMessage,
  });
}
