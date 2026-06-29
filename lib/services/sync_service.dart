/* // lib/services/sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // لمنع التزامن المتزامن المتعدد
  bool _isSyncing = false;
  DateTime? _lastFullSync;
  static const Duration _fullSyncInterval = Duration(minutes: 30);

  // المستمعات الحية (realtime)
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _statsSubscription;

  /// بدء الاستماع للتحديثات المباشرة (بعد أن يكون المستخدم مسجلاً)
  void startRealtimeSync() {
    stopRealtimeSync();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // مستمع لتغيرات وثيقة المستخدم
    _userSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) async {
      if (doc.exists) {
        await _updateUserDataFromDoc(doc);
      }
    });
  }

  void stopRealtimeSync() {
    _userSubscription?.cancel();
    _statsSubscription?.cancel();
  }

  /// مزامنة كاملة في الخلفية (تستخدم بعد التوجيه أو عند السحب للتحديث)
  Future<void> syncAllInBackground({bool force = false}) async {
    if (_isSyncing) return;
    if (!force &&
        _lastFullSync != null &&
        DateTime.now().difference(_lastFullSync!) < _fullSyncInterval) {
      safeDebugPrint('⏳ Skipping full sync, last sync was recent');
      return;
    }

    _isSyncing = true;
    safeDebugPrint('🔄 Starting background full sync...');

    try {
      await Future.wait([
        syncUserData(),
        syncDashboardCounts(),
        checkSubscriptionStatus(),
      ]);
      _lastFullSync = DateTime.now();
      safeDebugPrint('✅ Background full sync completed');
    } catch (e) {
      safeDebugPrint('⚠️ Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// مزامنة بيانات المستخدم الأساسية
  Future<void> syncUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      await _updateUserDataFromDoc(doc);
    }
  }

  Future<void> _updateUserDataFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userData = {
      'userId': userId,
      'email': data['email'] ?? '',
      'displayName': data['displayName'] ?? '',
      'name': data['name'] ?? '',
      'companyIds': List<String>.from(data['companyIds'] ?? []),
      'factoryIds': List<String>.from(data['factoryIds'] ?? []),
      'supplierIds': List<String>.from(data['supplierIds'] ?? []),
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
      'subscriptionDurationInDays': data['subscriptionDurationInDays'] ?? 30,
      'isActive': data['isActive'] ?? true,
      'isAdmin': data['isAdmin'] ?? false,
    };
    await HiveService.saveUserData(userData);
    safeDebugPrint('✅ User data synced to Hive');
  }

  /// مزامنة الإحصائيات (أعداد فقط) باستخدام count() أو التجميع
/*   Future<void> syncDashboardCounts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    safeDebugPrint('📊 Fetching dashboard counts from Firestore...');
    
    try {
      // استخدام count() لجلب الأعداد فقط - أسرع بكثير
      final itemsCount = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      
      final vendorsCount = await _firestore
          .collection('vendors')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      
      final ordersCount = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      
      // جلب إجمالي المبلغ - لا يمكن باستخدام count فقط، نستخدم aggregation أو نجمع بذكاء
      double totalAmount = 0.0;
      final amountQuery = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .get(); // للحصول على totalAmount بعد الضريبة - هذا ضروري لأنه لا يمكن عمل sum مباشرة
      totalAmount = amountQuery.docs.fold<double>(
        0.0, 
        (double currentSum, doc) => currentSum + ((doc['totalAmountAfterTax'] ?? 0.0) as num).toDouble()
      );
      
      final manufacturingCount = await _firestore
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      
      final finishedCount = await _getFinishedProductsCount(userId);
      
      final stats = {
        'totalItems': itemsCount.count,
        'totalSuppliers': vendorsCount.count,
        'totalOrders': ordersCount.count,
        'totalAmount': totalAmount,
        'totalManufacturingOrders': manufacturingCount.count,
        'totalFinishedProducts': finishedCount,
        'totalReports': 7, // يمكن تعديله لاحقاً
      };
      
      await HiveService.cacheData('dashboard_stats', stats);
      await HiveService.cacheData('dashboard_stats_last_updated', DateTime.now().toIso8601String());
      safeDebugPrint('✅ Dashboard counts synced: items=${itemsCount.count}, orders=${ordersCount.count}');
    } catch (e) {
      safeDebugPrint('❌ Failed to sync dashboard counts: $e');
    }
  }
   */

  // داخل class SyncService، تعديل syncDashboardCounts
  Future<void> syncDashboardCounts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    safeDebugPrint('📊 Fetching dashboard counts from Firestore...');

    try {
      // 1. عدد العناصر
      final itemsCount = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 2. عدد الموردين
      final vendorsCount = await _firestore
          .collection('vendors')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 3. عدد أوامر الشراء بحالة pending فقط
      final ordersCount = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending') // ✅ إضافة فلتر الحالة
          .count()
          .get();

      // 4. إجمالي المبلغ لأوامر الشراء pending (إذا أردت)
      double totalAmount = 0.0;
      final amountQuery = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      totalAmount = amountQuery.docs.fold<double>(
          0.0,
          (total, doc) =>
              total + ((doc['totalAmountAfterTax'] ?? 0.0) as num).toDouble());

      // 5. عدد أوامر التصنيع
      final manufacturingCount = await _firestore
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 6. عدد المنتجات التامة (من finished_products)
      final finishedCount = await _getFinishedProductsCount(userId);

      // 7. عدد المصانع (من factories التي تخص الشركات التابعة للمستخدم)
      final factoriesCount = await _getFactoriesCount(userId);

      // تخزين كل البيانات في dashboard_stats
      final stats = {
        'totalItems': itemsCount.count,
        'totalSuppliers': vendorsCount.count,
        'totalOrders': ordersCount.count,
        'totalAmount': totalAmount,
        'totalManufacturingOrders': manufacturingCount.count,
        'totalFinishedProducts': finishedCount,
        'totalFactories': factoriesCount, // ✅ إضافة عدد المصانع
        'totalReports': 7,
      };

      await HiveService.cacheData('dashboard_stats', stats);
      await HiveService.cacheData(
          'dashboard_stats_last_updated', DateTime.now().toIso8601String());
      safeDebugPrint(
          '✅ Dashboard counts synced: orders(pending)=${ordersCount.count}, factories=$factoriesCount, finished=$finishedCount');
    } catch (e) {
      safeDebugPrint('❌ Failed to sync dashboard counts: $e');
    }
  }

  /// جلب عدد المصانع التي تخص الشركات التابعة للمستخدم
  Future<int> _getFactoriesCount(String userId) async {
    try {
      final userData = await HiveService.getUserData();
      final companyIds = userData?['companyIds'] as List<String>? ?? [];
      if (companyIds.isEmpty) return 0;

      int totalFactories = 0;
      for (final companyId in companyIds) {
        final count = await _firestore
            .collection('factories')
            .where('companyIds', arrayContains: companyId)
            .count()
            .get();
        totalFactories += count.count ?? 0;
      }
      return totalFactories;
    } catch (e) {
      safeDebugPrint('Error fetching factories count: $e');
      return 0;
    }
  }

  Future<int?> _getFinishedProductsCount(String userId) async {
    final userData = await HiveService.getUserData();
    final companyIds = userData?['companyIds'] as List<String>? ?? [];
    if (companyIds.isNotEmpty) {
      int total = 0;
      for (final companyId in companyIds) {
        final count = await _firestore
            .collection('finished_products')
            .where('companyId', isEqualTo: companyId)
            .count()
            .get();
        total += count.count!;
      }
      return total;
    } else {
      final count = await _firestore
          .collection('finished_products')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      return count.count;
    }
  }

  /// التحقق من حالة الاشتراك وتحديث Hive
  Future<void> checkSubscriptionStatus() async {
    final service = UserSubscriptionService();
    final result = await service.checkUserSubscription();

    await HiveService.cacheData('subscription_status', {
      'isExpiringSoon': result.isExpiringSoon,
      'isExpired': result.isExpired,
      'timeLeftFormatted': result.timeLeftFormatted,
      'expiryDate': result.expiryDate?.toIso8601String(),
    });

    if (result.licenseId != null) {
      await HiveService.saveLicense(result.licenseId!);
    }
  }

  /// الحصول على البيانات من Hive بسرعة للـ Dashboard
  Future<Map<String, dynamic>> getLocalDashboardStats() async {
    final stats = await HiveService.getCachedData('dashboard_stats') ?? {};
    return stats;
  }

  /// التحقق من وجود بيانات محلية كافية للمستخدم القديم
  Future<bool> hasCompleteLocalData() async {
    final hasUser = await HiveService.hasAuthData();
    final hasLicense = await HiveService.getLicense() != null;
    final stats = await HiveService.getCachedData('dashboard_stats');
    return hasUser && hasLicense && stats != null;
  }

  void dispose() {
    stopRealtimeSync();
  }
}
 */

// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // لمنع التزامن المتزامن المتعدد
  bool _isSyncing = false;
  DateTime? _lastFullSync;
  static const Duration _fullSyncInterval = Duration(minutes: 30);

  // المستمعات الحية (realtime)
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _statsSubscription;

  // ✅ مفاتيح التخزين
  static const String _keyAuthData = 'auth_data';
  static const String _keyUserData = 'user_data';
  static const String _keyLicense = 'license';
  static const String _keySubscriptionStatus = 'subscription_status';
  static const String _keyDashboardStats = 'dashboard_stats';
  static const String _keyDashboardStatsLastUpdated = 'dashboard_stats_last_updated';
  static const String _keyLastFullSync = 'last_full_sync';

  /// بدء الاستماع للتحديثات المباشرة (بعد أن يكون المستخدم مسجلاً)
  void startRealtimeSync() {
    stopRealtimeSync();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // مستمع لتغيرات وثيقة المستخدم
    _userSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) async {
      if (doc.exists) {
        await _updateUserDataFromDoc(doc);
      }
    });
  }

  void stopRealtimeSync() {
    _userSubscription?.cancel();
    _statsSubscription?.cancel();
  }

  /// مزامنة كاملة في الخلفية (تستخدم بعد التوجيه أو عند السحب للتحديث)
  Future<void> syncAllInBackground({bool force = false}) async {
    if (_isSyncing) return;
    
    if (!force && _lastFullSync != null &&
        DateTime.now().difference(_lastFullSync!) < _fullSyncInterval) {
      safeDebugPrint('⏳ Skipping full sync, last sync was recent');
      return;
    }

    _isSyncing = true;
    safeDebugPrint('🔄 Starting background full sync...');

    try {
      await Future.wait([
        syncUserData(),
        syncDashboardCounts(),
        checkSubscriptionStatus(),
      ]);
      _lastFullSync = DateTime.now();
      
      // ✅ حفظ وقت آخر مزامنة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastFullSync, _lastFullSync!.millisecondsSinceEpoch);
      
      safeDebugPrint('✅ Background full sync completed');
    } catch (e) {
      safeDebugPrint('⚠️ Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// مزامنة بيانات المستخدم الأساسية
  Future<void> syncUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      await _updateUserDataFromDoc(doc);
    }
  }

  Future<void> _updateUserDataFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userData = {
      'userId': userId,
      'email': data['email'] ?? '',
      'displayName': data['displayName'] ?? '',
      'name': data['name'] ?? '',
      'companyIds': List<String>.from(data['companyIds'] ?? []),
      'factoryIds': List<String>.from(data['factoryIds'] ?? []),
      'supplierIds': List<String>.from(data['supplierIds'] ?? []),
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
      'subscriptionDurationInDays': data['subscriptionDurationInDays'] ?? 30,
      'isActive': data['isActive'] ?? true,
      'isAdmin': data['isAdmin'] ?? false,
    };
    
    // ✅ حفظ في SecureStorage (بيانات حساسة)
    await _secureStorage.write(key: _keyUserData, value: json.encode(userData));
    
    // ✅ حفظ اسم المستخدم بشكل منفصل للوصول السريع
    final prefs = await SharedPreferences.getInstance();
    final userName = userData['displayName']?.toString() ?? 
                     userData['name']?.toString() ?? 
                     userData['email']?.toString().split('@').first ?? 
                     'User';
    await prefs.setString('user_name', userName);
    
    safeDebugPrint('✅ User data synced to SecureStorage');
  }

  /// مزامنة الإحصائيات
  Future<void> syncDashboardCounts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    safeDebugPrint('📊 Fetching dashboard counts from Firestore...');

    try {
      // 1. عدد العناصر
      final itemsCount = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 2. عدد الموردين
      final vendorsCount = await _firestore
          .collection('vendors')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 3. عدد أوامر الشراء بحالة pending فقط
      final ordersCount = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // 4. إجمالي المبلغ لأوامر الشراء pending
      double totalAmount = 0.0;
      final amountQuery = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      totalAmount = amountQuery.docs.fold<double>(
          0.0,
          (total, doc) =>
              total + ((doc['totalAmountAfterTax'] ?? 0.0) as num).toDouble());

      // 5. عدد أوامر التصنيع
      final manufacturingCount = await _firestore
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      // 6. عدد المنتجات التامة
      final finishedCount = await _getFinishedProductsCount(userId);

      // 7. عدد المصانع
      final factoriesCount = await _getFactoriesCount(userId);

      final stats = {
        'totalItems': itemsCount.count,
        'totalSuppliers': vendorsCount.count,
        'totalOrders': ordersCount.count,
        'totalAmount': totalAmount,
        'totalManufacturingOrders': manufacturingCount.count,
        'totalFinishedProducts': finishedCount,
        'totalFactories': factoriesCount,
        'totalReports': 7,
      };

      // ✅ حفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDashboardStats, json.encode(stats));
      await prefs.setString(_keyDashboardStatsLastUpdated, DateTime.now().toIso8601String());
      
      safeDebugPrint('✅ Dashboard counts synced: orders(pending)=${ordersCount.count}, factories=$factoriesCount, finished=$finishedCount');
    } catch (e) {
      safeDebugPrint('❌ Failed to sync dashboard counts: $e');
    }
  }

  /// جلب عدد المصانع
  Future<int> _getFactoriesCount(String userId) async {
    try {
      final userDataJson = await _secureStorage.read(key: _keyUserData);
      if (userDataJson == null) return 0;
      
      final userData = json.decode(userDataJson) as Map<String, dynamic>;
      final companyIds = List<String>.from(userData['companyIds'] ?? []);
      if (companyIds.isEmpty) return 0;

      int totalFactories = 0;
      for (final companyId in companyIds) {
        final count = await _firestore
            .collection('factories')
            .where('companyIds', arrayContains: companyId)
            .count()
            .get();
        totalFactories += count.count ?? 0;
      }
      return totalFactories;
    } catch (e) {
      safeDebugPrint('Error fetching factories count: $e');
      return 0;
    }
  }

  Future<int?> _getFinishedProductsCount(String userId) async {
    try {
      final userDataJson = await _secureStorage.read(key: _keyUserData);
      if (userDataJson == null) return 0;
      
      final userData = json.decode(userDataJson) as Map<String, dynamic>;
      final companyIds = List<String>.from(userData['companyIds'] ?? []);
      
      if (companyIds.isNotEmpty) {
        int total = 0;
        for (final companyId in companyIds) {
          final count = await _firestore
              .collection('finished_products')
              .where('companyId', isEqualTo: companyId)
              .count()
              .get();
          total += count.count!;
        }
        return total;
      } else {
        final count = await _firestore
            .collection('finished_products')
            .where('userId', isEqualTo: userId)
            .count()
            .get();
        return count.count;
      }
    } catch (e) {
      safeDebugPrint('Error fetching finished products count: $e');
      return 0;
    }
  }

  /// التحقق من حالة الاشتراك
  Future<void> checkSubscriptionStatus() async {
    final service = UserSubscriptionService();
    final result = await service.checkUserSubscription();

    final subscriptionData = {
      'isExpiringSoon': result.isExpiringSoon,
      'isExpired': result.isExpired,
      'timeLeftFormatted': result.timeLeftFormatted,
      'expiryDate': result.expiryDate?.toIso8601String(),
    };

    // ✅ حفظ في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubscriptionStatus, json.encode(subscriptionData));

    if (result.licenseId != null) {
      await _secureStorage.write(key: _keyLicense, value: result.licenseId);
    }
    
    safeDebugPrint('✅ Subscription status synced: isExpired=${result.isExpired}');
  }

  /// الحصول على البيانات من SharedPreferences بسرعة للـ Dashboard
  Future<Map<String, dynamic>> getLocalDashboardStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_keyDashboardStats);
    if (statsJson != null) {
      return Map<String, dynamic>.from(json.decode(statsJson));
    }
    return {};
  }

  /// التحقق من وجود بيانات محلية كافية للمستخدم القديم
  Future<bool> hasCompleteLocalData() async {
    final authData = await _secureStorage.read(key: _keyAuthData);
    final license = await _secureStorage.read(key: _keyLicense);
    final prefs = await SharedPreferences.getInstance();
    final stats = prefs.getString(_keyDashboardStats);
    
    return authData != null && license != null && stats != null;
  }

  /// ✅ استعادة وقت آخر مزامنة
  Future<void> loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt(_keyLastFullSync);
    if (lastSyncMillis != null) {
      _lastFullSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    }
  }

  void dispose() {
    stopRealtimeSync();
  }
}