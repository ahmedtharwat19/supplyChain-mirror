/* // services/app_initializer_service.dart
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
 */

/* 
// services/app_initializer_service.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'; // ✅ مضاف لاستخدام kIsWeb
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/services/firestore_date_services.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ مضاف لفحص الصلاحيات

class AppInitializerService {
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final UserSubscriptionService _subscriptionService = UserSubscriptionService();

  Future<InitializationResult> initializeApp() async {
    try {
      safeDebugPrint('🚀 Starting app initialization...');

      // 1. فحص الصلاحيات أولاً (للهواتف فقط وليس الويب)
      if (!kIsWeb) {
        safeDebugPrint('🛡️ Checking app permissions...');
        final notificationStatus = await Permission.notification.status;
        
        // إذا لم يمنح المستخدم صلاحية الإشعارات بعد، وجهه لصفحة الصلاحيات فوراً
        if (!notificationStatus.isGranted) {
          safeDebugPrint('⚠️ Notification permission not granted, redirecting to permissions page');
          
          // ⚠️ ملحوظة: استبدل '/permissions' بالمسار الحقيقي لشاشة الصلاحيات في ملف الـ Router لديك
          return InitializationResult(shouldNavigateTo: '/permissions'); 
        }
        safeDebugPrint('✅ Permissions are granted');
      }

      // 2. تهيئة التخزين المحلي
      safeDebugPrint('💾 Initializing local storage...');
      await HiveService.init();

      // 3. التحقق من بيانات المصادقة
      safeDebugPrint('🔐 Checking authentication data...');
      final hasAuthData = await HiveService.hasAuthData();
      final hasLicense = await HiveService.getLicense() != null;

      if (!hasAuthData) {
        safeDebugPrint('❌ No auth data found, redirecting to login');
        return InitializationResult(shouldNavigateTo: '/login');
      }

      // 4. التحقق من الاتصال بالإنترنت
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
        final subscriptionResult = await _subscriptionService.checkUserSubscription();

        if (subscriptionResult.isValid && !subscriptionResult.isExpired) {
          safeDebugPrint('✅ Valid subscription found');

          if (subscriptionResult.licenseId != null) {
            await HiveService.saveLicense(subscriptionResult.licenseId!);
          }

          _fetchUserDataInBackground();

          return InitializationResult(shouldNavigateTo: '/dashboard');
        } else {
          safeDebugPrint('⚠️ Subscription issue: ${subscriptionResult.timeLeftFormatted}');

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

  Future<void> _fetchUserDataInBackground() async {
    try {
      safeDebugPrint('🔄 Fetching user data in background...');
      await HiveService.debugUserName();

      final currentName = await HiveService.getUserName();
      safeDebugPrint('📝 Current name before fetch: "$currentName"');
      
      final userBox = Hive.box('userBox');
      final backupData = Map<String, dynamic>.from(userBox.toMap());
      safeDebugPrint('📦 Created backup of userBox with ${backupData.keys.length} keys');
      
      await _firestoreService.fetchAllUserData();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await HiveService.debugUserName();
      final newName = await HiveService.getUserName();
      safeDebugPrint('📝 Name after fetch: "$newName"');
      
      if ((newName == null || newName.isEmpty || newName == 'User' || newName == 'null') && 
          currentName != null && currentName.isNotEmpty && currentName != 'User' && currentName != 'null') {
        safeDebugPrint('   🔄 Restoring name to: "$currentName"');
        await HiveService.saveUserName(currentName);
      }
      
      safeDebugPrint('✅ Background data fetch completed');
    } catch (e) {
      safeDebugPrint('⚠️ Background data fetch failed: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
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
 */

// services/app_initializer_service.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/services/firestore_date_services.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class AppInitializerService {
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final UserSubscriptionService _subscriptionService = UserSubscriptionService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyLicense = 'license';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserId = 'user_id';

  Future<InitializationResult> initializeApp() async {
    try {
      safeDebugPrint('🚀 Starting app initialization...');

      // 1. فحص الصلاحيات أولاً (للهواتف فقط وليس الويب)
      if (!kIsWeb) {
        safeDebugPrint('🛡️ Checking app permissions...');
        final notificationStatus = await Permission.notification.status;
        
        if (!notificationStatus.isGranted) {
          safeDebugPrint('⚠️ Notification permission not granted, redirecting to permissions page');
          return InitializationResult(shouldNavigateTo: '/permissions'); 
        }
        safeDebugPrint('✅ Permissions are granted');
      }

      // 2. تهيئة SharedPreferences
      safeDebugPrint('💾 Initializing local storage...');
      await SharedPreferences.getInstance(); // فقط للتأكد من التهيئة

      // 3. التحقق من بيانات المصادقة
      safeDebugPrint('🔐 Checking authentication data...');
      final hasAuthData = await _hasAuthData();
      final hasLicense = await _getLicense() != null;

      if (!hasAuthData) {
        safeDebugPrint('❌ No auth data found, redirecting to login');
        return InitializationResult(shouldNavigateTo: '/login');
      }

      // 4. التحقق من الاتصال بالإنترنت
      safeDebugPrint('🌐 Checking internet connection...');
      final hasInternet = await _checkInternetConnection();

      if (hasAuthData && hasLicense) {
        safeDebugPrint('✅ User has auth data and license');

        // جلب البيانات في الخلفية
        _fetchUserDataInBackground();

        final authData = await _getAuthData();
        return InitializationResult(
          shouldNavigateTo: '/dashboard',
          extraData: authData,
        );
      }

      if (hasInternet) {
        safeDebugPrint('📡 Internet available, checking subscription...');
        final subscriptionResult = await _subscriptionService.checkUserSubscription();

        if (subscriptionResult.isValid && !subscriptionResult.isExpired) {
          safeDebugPrint('✅ Valid subscription found');

          if (subscriptionResult.licenseId != null) {
            await _saveLicense(subscriptionResult.licenseId!);
          }

          _fetchUserDataInBackground();

          return InitializationResult(shouldNavigateTo: '/dashboard');
        } else {
          safeDebugPrint('⚠️ Subscription issue: ${subscriptionResult.timeLeftFormatted}');

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
        final authData = await _getAuthData();
        return InitializationResult(
          shouldNavigateTo: '/dashboard',
          extraData: authData,
          showMessage: 'no_internet'.tr(),
        );
      }
    } catch (e) {
      safeDebugPrint('❌ App initialization failed: $e');

      // Fallback: التحقق من وجود بيانات مصادقة محلية
      final hasAuthData = await _hasAuthData();
      return InitializationResult(
        shouldNavigateTo: hasAuthData ? '/dashboard' : '/login',
      );
    }
  }

  Future<void> _fetchUserDataInBackground() async {
    try {
      safeDebugPrint('🔄 Fetching user data in background...');
      
      await _debugUserName();

      final currentName = await _getUserName();
      safeDebugPrint('📝 Current name before fetch: "$currentName"');
      
      // عمل نسخة احتياطية من البيانات المهمة
      final backupData = {
        'name': currentName,
        'email': await _getUserEmail(),
        'userId': await _getUserId(),
      };
      safeDebugPrint('📦 Created backup of user data: $backupData');
      
      await _firestoreService.fetchAllUserData();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _debugUserName();
      final newName = await _getUserName();
      safeDebugPrint('📝 Name after fetch: "$newName"');
      
      // استعادة الاسم إذا تم مسحه
      if ((newName == null || newName.isEmpty || newName == 'User' || newName == 'null') && 
          currentName != null && currentName.isNotEmpty && currentName != 'User' && currentName != 'null') {
        safeDebugPrint('   🔄 Restoring name to: "$currentName"');
        await _saveUserName(currentName);
        
        final restoredName = await _getUserName();
        safeDebugPrint('✅ Name after restore: "$restoredName"');
      } else if (newName == 'Ahmed') {
        safeDebugPrint('✅ Name is correct: "$newName"');
      } else {
        safeDebugPrint('⚠️ Unexpected name value: "$newName"');
      }
      
      safeDebugPrint('✅ Background data fetch completed');
    } catch (e) {
      safeDebugPrint('⚠️ Background data fetch failed: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      safeDebugPrint('❌ Connectivity check failed: $e');
      return false;
    }
  }

  // ==================== Helper Methods for Storage ====================
  
  Future<bool> _hasAuthData() async {
    final authData = await _secureStorage.read(key: _keyAuthData);
    return authData != null && authData.isNotEmpty;
  }

  Future<String?> _getAuthData() async {
    return await _secureStorage.read(key: _keyAuthData);
  }

  // Future<void> _saveAuthData(String data) async {
  //   await _secureStorage.write(key: _keyAuthData, value: data);
  // }

  Future<String?> _getLicense() async {
    return await _secureStorage.read(key: _keyLicense);
  }

  Future<void> _saveLicense(String license) async {
    await _secureStorage.write(key: _keyLicense, value: license);
  }

  Future<String?> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<void> _debugUserName() async {
    final name = await _getUserName();
    safeDebugPrint('🔍 Debug - Current user name: "$name"');
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