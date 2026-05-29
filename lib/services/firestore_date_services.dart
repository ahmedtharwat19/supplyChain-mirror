/* // services/firestore_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class FirestoreDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // دالة رئيسية لجلب جميع بيانات المستخدم
  Future<Map<String, dynamic>> fetchAllUserData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      safeDebugPrint('🔄 Starting to fetch all user data for: ${user.uid}');

      // جلب جميع البيانات بشكل متوازي
      final results = await Future.wait([
        _fetchUserData(user.uid),
        _fetchUserCompanies(user.uid),
        _fetchUserFactories(user.uid),
        _fetchUserVendors(user.uid),
        _fetchUserItems(user.uid),
        _fetchUserPurchaseOrders(user.uid),
        _fetchUserManufacturingOrders(user.uid),
        _fetchUserFinishedProducts(user.uid),
        _fetchUserLicenseData(user.uid),
        _fetchUserLicenseRequests(user.uid),
        _fetchUserDeviceRequests(user.uid),
        _fetchUserNotifications(user.uid),
      ], eagerError: true);

      final allData = {
        'user': results[0],
        'companies': results[1],
        'factories': results[2],
        'vendors': results[3],
        'items': results[4],
        'purchaseOrders': results[5],
        'manufacturingOrders': results[6],
        'finishedProducts': results[7],
        'license': results[8],
        'licenseRequests': results[9],
        'deviceRequests': results[10],
        'notifications': results[11],
        'lastSync': DateTime.now().toIso8601String(),
        'userId': user.uid,
      };

      await _saveAllDataToHive(allData);
      safeDebugPrint('✅ All user data fetched and saved successfully');
      return allData;

    } catch (e) {
      safeDebugPrint('❌ Error fetching user data: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // الدوال المساعدة لجلب البيانات من كل مجموعة
  // ────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }

  Future<List<Map<String, dynamic>>> _fetchUserCompanies(String userId) async {
    final query = await _firestore
        .collection('companies')
        .where('userId', isEqualTo: userId)
        .get();
    
    final companies = query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();

    // جلب stock_movements لكل company
    for (var company in companies) {
      final stockMovements = await _fetchCompanyStockMovements(company['id']);
      company['stock_movements'] = stockMovements;
    }

    return companies;
  }

  Future<List<Map<String, dynamic>>> _fetchCompanyStockMovements(String companyId) async {
    try {
      final query = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('stock_movements')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();
    } catch (e) {
      safeDebugPrint('Error fetching stock movements for company $companyId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserFactories(String userId) async {
    final query = await _firestore
        .collection('factories')
        .where('userId', isEqualTo: userId)
        .get();
    
    final factories = query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();

    // جلب inventory لكل factory
    for (var factory in factories) {
      final inventory = await _fetchFactoryInventory(factory['id']);
      factory['inventory'] = inventory;
    }

    return factories;
  }

  Future<List<Map<String, dynamic>>> _fetchFactoryInventory(String factoryId) async {
    try {
      final query = await _firestore
          .collection('factories')
          .doc(factoryId)
          .collection('inventory')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();
    } catch (e) {
      safeDebugPrint('Error fetching inventory for factory $factoryId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserVendors(String userId) async {
    final query = await _firestore
        .collection('vendors')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserItems(String userId) async {
    final query = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserPurchaseOrders(String userId) async {
    final query = await _firestore
        .collection('purchase_orders')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserManufacturingOrders(String userId) async {
    final query = await _firestore
        .collection('manufacturing_orders')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserFinishedProducts(String userId) async {
    final query = await _firestore
        .collection('finished_products')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchUserLicenseData(String userId) async {
    final query = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.isNotEmpty 
        ? {'id': query.docs.first.id, ...query.docs.first.data()}
        : {};
  }

  Future<List<Map<String, dynamic>>> _fetchUserLicenseRequests(String userId) async {
    final query = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserDeviceRequests(String userId) async {
    final query = await _firestore
        .collection('device_requests')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserNotifications(String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50) // آخر 50 إشعار
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  // حفظ البيانات في Hive
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _saveAllDataToHive(Map<String, dynamic> allData) async {
    try {
      // حفظ البيانات الرئيسية
      await HiveService.saveUserData(allData);

      // حفظ البيانات في صناديق منفصلة للوصول السريع
      await Future.wait([
        HiveService.saveSetting('user_profile', allData['user']),
        HiveService.saveSetting('user_companies', allData['companies']),
        HiveService.saveSetting('user_factories', allData['factories']),
        HiveService.saveSetting('user_vendors', allData['vendors']),
        HiveService.saveSetting('user_items', allData['items']),
        HiveService.saveSetting('user_purchase_orders', allData['purchaseOrders']),
        HiveService.saveSetting('user_manufacturing_orders', allData['manufacturingOrders']),
        HiveService.saveSetting('user_finished_products', allData['finishedProducts']),
        HiveService.saveSetting('user_license', allData['license']),
        HiveService.saveSetting('user_license_requests', allData['licenseRequests']),
        HiveService.saveSetting('user_device_requests', allData['deviceRequests']),
        HiveService.saveSetting('user_notifications', allData['notifications']),
        HiveService.saveSetting('last_sync', allData['lastSync']),
      ]);

      safeDebugPrint('✅ All user data saved to Hive successfully');
    } catch (e) {
      safeDebugPrint('❌ Error saving data to Hive: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // دوال مساعدة للوصول إلى البيانات المحلية
  // ────────────────────────────────────────────────────────────────────────

 // في services/firestore_data_service.dart - تصحيح الدوال من السطر 294

Future<Map<String, dynamic>> getLocalUserProfile() async {
  final data = await HiveService.getSetting('user_profile', defaultValue: {});
  return Map<String, dynamic>.from(data ?? {});
}

Future<List<dynamic>> getLocalCompanies() async {
  final data = await HiveService.getSetting('user_companies', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalFactories() async {
  final data = await HiveService.getSetting('user_factories', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalVendors() async {
  final data = await HiveService.getSetting('user_vendors', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalItems() async {
  final data = await HiveService.getSetting('user_items', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalPurchaseOrders() async {
  final data = await HiveService.getSetting('user_purchase_orders', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalManufacturingOrders() async {
  final data = await HiveService.getSetting('user_manufacturing_orders', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalFinishedProducts() async {
  final data = await HiveService.getSetting('user_finished_products', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<Map<String, dynamic>> getLocalLicense() async {
  final data = await HiveService.getSetting('user_license', defaultValue: {});
  return Map<String, dynamic>.from(data ?? {});
}

Future<List<dynamic>> getLocalLicenseRequests() async {
  final data = await HiveService.getSetting('user_license_requests', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalDeviceRequests() async {
  final data = await HiveService.getSetting('user_device_requests', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

Future<List<dynamic>> getLocalNotifications() async {
  final data = await HiveService.getSetting('user_notifications', defaultValue: []);
  return List<dynamic>.from(data ?? []);
}

  Future<DateTime?> getLastSyncTime() async {
    final lastSync = await HiveService.getSetting<String>('last_sync');
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  // ────────────────────────────────────────────────────────────────────────
  // التحقق من وجود بيانات محلية
  // ────────────────────────────────────────────────────────────────────────

  Future<bool> hasLocalData() async {
    final lastSync = await getLastSyncTime();
    return lastSync != null;
  }

  // ────────────────────────────────────────────────────────────────────────
  // مسح البيانات المحلية
  // ────────────────────────────────────────────────────────────────────────

  Future<void> clearLocalData() async {
    await HiveService.clearAllData();
    safeDebugPrint('🗑️ All local data cleared');
  }
} */


// services/firestore_data_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class FirestoreDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين
  static const String _keyUserData = 'user_data';
  static const String _keyCompanies = 'user_companies';
  static const String _keyFactories = 'user_factories';
  static const String _keyVendors = 'user_vendors';
  static const String _keyItems = 'user_items';
  static const String _keyPurchaseOrders = 'user_purchase_orders';
  static const String _keyManufacturingOrders = 'user_manufacturing_orders';
  static const String _keyFinishedProducts = 'user_finished_products';
  static const String _keyLicense = 'user_license';
  static const String _keyLicenseRequests = 'user_license_requests';
  static const String _keyDeviceRequests = 'user_device_requests';
  static const String _keyNotifications = 'user_notifications';
  static const String _keyLastSync = 'last_sync';

  // دالة رئيسية لجلب جميع بيانات المستخدم
  Future<Map<String, dynamic>> fetchAllUserData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      safeDebugPrint('🔄 Starting to fetch all user data for: ${user.uid}');

      // جلب جميع البيانات بشكل متوازي
      final results = await Future.wait([
        _fetchUserData(user.uid),
        _fetchUserCompanies(user.uid),
        _fetchUserFactories(user.uid),
        _fetchUserVendors(user.uid),
        _fetchUserItems(user.uid),
        _fetchUserPurchaseOrders(user.uid),
        _fetchUserManufacturingOrders(user.uid),
        _fetchUserFinishedProducts(user.uid),
        _fetchUserLicenseData(user.uid),
        _fetchUserLicenseRequests(user.uid),
        _fetchUserDeviceRequests(user.uid),
        _fetchUserNotifications(user.uid),
      ], eagerError: true);

      final allData = {
        'user': results[0],
        'companies': results[1],
        'factories': results[2],
        'vendors': results[3],
        'items': results[4],
        'purchaseOrders': results[5],
        'manufacturingOrders': results[6],
        'finishedProducts': results[7],
        'license': results[8],
        'licenseRequests': results[9],
        'deviceRequests': results[10],
        'notifications': results[11],
        'lastSync': DateTime.now().toIso8601String(),
        'userId': user.uid,
      };

      await _saveAllDataToStorage(allData);
      safeDebugPrint('✅ All user data fetched and saved successfully');
      return allData;

    } catch (e) {
      safeDebugPrint('❌ Error fetching user data: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // الدوال المساعدة لجلب البيانات من كل مجموعة
  // ────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }

  Future<List<Map<String, dynamic>>> _fetchUserCompanies(String userId) async {
    final query = await _firestore
        .collection('companies')
        .where('userId', isEqualTo: userId)
        .get();
    
    final companies = query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();

    // جلب stock_movements لكل company
    for (var company in companies) {
      final stockMovements = await _fetchCompanyStockMovements(company['id']);
      company['stock_movements'] = stockMovements;
    }

    return companies;
  }

  Future<List<Map<String, dynamic>>> _fetchCompanyStockMovements(String companyId) async {
    try {
      final query = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('stock_movements')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();
    } catch (e) {
      safeDebugPrint('Error fetching stock movements for company $companyId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserFactories(String userId) async {
    final query = await _firestore
        .collection('factories')
        .where('userId', isEqualTo: userId)
        .get();
    
    final factories = query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();

    // جلب inventory لكل factory
    for (var factory in factories) {
      final inventory = await _fetchFactoryInventory(factory['id']);
      factory['inventory'] = inventory;
    }

    return factories;
  }

  Future<List<Map<String, dynamic>>> _fetchFactoryInventory(String factoryId) async {
    try {
      final query = await _firestore
          .collection('factories')
          .doc(factoryId)
          .collection('inventory')
          .get();
      
      return query.docs.map((doc) => ({
        'id': doc.id,
        ...doc.data()
      })).toList();
    } catch (e) {
      safeDebugPrint('Error fetching inventory for factory $factoryId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserVendors(String userId) async {
    final query = await _firestore
        .collection('vendors')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserItems(String userId) async {
    final query = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserPurchaseOrders(String userId) async {
    final query = await _firestore
        .collection('purchase_orders')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserManufacturingOrders(String userId) async {
    final query = await _firestore
        .collection('manufacturing_orders')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserFinishedProducts(String userId) async {
    final query = await _firestore
        .collection('finished_products')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchUserLicenseData(String userId) async {
    final query = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.isNotEmpty 
        ? {'id': query.docs.first.id, ...query.docs.first.data()}
        : {};
  }

  Future<List<Map<String, dynamic>>> _fetchUserLicenseRequests(String userId) async {
    final query = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserDeviceRequests(String userId) async {
    final query = await _firestore
        .collection('device_requests')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUserNotifications(String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    
    return query.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  // حفظ البيانات في SharedPreferences و SecureStorage
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _saveAllDataToStorage(Map<String, dynamic> allData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // حفظ البيانات في SecureStorage (بيانات حساسة)
      await _secureStorage.write(key: _keyUserData, value: json.encode(allData['user'] ?? {}));
      
      // حفظ البيانات في SharedPreferences (بيانات غير حساسة)
      await Future.wait([
        prefs.setString(_keyCompanies, json.encode(allData['companies'] ?? [])),
        prefs.setString(_keyFactories, json.encode(allData['factories'] ?? [])),
        prefs.setString(_keyVendors, json.encode(allData['vendors'] ?? [])),
        prefs.setString(_keyItems, json.encode(allData['items'] ?? [])),
        prefs.setString(_keyPurchaseOrders, json.encode(allData['purchaseOrders'] ?? [])),
        prefs.setString(_keyManufacturingOrders, json.encode(allData['manufacturingOrders'] ?? [])),
        prefs.setString(_keyFinishedProducts, json.encode(allData['finishedProducts'] ?? [])),
        prefs.setString(_keyLicense, json.encode(allData['license'] ?? {})),
        prefs.setString(_keyLicenseRequests, json.encode(allData['licenseRequests'] ?? [])),
        prefs.setString(_keyDeviceRequests, json.encode(allData['deviceRequests'] ?? [])),
        prefs.setString(_keyNotifications, json.encode(allData['notifications'] ?? [])),
        prefs.setString(_keyLastSync, allData['lastSync'] ?? DateTime.now().toIso8601String()),
      ]);

      safeDebugPrint('✅ All user data saved to storage successfully');
    } catch (e) {
      safeDebugPrint('❌ Error saving data to storage: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // دوال مساعدة للوصول إلى البيانات المحلية
  // ────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLocalUserProfile() async {
    final data = await _secureStorage.read(key: _keyUserData);
    if (data != null) {
      return Map<String, dynamic>.from(json.decode(data));
    }
    return {};
  }

  Future<List<dynamic>> getLocalCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyCompanies);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalFactories() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFactories);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalVendors() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyVendors);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyItems);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalPurchaseOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyPurchaseOrders);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalManufacturingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyManufacturingOrders);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalFinishedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFinishedProducts);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<Map<String, dynamic>> getLocalLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyLicense);
    if (data != null) {
      return Map<String, dynamic>.from(json.decode(data));
    }
    return {};
  }

  Future<List<dynamic>> getLocalLicenseRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyLicenseRequests);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalDeviceRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyDeviceRequests);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<List<dynamic>> getLocalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyNotifications);
    if (data != null) {
      return List<dynamic>.from(json.decode(data));
    }
    return [];
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_keyLastSync);
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  // ────────────────────────────────────────────────────────────────────────
  // التحقق من وجود بيانات محلية
  // ────────────────────────────────────────────────────────────────────────

  Future<bool> hasLocalData() async {
    final lastSync = await getLastSyncTime();
    return lastSync != null;
  }

  // ────────────────────────────────────────────────────────────────────────
  // مسح البيانات المحلية
  // ────────────────────────────────────────────────────────────────────────

  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
    safeDebugPrint('🗑️ All local data cleared');
  }
}