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
}