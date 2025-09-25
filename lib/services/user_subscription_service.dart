/* import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserSubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SubscriptionResult> checkUserSubscription() async {
    try {
      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        return await _checkLocalSubscription();
      } else {
        return await _checkFirebaseSubscription();
      }
    } catch (e) {
      debugPrint('🔥 Error in checkUserSubscription: $e');
      return SubscriptionResult.error(error: e.toString());
    }
  }

  Future<SubscriptionResult> _checkLocalSubscription() async {
    debugPrint('📴 Checking local subscription...');
    final localUser = await UserLocalStorage.getUser();
    
    if (localUser == null) {
      debugPrint('🚫 No local user found');
      return SubscriptionResult.invalid(reason: 'no_user');
    }

    final createdAtString = localUser['createdAt'] as String?;
    final createdAt = createdAtString != null ? DateTime.tryParse(createdAtString) : null;
    final duration = localUser['subscriptionDurationInDays'] as int? ?? 30;
    final isActive = localUser['isActive'] as bool? ?? false;

    if (createdAt == null) {
      debugPrint('⚠️ createdAt not found in local user data');
      return SubscriptionResult.invalid(reason: 'invalid_data');
    }

    final now = DateTime.now();
    final expiryDate = createdAt.add(Duration(days: duration));
    final daysLeft = expiryDate.difference(now).inDays;

    if (!isActive) {
      debugPrint('🔴 Account is inactive');
      return SubscriptionResult.expired(expiryDate: expiryDate);
    }

    if (now.isAfter(expiryDate)) {
      debugPrint('🔴 Local subscription expired on $expiryDate');
      return SubscriptionResult.expired(expiryDate: expiryDate);
    }

    debugPrint('🟢 Local subscription valid until $expiryDate ($daysLeft days left)');
    return SubscriptionResult.valid(
      expiryDate: expiryDate,
      daysLeft: daysLeft,
      isActive: isActive,
    );
  }

  Future<SubscriptionResult> _checkFirebaseSubscription() async {
    debugPrint('🌐 Checking Firebase subscription...');
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        debugPrint('❌ No Firebase user logged in');
        return SubscriptionResult.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('⛔️ User document not found');
        await _auth.signOut();
        return SubscriptionResult.invalid(reason: 'no_document');
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] == true;
      final durationDays = data['subscriptionDurationInDays'] ?? 30;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      if (createdAt == null) {
        debugPrint('⛔️ createdAt not found in user document');
        return SubscriptionResult.invalid(reason: 'invalid_data');
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(now).inDays;

      await _updateLocalUserData(user, data, createdAt, durationDays, isActive);

      if (!isActive) {
        debugPrint('🔴 Account is inactive in Firebase');
        return SubscriptionResult.expired(expiryDate: expiryDate);
      }

      if (now.isAfter(expiryDate)) {
        debugPrint('🔴 Firebase subscription expired on $expiryDate');
        await _firestore.collection('users').doc(user.uid).update({'isActive': false});
        await _auth.signOut();
        return SubscriptionResult.expired(expiryDate: expiryDate);
      }

      debugPrint('🟢 Firebase subscription valid until $expiryDate ($daysLeft days left)');
      return SubscriptionResult.valid(
        expiryDate: expiryDate,
        daysLeft: daysLeft,
        isActive: isActive,
      );
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');
      await _auth.signOut();
      return SubscriptionResult.error(error: e.toString());
    }
  }

  Future<void> _updateLocalUserData(
    User user,
    Map<String, dynamic> data,
    DateTime createdAt,
    int durationDays,
    bool isActive,
  ) async {
    try {
      final localUser = await UserLocalStorage.getUser();
      bool needUpdate = localUser == null;

      if (localUser != null) {
        final localCreatedAt = localUser['createdAt'] as DateTime?;
        final localDuration = localUser['subscriptionDurationInDays'] as int?;
        final localIsActive = localUser['isActive'] as bool?;

        if (localCreatedAt == null || 
            !localCreatedAt.isAtSameMomentAs(createdAt) ||
            localDuration != durationDays ||
            localIsActive != isActive) {
          needUpdate = true;
        }
      }

      if (needUpdate) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          subscriptionDurationInDays: durationDays,
          createdAt: createdAt,
          companyIds: List<String>.from(data['companyIds'] ?? []),
          factoryIds: List<String>.from(data['factoryIds'] ?? []),
          supplierIds: List<String>.from(data['supplierIds'] ?? []),
          isActive: isActive,
        );
        debugPrint('📦 Local user data updated');
      }
    } catch (e) {
      debugPrint('❌ Error updating local user data: $e');
    }
  }
}

class SubscriptionResult {
  final bool isValid;
  final bool isActive;
  final bool isExpired;
  final bool isExpiringSoon;
  final DateTime? expiryDate;
  final int daysLeft;
  final String? invalidReason;
  final String? error;

  SubscriptionResult._({
    required this.isValid,
    required this.isActive,
    required this.isExpired,
    required this.isExpiringSoon,
    this.expiryDate,
    this.daysLeft = 0,
    this.invalidReason,
    this.error,
  });

  factory SubscriptionResult.valid({
    required DateTime expiryDate,
    required int daysLeft,
    required bool isActive,
  }) {
    return SubscriptionResult._(
      isValid: true,
      isActive: isActive,
      isExpired: false,
      isExpiringSoon: daysLeft <= 3,
      expiryDate: expiryDate,
      daysLeft: daysLeft,
    );
  }

  factory SubscriptionResult.expired({required DateTime expiryDate}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: true,
      isExpiringSoon: false,
      expiryDate: expiryDate,
      daysLeft: 0,
    );
  }

  factory SubscriptionResult.invalid({required String reason}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: false,
      isExpiringSoon: false,
      invalidReason: reason,
    );
  }

  factory SubscriptionResult.error({required String error}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: false,
      isExpiringSoon: false,
      error: error,
    );
  }
}

// فئة منفصلة لعرض التنبيهات
class SubscriptionNotifier {
  static void showExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tr('membership_expired_title')),
        content: Text(tr('membership_expired_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('ok')),),
        ],
      ),
    );
  }

  static void showWarning(BuildContext context, SubscriptionResult result) {
    if (result.isExpiringSoon && !result.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subscription_expires_soon', 
              args: [result.daysLeft.toString()])),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subscription_expired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }
}

 */

/* 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

/// خدمة متكاملة لإدارة وتحقق حالة اشتراك المستخدم
class UserSubscriptionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;

  /// تهيئة الخدمة مع إمكانية حقن التبعيات للاختبار
  UserSubscriptionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivity = connectivity ?? Connectivity();

  /// التحقق الرئيسي من حالة الاشتراك (يتعامل مع الحالات المتصلة والغير متصلة)
  Future<SubscriptionResult> checkUserSubscription() async {
    try {
      // 1. التحقق من حالة الاتصال بالإنترنت
      final connectivityResult = await _connectivity.checkConnectivity();
      //final isOnline = connectivityResult != ConnectivityResult.none;
      //final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);
      final isOnline = connectivityResult.isNotEmpty &&
                 connectivityResult.any((result) => result != ConnectivityResult.none);



      // 2. التنفيذ بناءً على حالة الاتصال
      final result = isOnline
          ? await _checkOnlineSubscription()
          : await _checkOfflineSubscription();

      // 3. تسجيل النتائج للتحليل
      _logSubscriptionResult(result, isOnline);
      return result;
    } catch (e, stackTrace) {
      debugPrint('''
      🔴 Error in checkUserSubscription:
      Error: $e
      StackTrace: $stackTrace
      ''');

      return SubscriptionResult.error(
        error: 'subscription_check_failed'.tr(),
        details: e.toString(),
      );
    }
  }

  /// التحقق من الاشتراك عند الاتصال بالإنترنت
  Future<SubscriptionResult> _checkOnlineSubscription() async {
    try {
      // 1. التحقق من وجود مستخدم مسجل الدخول
      final user = _auth.currentUser;
      if (user == null) {
        return SubscriptionResult.invalid(reason: 'not_logged_in');
      }

      // 2. جلب بيانات المستخدم من Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        return SubscriptionResult.invalid(reason: 'user_not_found');
      }

      // 3. تحليل بيانات الاشتراك
      final data = userDoc.data()!;
      final subscriptionData = _parseSubscriptionData(data);

      // 4. التحقق من صلاحية الاشتراك
      if (!subscriptionData.isValid) {
        await _handleInvalidOnlineSubscription(user.uid, subscriptionData.isActive);
        return SubscriptionResult.expired(expiryDate: subscriptionData.expiryDate);
      }

      // 5. تخزين البيانات محلياً لاستخدامها في وضع عدم الاتصال
      await _cacheUserData(user, data, subscriptionData);

      return SubscriptionResult.valid(
        expiryDate: subscriptionData.expiryDate,
        daysLeft: subscriptionData.daysLeft,
        isActive: subscriptionData.isActive,
      );
    } catch (e) {
      debugPrint('Online subscription check error: $e');
      rethrow;
    }
  }

  /// تحليل بيانات الاشتراك من Firestore
/*   SubscriptionData _parseSubscriptionData(Map<String, dynamic> data) {
    final isActive = data['isActive'] as bool? ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final durationDays = data['subscriptionDurationInDays'] as int? ?? 30;

    if (createdAt == null) {
      throw Exception('Invalid creation date in user data');
    }

    final expiryDate = createdAt.add(Duration(days: durationDays));
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;

    return SubscriptionData(
      isActive: isActive,
      expiryDate: expiryDate,
      daysLeft: daysLeft,
      isValid: isActive && daysLeft > 0,
    );
  }
 */
  /// معالجة الاشتراك غير الصالح (تسجيل الخروج، تحديث الحالة)
  Future<void> _handleInvalidOnlineSubscription(String userId, bool isActive) async {
    if (isActive) {
      await _firestore.collection('users').doc(userId).update({'isActive': false});
    }
    await _auth.signOut();
  }

  /// تخزين بيانات المستخدم محلياً
/*   Future<void> _cacheUserData(
    User user,
    Map<String, dynamic> data,
    SubscriptionData subscriptionData,
  ) async {
    try {
await UserLocalStorage.saveUser(
  userId: user.uid,
  email: user.email ?? '',
  displayName: user.displayName,
  companyIds: data['companyIds']?.cast<String>(),
  factoryIds: data['factoryIds']?.cast<String>(),
  supplierIds: data['supplierIds']?.cast<String>(),
  subscriptionDurationInDays: subscriptionData.daysLeft, // الجديد هنا
  createdAt: null, // لم يعد مطلوباً
  isActive: subscriptionData.isActive,
);


      debugPrint('🔄 User data cached locally');
    } catch (e) {
      debugPrint('Failed to cache user data: $e');
    }
  }
 */

Future<void> _cacheUserData(
  User user,
  Map<String, dynamic> data,
  SubscriptionData subscriptionData,
) async {
  try {
    await UserLocalStorage.saveUser(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      companyIds: data['companyIds']?.cast<String>(),
      factoryIds: data['factoryIds']?.cast<String>(),
      supplierIds: data['supplierIds']?.cast<String>(),
      subscriptionDurationInDays: subscriptionData.daysLeft,
      expiryDate: subscriptionData.expiryDate, // Add this line
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: subscriptionData.isActive,
    );
    debugPrint('🔄 User data cached locally');
  } catch (e) {
    debugPrint('Failed to cache user data: $e');
  }
}

  /// التحقق من الاشتراك في وضع عدم الاتصال
  Future<SubscriptionResult> _checkOfflineSubscription() async {
    try {
      // 1. جلب البيانات المحفوظة
      final localData = await UserLocalStorage.getUser();
      if (localData == null) {
        return SubscriptionResult.invalid(reason: 'no_local_data');
      }

      // 2. تحليل البيانات المحلية
      final subscriptionData = _parseLocalSubscriptionData(localData);

      if (!subscriptionData.isValid) {
        return SubscriptionResult.expired(expiryDate: subscriptionData.expiryDate);
      }

      return SubscriptionResult.valid(
        expiryDate: subscriptionData.expiryDate,
        daysLeft: subscriptionData.daysLeft,
        isActive: subscriptionData.isActive,
      );
    } catch (e) {
      debugPrint('Offline subscription check error: $e');
      return SubscriptionResult.invalid(reason: 'invalid_local_data');
    }
  }

  /// تحليل بيانات الاشتراك المحلية
  SubscriptionData _parseLocalSubscriptionData(Map<String, dynamic> localData) {
  final isActive = localData['isActive'] as bool? ?? false;
  final expiryDateTimestamp = localData['expiryDate'] as Timestamp?;
  final durationDays = localData['subscriptionDurationInDays'] as int? ?? 0;
  
  DateTime expiryDate;
  
  if (expiryDateTimestamp != null) {
    expiryDate = expiryDateTimestamp.toDate();
  } else {
    // Fallback: calculate from duration if expiryDate is not cached
    expiryDate = DateTime.now().add(Duration(days: durationDays));
  }
  
  final daysLeft = expiryDate.difference(DateTime.now()).inDays;

  return SubscriptionData(
    isActive: isActive,
    expiryDate: expiryDate,
    daysLeft: daysLeft,
    isValid: isActive && daysLeft > 0,
  );
}

/* SubscriptionData _parseLocalSubscriptionData(Map<String, dynamic> localData) {
  final isActive = localData['isActive'] as bool? ?? false;
  final durationDays = localData['subscriptionDurationInDays'] as int? ?? 0;
  final expiryDate = DateTime.now().add(Duration(days: durationDays));
  final daysLeft = durationDays;

  return SubscriptionData(
    isActive: isActive,
    expiryDate: expiryDate,
    daysLeft: daysLeft,
    isValid: isActive && daysLeft > 0,
  );
}
 */
SubscriptionData _parseSubscriptionData(Map<String, dynamic> data) {
  final isActive = data['isActive'] as bool? ?? false;
  final expiryTimestamp = data['expiryDate'] as Timestamp?;
  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  final durationDays = data['subscriptionDurationInDays'] as int? ?? 30;

  DateTime expiryDate;
  
  // If expiryDate exists, use it directly
  if (expiryTimestamp != null) {
    expiryDate = expiryTimestamp.toDate();
  } 
  // If expiryDate doesn't exist but createdAt does, calculate it
  else if (createdAt != null) {
    expiryDate = createdAt.add(Duration(days: durationDays));
  }
  // If neither exists, throw a more descriptive error
  else {
    throw Exception('Missing both expiryDate and createdAt in user data. Cannot determine subscription validity.');
  }

  final now = DateTime.now();
  final daysLeft = expiryDate.difference(now).inDays;

  return SubscriptionData(
    isActive: isActive,
    expiryDate: expiryDate,
    daysLeft: daysLeft,
    isValid: isActive && now.isBefore(expiryDate),
  );
}

/* SubscriptionData _parseSubscriptionData(Map<String, dynamic> data) {
  final isActive = data['isActive'] as bool? ?? false;
  final expiryTimestamp = data['expiryDate'] as Timestamp?;
  final expiryDate = expiryTimestamp?.toDate();
  int durationDays = data['subscriptionDurationInDays'] ?? 0;

  if (expiryDate == null) {
    throw Exception('Missing expiry date in user data');
  }

  final now = DateTime.now();
  final daysLeft = expiryDate.difference(now).inDays;

  // تقليل عدد الأيام المتبقية في الاشتراك (يومياً)
  if (durationDays > daysLeft && daysLeft >= 0) {
    durationDays = daysLeft;
  }

  return SubscriptionData(
    isActive: isActive,
    expiryDate: expiryDate,
    daysLeft: daysLeft,
    isValid: isActive && now.isBefore(expiryDate),
  );
}
 */

  /// تسجيل نتائج التحقق للتحليل
  void _logSubscriptionResult(SubscriptionResult result, bool isOnline) {
    debugPrint('''
    📊 Subscription Check Result:
    - Mode: ${isOnline ? 'Online' : 'Offline'}
    - Valid: ${result.isValid}
    - Active: ${result.isActive}
    - Expired: ${result.isExpired}
    - Days Left: ${result.daysLeft}
    - Expiry Date: ${result.expiryDate}
    - Reason: ${result.reason}
    - Error: ${result.error}
    ''');
  }
}

/// نموذج بيانات الاشتراك الداخلية
class SubscriptionData {
  final bool isActive;
  final DateTime expiryDate;
  final int daysLeft;
  final bool isValid;

  SubscriptionData({
    required this.isActive,
    required this.expiryDate,
    required this.daysLeft,
    required this.isValid,
  });
}

/// نتيجة التحقق من الاشتراك
class SubscriptionResult {
  final bool isValid;
  final bool isActive;
  final bool isExpired;
  final bool isExpiringSoon;
  final DateTime? expiryDate;
  final int daysLeft;
  final String? reason;
  final String? error;
  final String? details;

  const SubscriptionResult._({
    required this.isValid,
    required this.isActive,
    required this.isExpired,
    required this.isExpiringSoon,
    this.expiryDate,
    this.daysLeft = 0,
    this.reason,
    this.error,
    this.details,
  });

  factory SubscriptionResult.valid({
    required DateTime expiryDate,
    required int daysLeft,
    required bool isActive,
  }) => SubscriptionResult._(
    isValid: true,
    isActive: isActive,
    isExpired: false,
    isExpiringSoon: daysLeft <= 7,
    expiryDate: expiryDate,
    daysLeft: daysLeft,
  );

  factory SubscriptionResult.expired({required DateTime expiryDate}) => SubscriptionResult._(
    isValid: false,
    isActive: false,
    isExpired: true,
    isExpiringSoon: false,
    expiryDate: expiryDate,
  );

  factory SubscriptionResult.invalid({required String reason}) => SubscriptionResult._(
    isValid: false,
    isActive: false,
    isExpired: false,
    isExpiringSoon: false,
    reason: reason,
  );

  factory SubscriptionResult.error({
    required String error,
    String? details,
  }) => SubscriptionResult._(
    isValid: false,
    isActive: false,
    isExpired: false,
    isExpiringSoon: false,
    error: error,
    details: details,
  );

  @override
  String toString() {
    return '''
SubscriptionStatus:
- Valid: $isValid
- Active: $isActive
- Expired: $isExpired
- Expiring Soon: $isExpiringSoon
- Days Left: $daysLeft
- Expiry Date: ${expiryDate?.toIso8601String()}
- Reason: $reason
- Error: $error
- Details: $details
''';
  }
}

/// مساعد لعرض التنبيهات للمستخدم
class SubscriptionNotifier {
  static void showExpiredDialog(BuildContext context, {required DateTime expiryDate}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('subscription_expired'.tr()),
        content: Text(
          'subscription_expired_message'.tr(args: [
            _formatDate(expiryDate),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  static void showWarning(BuildContext context, {required int daysLeft}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'subscription_expiring_soon'.tr(args: [daysLeft.toString()]),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} */

/* 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'device_fingerprint.dart';

/// كائن النتيجة الخاص بالاشتراك
class SubscriptionResult {
  final bool isValid;
  final bool isExpired;
  final DateTime? expiryDate;

  /// نص منسق للمدة المتبقية
  final String? timeLeftFormatted;

  SubscriptionResult({
    required this.isValid,
    required this.isExpired,
    this.expiryDate,
    this.timeLeftFormatted,
  });

  /// هل الاشتراك قرب ينتهي؟ (لو باقي أقل من يوم)
  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    final now = DateTime.now();
    final difference = expiryDate!.difference(now);
    return difference.inHours <= 168; // 7 أيام
  }
}

class UserSubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// التحقق الأساسي من الاشتراك باستخدام البصمة
  Future<bool> checkSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final subRef = _fs.collection('licenses').doc(user.uid);
    final snap = await subRef.get();

    if (!snap.exists) return false;

    final data = snap.data()!;
    final serverFingerprint = data['fingerprint'] as String?;
    final expiryDate = (data['expiryDate'] as Timestamp).toDate();

    // نولد البصمة الحالية
    final currentFingerprint = await DeviceFingerprint.generate();

    // نجيب البصمة المحلية
    final box = await Hive.openBox('auth');
    final localFingerprint = box.get('fingerprint');

    // تحقق من تاريخ الاشتراك
    if (DateTime.now().isAfter(expiryDate)) {
      return false; // الاشتراك منتهي
    }

    // أول مرة → خزّن البصمة
    if (serverFingerprint == null) {
      await subRef.set({'fingerprint': currentFingerprint},
          SetOptions(merge: true));
      await box.put('fingerprint', currentFingerprint);
      return true;
    }

    // تحقق ثلاثي
    if (serverFingerprint == currentFingerprint &&
        (localFingerprint == null || localFingerprint == currentFingerprint)) {
      // خزّنها محليًا لو مش موجودة
      if (localFingerprint == null) {
        await box.put('fingerprint', currentFingerprint);
      }
      return true;
    }

    // جهاز مختلف → منع الدخول
    return false;
  }

  /// نسخة متوافقة مع SplashScreen (ترجع SubscriptionResult)
  Future<SubscriptionResult> checkUserSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        timeLeftFormatted: null,
      );
    }

    final subRef = _fs.collection('licenses').doc(user.uid);
    final snap = await subRef.get();

    if (!snap.exists) {
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        timeLeftFormatted: null,
      );
    }

    final data = snap.data()!;
    final expiryDate = (data['expiryDate'] as Timestamp).toDate();

    final now = DateTime.now();
    final isExpired = now.isAfter(expiryDate);
    final isValid = await checkSubscription();

    String? formatted;
    if (!isExpired) {
      final difference = expiryDate.difference(now);

      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      final parts = <String>[];
      if (days > 0) parts.add("$days ${'days'.tr()}");
      if (hours > 0) parts.add("$hours ${'hours'.tr()}");
      if (minutes > 0) parts.add("$minutes ${'minutes'.tr()}");
      if (seconds > 0) parts.add("$seconds ${'seconds'.tr()}");

      formatted = parts.join(' ');
    }

    return SubscriptionResult(
      isValid: isValid,
      isExpired: isExpired,
      expiryDate: expiryDate,
      timeLeftFormatted: formatted,
    );
  }

  /// تمديد الاشتراك
  Future<void> extendSubscription(DateTime newExpiryDate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final currentFingerprint = await DeviceFingerprint.generate();

    await _fs.collection('licenses').doc(user.uid).set({
      'expiryDate': newExpiryDate,
      'fingerprint': currentFingerprint,
    }, SetOptions(merge: true));

    final box = await Hive.openBox('auth');
    await box.put('fingerprint', currentFingerprint);
  }

  /// إلغاء الاشتراك
  Future<void> cancelSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('licenses').doc(user.uid).delete();

    final box = await Hive.openBox('auth');
    await box.delete('fingerprint');
  }
}
 */

/*  Future<SubscriptionResult> checkUserSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }

    try {
      // البحث في مجموعة licenses بدلاً من subscriptions
      final querySnapshot = await _fs.collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      // الحصول على أول ترخيص فعال
      final licenseDoc = querySnapshot.docs.first;
      final data = licenseDoc.data();
      
      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      if (expiryTimestamp == null) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final expiryDate = expiryTimestamp.toDate();
      final now = DateTime.now();
      final isExpired = now.isAfter(expiryDate);
      
      // التحقق من البصمة (اختياري - يمكن إزالته إذا لم يكن مطلوبًا)
      final isValid = await _checkDeviceFingerprint(licenseDoc.id);

      // حساب الوقت المتبقي
      String? formattedTimeLeft;
      bool isExpiringSoon = false;

      if (!isExpired) {
        final difference = expiryDate.difference(now);
        
        // تحديد إذا كان الاشتراك على وشك الانتهاء (أقل من 7 أيام)
        isExpiringSoon = difference.inDays <= 7;
        
        final days = difference.inDays;
        final hours = difference.inHours % 24;
        final minutes = difference.inMinutes % 60;

        final parts = <String>[];
        if (days > 0) parts.add("$days ${'days'.tr()}");
        if (hours > 0) parts.add("$hours ${'hours'.tr()}");
        if (minutes > 0) parts.add("$minutes ${'minutes'.tr()}");

        formattedTimeLeft = parts.join(' ');
        
        // إذا لم يكن هناك أيام ولكن هناك ساعات أو دقائق
        if (formattedTimeLeft.isEmpty && difference.inHours > 0) {
          formattedTimeLeft = "${difference.inHours} ${'hours'.tr()}";
        } else if (formattedTimeLeft.isEmpty) {
          formattedTimeLeft = "${difference.inMinutes} ${'minutes'.tr()}";
        }
      }

      return SubscriptionResult(
        isValid: isValid,
        isExpired: isExpired,
        isExpiringSoon: isExpiringSoon,
        expiryDate: expiryDate,
        timeLeftFormatted: formattedTimeLeft,
      );
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }
  }
 */

/* 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'device_fingerprint.dart';

/// كائن النتيجة الخاص بالاشتراك
class SubscriptionResult {
  final bool isValid;
  final bool isExpired;
  final bool isExpiringSoon;
  final DateTime? expiryDate;

  /// نص منسق للمدة المتبقية
  final String? timeLeftFormatted;

  SubscriptionResult({
    required this.isValid,
    required this.isExpired,
    required this.isExpiringSoon,
    this.expiryDate,
    this.timeLeftFormatted,
  });
}

class UserSubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// التحقق من الاشتراك باستخدام مجموعة licenses
  Future<SubscriptionResult> checkUserSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }

    try {
      final querySnapshot = await _fs
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final licenseDoc = querySnapshot.docs.first;
      final data = licenseDoc.data();

      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      if (expiryTimestamp == null) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final expiryDate = expiryTimestamp.toDate();
      final now = DateTime.now();
      final isExpired = now.isAfter(expiryDate);

      // التحقق من البصمة ← إضافة هذا السطر
      final isValid = await _checkDeviceFingerprint(licenseDoc.id);

      // حساب الوقت المتبقي
      String? formattedTimeLeft;
      bool isExpiringSoon = false;

      if (!isExpired) {
        final difference = expiryDate.difference(now);
        isExpiringSoon = difference.inDays <= 7;

        final days = difference.inDays;
        final hours = difference.inHours % 24;
        final minutes = difference.inMinutes % 60;

        final parts = <String>[];
        if (days > 0) parts.add("$days ${'days'.tr()}");
        if (hours > 0) parts.add("$hours ${'hours'.tr()}");
        if (minutes > 0) parts.add("$minutes ${'minutes'.tr()}");

        formattedTimeLeft = parts.join(' ');
      }

      return SubscriptionResult(
        isValid: isValid, // ← استخدام نتيجة التحقق من البصمة
        isExpired: isExpired,
        isExpiringSoon: isExpiringSoon,
        expiryDate: expiryDate,
        timeLeftFormatted: formattedTimeLeft,
      );
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }
  }

  /// التحقق من بصمة الجهاز (اختياري)
  Future<bool> _checkDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final box = await Hive.openBox('auth');
      final localFingerprint = box.get('fingerprint');

      // إذا كانت البصمة المحلية مطابقة للبصمة الحالية
      if (localFingerprint != null && localFingerprint == currentFingerprint) {
        return true;
      }

      // التحقق من البصمة في الترخيص
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];
      //    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      // البحث عن البصمة الحالية في الأجهزة المسجلة
      final isDeviceRegistered = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);

      if (isDeviceRegistered) {
        // حفظ البصمة محليًا
        await box.put('fingerprint', currentFingerprint);
        return true;
      }

      // إذا لم يكن الجهاز مسجلاً وهناك مساحة لأجهزة جديدة
      if (devices.length < maxDevices) {
        // إضافة الجهاز الجديد
        final updatedDevices = [
          ...devices,
          {'fingerprint': currentFingerprint}
        ];
        await _fs.collection('licenses').doc(licenseId).update({
          'devices': updatedDevices,
          'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
        });

        // حفظ البصمة محليًا
        await box.put('fingerprint', currentFingerprint);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking device fingerprint: $e');
      return false;
    }
  }

  /// تمديد الاشتراك
  Future<void> extendSubscription(
      String licenseId, DateTime newExpiryDate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('licenses').doc(licenseId).update({
      'expiryDate': Timestamp.fromDate(newExpiryDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// إلغاء الاشتراك
  Future<void> cancelSubscription(String licenseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('licenses').doc(licenseId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });

    final box = await Hive.openBox('auth');
    await box.delete('fingerprint');
  }
    /// طلب إضافة جهاز جديد
  Future<void> requestNewDeviceSlot(String licenseId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('device_requests').add({
      'userId': user.uid,
      'licenseId': licenseId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deviceFingerprint': await DeviceFingerprint.generate(),
    });
  }

} */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
//import 'package:go_router/go_router.dart';
import 'device_fingerprint.dart';

/// كائن النتيجة الخاص بالاشتراك
class SubscriptionResult {
  final bool isValid;
  final bool isExpired;
  final bool isExpiringSoon;
  final DateTime? expiryDate;
  final bool needsDeviceRegistration;
  final String? licenseId;

  /// نص منسق للمدة المتبقية
  final String? timeLeftFormatted;

  SubscriptionResult({
    required this.isValid,
    required this.isExpired,
    required this.isExpiringSoon,
    this.expiryDate,
    this.timeLeftFormatted,
    this.needsDeviceRegistration = false,
    this.licenseId,
  });
}

class UserSubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// التحقق من الاشتراك باستخدام مجموعة licenses
  Future<SubscriptionResult> checkUserSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }

    try {
      final querySnapshot = await _fs
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final licenseDoc = querySnapshot.docs.first;
      final data = licenseDoc.data();

      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      if (expiryTimestamp == null) {
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final expiryDate = expiryTimestamp.toDate();
      final now = DateTime.now();
      final isExpired = now.isAfter(expiryDate);

      // التحقق من البصمة
      final fingerprintResult = await _checkDeviceFingerprint(licenseDoc.id);

      // حساب الوقت المتبقي
      String? formattedTimeLeft;
      bool isExpiringSoon = false;

      if (!isExpired) {
        final difference = expiryDate.difference(now);
        isExpiringSoon = difference.inDays <= 7;

        final days = difference.inDays;
        final hours = difference.inHours % 24;
        final minutes = difference.inMinutes % 60;

        final parts = <String>[];
        if (days > 0) parts.add("$days ${'days'.tr()}");
        if (hours > 0) parts.add("$hours ${'hours'.tr()}");
        if (minutes > 0) parts.add("$minutes ${'minutes'.tr()}");

        formattedTimeLeft = parts.join(' ');
      }

      return SubscriptionResult(
        isValid: fingerprintResult['isValid'] && !isExpired,
        isExpired: isExpired,
        isExpiringSoon: isExpiringSoon,
        expiryDate: expiryDate,
        timeLeftFormatted: formattedTimeLeft,
        needsDeviceRegistration: fingerprintResult['needsRegistration'],
        licenseId: licenseDoc.id,
      );
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
      return SubscriptionResult(
        isValid: false,
        isExpired: true,
        isExpiringSoon: false,
        timeLeftFormatted: null,
      );
    }
  }

  /// التحقق من بصمة الجهاز وإمكانية التسجيل
/*   Future<Map<String, dynamic>> _checkDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final box = await Hive.openBox('auth');
      final localFingerprint = box.get('fingerprint');

      // إذا كانت البصمة المحلية مطابقة للبصمة الحالية
      if (localFingerprint != null && localFingerprint == currentFingerprint) {
        return {'isValid': true, 'needsRegistration': false};
      }

      // التحقق من البصمة في الترخيص
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) {
        return {'isValid': false, 'needsRegistration': false};
      }

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      // البحث عن البصمة الحالية في الأجهزة المسجلة
      final isDeviceRegistered = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);

      if (isDeviceRegistered) {
        // حفظ البصمة محليًا
        await box.put('fingerprint', currentFingerprint);
        return {'isValid': true, 'needsRegistration': false};
      }

      // إذا لم يكن الجهاز مسجلاً وهناك مساحة لأجهزة جديدة
      if (devices.length < maxDevices) {
        // يمكن إضافة الجهاز تلقائيًا أو يحتاج إلى تسجيل
        return {'isValid': false, 'needsRegistration': true};
      }

      // لا توجد مساحة لأجهزة جديدة
      return {'isValid': false, 'needsRegistration': false};
    } catch (e) {
      debugPrint('❌ Error checking device fingerprint: $e');
      return {'isValid': false, 'needsRegistration': false};
    }
  }
 */

/// التحقق من بصمة الجهاز وإمكانية التسجيل
 Future<Map<String, dynamic>> _checkDeviceFingerprint(String licenseId) async {
  try {
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo(); // ✅ الحصول على بيانات الجهاز
    final box = await Hive.openBox('auth');
    final localFingerprint = box.get('fingerprint');

    // ✅ إذا كانت البصمة المحلية مطابقة للبصمة الحالية
    if (localFingerprint != null && localFingerprint == currentFingerprint) {
      return {'isValid': true, 'needsRegistration': false};
    }

    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      return {'isValid': false, 'needsRegistration': false};
    }

    final data = licenseDoc.data()!;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;

    // ✅ البحث عن البصمة الحالية في الأجهزة المسجلة
    final isDeviceRegistered = devices.any((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == currentFingerprint);

    if (isDeviceRegistered) {
      await box.put('fingerprint', currentFingerprint);
      return {'isValid': true, 'needsRegistration': false};
    }

    // ✅ إذا لم يكن مسجل وهناك مساحة لتسجيل الجهاز
    if (devices.length < maxDevices) {
      // ✅ تسجيل بيانات الجهاز بالكامل
      final updatedDevices = [
        ...devices,
        {
          'fingerprint': currentFingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceName': deviceInfo['deviceName'],
          'platform': deviceInfo['platform'],
          'model': deviceInfo['model'],
          'os': deviceInfo['os'],
          'browser': deviceInfo['browser'],
          'lastActive': DateTime.now().toIso8601String(),
        }
      ];

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': updatedDevices,
        'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
      });

      await box.put('fingerprint', currentFingerprint);

      return {'isValid': true, 'needsRegistration': false}; // ✅ الجهاز سُجّل تلقائياً
    }

    // لا توجد مساحة لأجهزة جديدة
    return {'isValid': false, 'needsRegistration': false};
  } catch (e) {
    debugPrint('❌ Error checking device fingerprint: $e');
    return {'isValid': false, 'needsRegistration': false};
  }
}
 

Future<void> _fixDeviceLimit(String licenseId, int maxDevices) async {
  try {
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) return;

    final data = licenseDoc.data()!;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];

    if (devices.length > maxDevices || deviceIds.length > maxDevices) {
      safeDebugPrint('🛠️ Fixing device limit for license: $licenseId');
      
      // أخذ الأجهزة الأحدث أولاً
      final sortedDevices = List.from(devices);
      sortedDevices.sort((a, b) {
        final aTime = a['lastActive'] ?? a['registeredAt'];
        final bTime = b['lastActive'] ?? b['registeredAt'];
        return bTime.compareTo(aTime);
      });

      final validDevices = sortedDevices.take(maxDevices).toList();
      final validDeviceIds = validDevices
          .map((device) => device['fingerprint'] as String)
          .toList();

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': validDevices,
        'deviceIds': validDeviceIds,
      });

      safeDebugPrint('✅ Fixed device limit: ${devices.length} → $maxDevices');
    }
  } catch (e) {
    safeDebugPrint('❌ Error fixing device limit: $e');
  }
}
/* Future<Map<String, dynamic>> _checkDeviceFingerprint(String licenseId) async {
  try {
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    final box = await Hive.openBox('auth');
    final localFingerprint = box.get('fingerprint');

    // ✅ التحقق من البصمة المحلية أولاً
    if (localFingerprint != null && localFingerprint == currentFingerprint) {
      return {'isValid': true, 'needsRegistration': false};
    }

    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      return {'isValid': false, 'needsRegistration': false};
    }

    final data = licenseDoc.data()!;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;
    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];

    // ✅ التحقق من أن عدد الأجهزة المسجلة لا يتجاوز الحد المسموح
    if (devices.length > maxDevices || deviceIds.length > maxDevices) {
      safeDebugPrint('⚠️ Warning: License has more devices than allowed!');
      // إصلاح تلقائي: أخذ أول جهازين فقط (أو حسب maxDevices)
      final validDevices = devices.take(maxDevices).toList();
      final validDeviceIds = deviceIds.take(maxDevices).toList();
      
      await _fs.collection('licenses').doc(licenseId).update({
        'devices': validDevices,
        'deviceIds': validDeviceIds,
      });
    }

    final isDeviceRegistered = devices.any((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == currentFingerprint);

    if (isDeviceRegistered) {
      await box.put('fingerprint', currentFingerprint);
      return {'isValid': true, 'needsRegistration': false};
    }

    // ✅ إذا لم يكن مسجل وهناك مساحة لتسجيل الجهاز
    if (devices.length < maxDevices) {
      return {'isValid': false, 'needsRegistration': true};
    }

    // ✅ لا توجد مساحة لأجهزة جديدة
    return {
      'isValid': false, 
      'needsRegistration': false,
      'reason': 'Device limit reached'
    };
  } catch (e) {
    debugPrint('❌ Error checking device fingerprint: $e');
    return {'isValid': false, 'needsRegistration': false};
  }
}
 */
Future<bool> registerDeviceFingerprint(String licenseId) async {
  try {
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) return false;

    final data = licenseDoc.data()!;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;

    // ✅ الإصلاح التلقائي إذا تجاوز الحد
    if (devices.length >= maxDevices) {
      await _fixDeviceLimit(licenseId, maxDevices);
      // إعادة تحميل البيانات بعد الإصلاح
      final updatedDoc = await _fs.collection('licenses').doc(licenseId).get();
      final updatedData = updatedDoc.data()!;
      final updatedDevices = updatedData['devices'] as List<dynamic>? ?? [];
      
      if (updatedDevices.length >= maxDevices) {
        return false; // لا تزال لا توجد مساحة
      }
    }

    final updatedDevices = [
      ...devices,
      {
        'fingerprint': currentFingerprint,
        'registeredAt': DateTime.now().toIso8601String(),
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': DateTime.now().toIso8601String(),
      }
    ];

    await _fs.collection('licenses').doc(licenseId).update({
      'devices': updatedDevices,
      'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
    });

    final box = await Hive.openBox('auth');
    await box.put('fingerprint', currentFingerprint);

    return true;
  } catch (e) {
    debugPrint('❌ Error registering device fingerprint: $e');
    return false;
  }
}

/* Future<bool> registerDeviceFingerprint(String licenseId) async {
  try {
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) return false;

    final data = licenseDoc.data()!;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;

    if (devices.length >= maxDevices) {
      return false;
    }

    // إضافة الجهاز بمعلومات كاملة - استخدام DateTime بدلاً من serverTimestamp
    final updatedDevices = [
      ...devices,
      {
        'fingerprint': currentFingerprint,
        'registeredAt': DateTime.now().toIso8601String(), // تغيير هنا
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': DateTime.now().toIso8601String(), // تغيير هنا
      }
    ];

    await _fs.collection('licenses').doc(licenseId).update({
      'devices': updatedDevices,
      'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
    });

    final box = await Hive.openBox('auth');
    await box.put('fingerprint', currentFingerprint);

    return true;
  } catch (e) {
    debugPrint('❌ Error registering device fingerprint: $e');
    return false;
  }
}
 */
/*   Future<bool> registerDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo(); // دالة جديدة

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      if (devices.length >= maxDevices) {
        return false;
      }

      // إضافة الجهاز بمعلومات كاملة
      final updatedDevices = [
        ...devices,
        {
          'fingerprint': currentFingerprint,
          'registeredAt': FieldValue.serverTimestamp(),
          'deviceName': deviceInfo['deviceName'],
          'platform': deviceInfo['platform'],
          'model': deviceInfo['model'],
          'browser': deviceInfo['browser'],
          'os': deviceInfo['os'],
          'lastActive': FieldValue.serverTimestamp(),
        }
      ];

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': updatedDevices,
        'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
      });

      final box = await Hive.openBox('auth');
      await box.put('fingerprint', currentFingerprint);

      return true;
    } catch (e) {
      debugPrint('❌ Error registering device fingerprint: $e');
      return false;
    }
  }
 */
/*   /// تسجيل بصمة جهاز جديدة
  Future<bool> registerDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      // التحقق من وجود مساحة كافية
      if (devices.length >= maxDevices) {
        return false;
      }

      // إضافة الجهاز الجديد
      final updatedDevices = [
        ...devices,
        {
          'fingerprint': currentFingerprint,
          'registeredAt': FieldValue.serverTimestamp(),
          'deviceName': 'Device ${devices.length + 1}'
        }
      ];

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': updatedDevices,
        'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
      });

      // حفظ البصمة محليًا
      final box = await Hive.openBox('auth');
      await box.put('fingerprint', currentFingerprint);

      return true;
    } catch (e) {
      debugPrint('❌ Error registering device fingerprint: $e');
      return false;
    }
  }
 */
/*   /// إلغاء تسجيل جهاز حالي
  Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
    try {
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];

      // إزالة الجهاز
      devices.removeWhere((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == fingerprint);

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': devices,
        'deviceIds': FieldValue.arrayRemove([fingerprint]),
      });

      // إزالة البصمة المحلية إذا كانت مطابقة
      final box = await Hive.openBox('auth');
      final localFingerprint = box.get('fingerprint');
      if (localFingerprint == fingerprint) {
        await box.delete('fingerprint');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error unregistering device: $e');
      return false;
    }
  }
 */
  /// إلغاء تسجيل جهاز حالي
/*   Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;

      // التحقق من أن المستخدم هو مالك الترخيص
      if (data['userId'] != user.uid) {
        safeDebugPrint('User does not own this license');
        return false;
      }

      List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];

      // إزالة الجهاز
      devices.removeWhere((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == fingerprint);

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': devices,
        'deviceIds': FieldValue.arrayRemove([fingerprint]),
      });

      // إزالة البصمة المحلية إذا كانت مطابقة
      final box = await Hive.openBox('auth');
      final localFingerprint = box.get('fingerprint');
      if (localFingerprint == fingerprint) {
        await box.delete('fingerprint');
      }

      return true;
    } catch (e) {
      safeDebugPrint('❌ Error unregistering device: $e');

      // معالجة أنواع الأخطاء المختلفة
      if (e is FirebaseException && e.code == 'permission-denied') {
        safeDebugPrint('Permission denied - user may not own this license');
      }

      return false;
    }
  }
 */

  Future<bool> _verifyLicenseOwnership(String licenseId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      return data['userId'] == user.uid;
    } catch (e) {
      safeDebugPrint('Error verifying license ownership: $e');
      return false;
    }
  }

  /// إلغاء تسجيل جهاز حالي وتسجيل الجهاز الحالي تلقائياً
/*   Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
    try {
      // التحقق من ملكية الترخيص أولاً
      if (!await _verifyLicenseOwnership(licenseId)) {
        safeDebugPrint('User does not own this license');
        return false;
      }

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      // إزالة الجهاز
      devices.removeWhere((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == fingerprint);

      // تسجيل الجهاز الحالي تلقائياً إذا كانت هناك مساحة
      final currentFingerprint = await DeviceFingerprint.generate();
      final box = await Hive.openBox('auth');

      if (devices.length < maxDevices) {
        // إضافة الجهاز الحالي
        devices.add({
          'fingerprint': currentFingerprint,
          'registeredAt': FieldValue.serverTimestamp(),
          'deviceName': 'Device ${devices.length + 1}'
        });

        // حفظ البصمة محلياً
        await box.put('fingerprint', currentFingerprint);
      }

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': devices,
        'deviceIds': FieldValue.arrayRemove([fingerprint]),
      });

      // إزالة البصمة المحلية إذا كانت مطابقة للبصمة المحذوفة
      final localFingerprint = box.get('fingerprint');
      if (localFingerprint == fingerprint) {
        await box.delete('fingerprint');
      }

      return true;
    } catch (e) {
      safeDebugPrint('❌ Error unregistering device: $e');

      if (e is FirebaseException && e.code == 'permission-denied') {
        safeDebugPrint('Permission denied - check Firestore rules');
      }

      return false;
    }
  }
 */

/// في دالة unregisterDevice، تأكد من تحديث lastActive للجهاز الحالي
/* Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
  try {
    if (!await _verifyLicenseOwnership(licenseId)) {
      return false;
    }

    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) return false;

    final data = licenseDoc.data()!;
    List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;

    // إزالة الجهاز
    devices.removeWhere((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == fingerprint);

    // تسجيل الجهاز الحالي تلقائياً
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    final box = await Hive.openBox('auth');
    
    if (devices.length < maxDevices) {
      // إضافة الجهاز الحالي بمعلومات كاملة
      devices.add({
        'fingerprint': currentFingerprint,
        'registeredAt': FieldValue.serverTimestamp(),
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      await box.put('fingerprint', currentFingerprint);
    }

    await _fs.collection('licenses').doc(licenseId).update({
      'devices': devices,
      'deviceIds': FieldValue.arrayRemove([fingerprint]),
    });

    final localFingerprint = box.get('fingerprint');
    if (localFingerprint == fingerprint) {
      await box.delete('fingerprint');
    }

    return true;
  } catch (e) {
    safeDebugPrint('❌ Error unregistering device: $e');
    return false;
  }
}
 */

/// إلغاء تسجيل جهاز حالي وتسجيل الجهاز الحالي تلقائياً
Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
  try {
    // التحقق من ملكية الترخيص أولاً
    if (!await _verifyLicenseOwnership(licenseId)) {
      safeDebugPrint('User does not own this license');
      return false;
    }

    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    
    if (!licenseDoc.exists) return false;

    final data = licenseDoc.data()!;
    List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];
    final maxDevices = data['maxDevices'] as int? ?? 1;

    // إزالة الجهاز
    devices.removeWhere((device) =>
        device is Map<String, dynamic> &&
        device['fingerprint'] == fingerprint);

    // تسجيل الجهاز الحالي تلقائياً إذا كانت هناك مساحة
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    final box = await Hive.openBox('auth');
    
    if (devices.length < maxDevices) {
      // إضافة الجهاز الحالي بمعلومات كاملة - استخدام DateTime.now() بدلاً من serverTimestamp()
      devices.add({
        'fingerprint': currentFingerprint,
        'registeredAt': DateTime.now().toIso8601String(), // استخدام DateTime بدلاً من serverTimestamp
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': DateTime.now().toIso8601String(), // استخدام DateTime بدلاً من serverTimestamp
      });
      
      await box.put('fingerprint', currentFingerprint);
    }

    await _fs.collection('licenses').doc(licenseId).update({
      'devices': devices,
      'deviceIds': FieldValue.arrayRemove([fingerprint]),
    });

    final localFingerprint = box.get('fingerprint');
    if (localFingerprint == fingerprint) {
      await box.delete('fingerprint');
    }

    return true;
  } catch (e) {
    safeDebugPrint('❌ Error unregistering device: $e');
    
    if (e is FirebaseException && e.code == 'invalid-argument') {
      safeDebugPrint('Invalid argument error - check timestamp usage in arrays');
    }
    
    return false;
  }
}

  /// الحصول على الأجهزة المسجلة
  Future<List<Map<String, dynamic>>> getRegisteredDevices(
      String licenseId) async {
    try {
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return [];

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];

      return devices.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('❌ Error getting registered devices: $e');
      return [];
    }
  }

  /// تمديد الاشتراك
  Future<void> extendSubscription(
      String licenseId, DateTime newExpiryDate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('licenses').doc(licenseId).update({
      'expiryDate': Timestamp.fromDate(newExpiryDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// إلغاء الاشتراك
  Future<void> cancelSubscription(String licenseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('licenses').doc(licenseId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });

    final box = await Hive.openBox('auth');
    await box.delete('fingerprint');
  }

  /// طلب إضافة جهاز جديد
  Future<void> requestNewDeviceSlot(String licenseId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _fs.collection('device_requests').add({
      'userId': user.uid,
      'licenseId': licenseId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deviceFingerprint': await DeviceFingerprint.generate(),
    });
  }
}
