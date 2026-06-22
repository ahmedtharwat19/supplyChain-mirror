// lib/services/reports_data_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// خدمة موحدة لجلب بيانات التقارير مع كاش مدمج
class ReportsDataService {
  static const String _cacheKeyPrefix = 'reports_cache_';
  static const String _cacheTimeKey = 'reports_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 10);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // الشركات
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<Map<String, dynamic>>> getUserCompanies(
    bool isArabic, {
    bool forceRefresh = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final cacheKey = '${_cacheKeyPrefix}companies';

    if (!forceRefresh) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached.cast<Map<String, dynamic>>();
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userCompanyIds = (userDoc.data()?['companyIds'] as List?)
          ?.cast<String>() ?? [];

      if (userCompanyIds.isEmpty) return [];

      final companiesSnapshot = await _firestore
          .collection('companies')
          .where(FieldPath.documentId, whereIn: userCompanyIds)
          .get();

      final companies = companiesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': isArabic
              ? (data['nameAr'] ?? data['nameEn'] ?? doc.id)
              : (data['nameEn'] ?? data['nameAr'] ?? doc.id),
          'nameAr': data['nameAr'] ?? doc.id,
          'nameEn': data['nameEn'] ?? doc.id,
        };
      }).toList();

      await _saveToCache(cacheKey, companies);
      return companies;
    } catch (e) {
      safeDebugPrint('Error loading companies: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // المصانع
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<Map<String, dynamic>>> getFactoriesForCompany(
    String companyId,
    bool isArabic, {
    bool forceRefresh = false,
  }) async {
    if (companyId.isEmpty) return [];

    final cacheKey = '${_cacheKeyPrefix}factories_$companyId';

    if (!forceRefresh) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached.cast<Map<String, dynamic>>();
    }

    try {
      final snapshot = await _firestore
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .get();

      final factories = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': isArabic
              ? (data['nameAr'] ?? data['nameEn'] ?? doc.id)
              : (data['nameEn'] ?? data['nameAr'] ?? doc.id),
          'nameAr': data['nameAr'] ?? doc.id,
          'nameEn': data['nameEn'] ?? doc.id,
        };
      }).toList();

      await _saveToCache(cacheKey, factories);
      return factories;
    } catch (e) {
      safeDebugPrint('Error loading factories: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // الأصناف (Items)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<Map<String, Map<String, dynamic>>> getItemsMap({
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}items';

    if (!forceRefresh) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) {
        return Map<String, Map<String, dynamic>>.from(cached);
      }
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      final itemsMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        itemsMap[doc.id] = doc.data();
      }

      await _saveToCache(cacheKey, itemsMap);
      return itemsMap;
    } catch (e) {
      safeDebugPrint('Error loading items: $e');
      return {};
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // مخزون المصنع (مع الأسعار)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<Map<String, Map<String, dynamic>>> getFactoryInventory(
    String factoryId, {
    bool forceRefresh = false,
  }) async {
    if (factoryId.isEmpty) return {};

    final cacheKey = '${_cacheKeyPrefix}inventory_$factoryId';

    if (!forceRefresh) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) {
        return Map<String, Map<String, dynamic>>.from(cached);
      }
    }

    try {
      final snapshot = await _firestore
          .collection('factories')
          .doc(factoryId)
          .collection('inventory')
          .get();

      final inventoryMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unitPrice = data['unitPrice'] ??
            data['averagePrice'] ??
            data['price'] ??
            0.0;

        inventoryMap[doc.id] = {
          'quantity': (data['quantity'] as num?)?.toDouble() ?? 0,
          'unitPrice': unitPrice.toDouble(),
          'expiryDate': data['expiryDate'],
          'batchNumber': data['batchNumber'] ?? '',
          ...data,
        };
      }

      await _saveToCache(cacheKey, inventoryMap);
      return inventoryMap;
    } catch (e) {
      safeDebugPrint('Error loading inventory: $e');
      return {};
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // حركات المخزون
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<QueryDocumentSnapshot>> getStockMovements({
    required String companyId,
    required String factoryId,
    String? itemId,
    String? movementType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: factoryId);

      if (itemId != null && itemId.isNotEmpty) {
        query = query.where('itemId', isEqualTo: itemId);
      }

      if (movementType != null && movementType != 'all' && movementType.isNotEmpty) {
        query = query.where('type', isEqualTo: movementType);
      }

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      safeDebugPrint('Error loading stock movements: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ أوامر الشراء
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<QueryDocumentSnapshot>> getPurchaseOrders({
    required String companyId,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('purchase_orders')
          .where('companyId', isEqualTo: companyId);

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplierId', isEqualTo: supplierId);
      }

      if (startDate != null) {
        query = query.where('orderDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('orderDate', descending: true);

      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      safeDebugPrint('Error loading purchase orders: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ الموردين
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<Map<String, dynamic>>> getSuppliersForCompany(
    String companyId,
    bool isArabic, {
    bool forceRefresh = false,
  }) async {
    if (companyId.isEmpty) return [];

    final cacheKey = '${_cacheKeyPrefix}suppliers_$companyId';

    if (!forceRefresh) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached.cast<Map<String, dynamic>>();
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userSupplierIds = (userDoc.data()?['supplierIds'] as List?)
          ?.cast<String>() ?? [];

      if (userSupplierIds.isEmpty) return [];

      final suppliers = <Map<String, dynamic>>[];

      for (final supplierId in userSupplierIds) {
        final doc = await _firestore
            .collection('vendors')
            .doc(supplierId)
            .get();

        if (!doc.exists) continue;

        final data = doc.data()!;
        final vendorCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];

        // إذا كان companyIds فارغاً، نعتبره مرتبطاً بكل الشركات
        if (vendorCompanyIds.isEmpty || vendorCompanyIds.contains(companyId)) {
          suppliers.add({
            'id': supplierId,
            'name': isArabic
                ? (data['nameAr'] ?? data['nameEn'] ?? supplierId)
                : (data['nameEn'] ?? data['nameAr'] ?? supplierId),
          });
        }
      }

      await _saveToCache(cacheKey, suppliers);
      return suppliers;
    } catch (e) {
      safeDebugPrint('Error loading suppliers: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // أدوات الكاش
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _saveToCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(data);
      await prefs.setString(key, jsonString);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      safeDebugPrint('Cache save error: $e');
    }
  }

  Future<dynamic> _getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (age > _cacheDuration.inMilliseconds) return null;

      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;

      return json.decode(jsonString);
    } catch (e) {
      safeDebugPrint('Cache load error: $e');
      return null;
    }
  }

  /// مسح كافة الكاش
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      await prefs.remove(_cacheTimeKey);
      safeDebugPrint('Cache cleared successfully');
    } catch (e) {
      safeDebugPrint('Error clearing cache: $e');
    }
  }
}