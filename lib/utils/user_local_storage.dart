/* import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  // ══════════════ Keys ══════════════
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  static const String _keyCompanyIds = 'companyIds';
  static const String _keyCurrentCompanyId = 'currentCompanyId';

  static const String _keyFactoryIds = 'factoryIds';
  static const String _keyCurrentFactoryId = 'currentFactoryId';

  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  static const String _keyTotalFactories = 'totalFactories';
  static const String _keyTotalItems = 'totalItems';
  static const String _keyTotalStockMovements = 'totalStockMovements';
  static const String _keyTotalManufacturingOrders = 'totalManufacturingOrders';
  static const String _keyTotalFinishedProducts = 'totalFinishedProducts';

  // ══════════════ Helper to get SharedPreferences ══════════════
  static Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      safeDebugPrint('❌ SharedPreferences error: $e');
      return null;
    }
  }

  // ══════════════ User Info ══════════════
  static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    final nameToSave = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : email.split('@').first;

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDisplayName, nameToSave);
  }

  static Future<Map<String, String>?> getUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;

    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final displayName = prefs.getString(_keyDisplayName);
    if (userId == null) return null;

    return {
      'userId': userId,
      'email': email ?? '',
      'displayName': displayName ?? '',
    };
  }

  static Future<bool> hasUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return false;
    return prefs.containsKey(_keyUserId);
  }

  static Future<void> clearUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
  }

  // ══════════════ Company & Factory Lists ══════════════
  static Future<void> saveCompanyIds(List<String> ids) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setStringList(_keyCompanyIds, ids);
  }

  static Future<List<String>> getCompanyIds() async {
    final prefs = await _getPrefs();
    if (prefs == null) return [];
    return prefs.getStringList(_keyCompanyIds) ?? [];
  }

  static Future<void> saveCurrentCompanyId(String companyId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentCompanyId, companyId);
  }

  static Future<String?> getCurrentCompanyId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentCompanyId);
  }

  static Future<void> clearCompanyInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyCurrentCompanyId);
  }

  static Future<void> saveFactoryIds(List<String> ids) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setStringList(_keyFactoryIds, ids);
  }

  static Future<List<String>> getFactoryIds() async {
    final prefs = await _getPrefs();
    if (prefs == null) return [];
    return prefs.getStringList(_keyFactoryIds) ?? [];
  }

  static Future<void> saveCurrentFactoryId(String factoryId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentFactoryId, factoryId);
  }

  static Future<String?> getCurrentFactoryId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentFactoryId);
  }

  static Future<void> clearFactoryInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keyCurrentFactoryId);
  }

  // ══════════════ Dashboard Data ══════════════
  static Future<void> saveDashboardData({
    required int totalCompanies,
    required int totalSuppliers,
    required int totalOrders,
    required double totalAmount,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalCompanies, totalCompanies);
    await prefs.setInt(_keyTotalSuppliers, totalSuppliers);
    await prefs.setInt(_keyTotalOrders, totalOrders);
    await prefs.setDouble(_keyTotalAmount, totalAmount);
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  static Future<void> clearDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  // ══════════════ Extended Stats ══════════════
  static Future<void> saveExtendedStats({
    required int totalFactories,
    required int totalItems,
    required int totalStockMovements,
    required int totalManufacturingOrders,
    required int totalFinishedProducts,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalFactories, totalFactories);
    await prefs.setInt(_keyTotalItems, totalItems);
    await prefs.setInt(_keyTotalStockMovements, totalStockMovements);
    await prefs.setInt(_keyTotalManufacturingOrders, totalManufacturingOrders);
    await prefs.setInt(_keyTotalFinishedProducts, totalFinishedProducts);
  }

  static Future<Map<String, int>> getExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders': prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }

  static Future<void> clearExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalFactories);
    await prefs.remove(_keyTotalItems);
    await prefs.remove(_keyTotalStockMovements);
    await prefs.remove(_keyTotalManufacturingOrders);
    await prefs.remove(_keyTotalFinishedProducts);
  }

  // ══════════════ Clear Everything ══════════════
  static Future<void> clearAll() async {
    await clearUser();
    await clearCompanyInfo();
    await clearFactoryInfo();
    await clearDashboardData();
    await clearExtendedStats();
  }
}





/* import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  // ══════════════ Keys ══════════════
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  static const String _keyCompanyIds = 'companyIds';
  static const String _keyCurrentCompanyId = 'currentCompanyId';

  static const String _keyFactoryIds = 'factoryIds';
  static const String _keyCurrentFactoryId = 'currentFactoryId';

  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  static const String _keyTotalFactories = 'totalFactories';
  static const String _keyTotalItems = 'totalItems';
  static const String _keyTotalStockMovements = 'totalStockMovements';
  static const String _keyTotalManufacturingOrders = 'totalManufacturingOrders';
  static const String _keyTotalFinishedProducts = 'totalFinishedProducts';

  // ══════════════ User Info ══════════════
  static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nameToSave = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : email.split('@').first;

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDisplayName, nameToSave);
  }

  static Future<Map<String, String>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final displayName = prefs.getString(_keyDisplayName);
    if (userId == null) return null;

    return {
      'userId': userId,
      'email': email ?? '',
      'displayName': displayName ?? '',
    };
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
  }

  // ══════════════ Company & Factory Lists ══════════════

  static Future<void> saveCompanyIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCompanyIds, ids);
  }

  static Future<List<String>> getCompanyIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCompanyIds) ?? [];
  }

  static Future<void> saveCurrentCompanyId(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentCompanyId, companyId);
  }

  static Future<String?> getCurrentCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentCompanyId);
  }

  static Future<void> clearCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyCurrentCompanyId);
  }

  static Future<void> saveFactoryIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFactoryIds, ids);
  }

  static Future<List<String>> getFactoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFactoryIds) ?? [];
  }

  static Future<void> saveCurrentFactoryId(String factoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentFactoryId, factoryId);
  }

  static Future<String?> getCurrentFactoryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentFactoryId);
  }

  static Future<void> clearFactoryInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keyCurrentFactoryId);
  }

  // ══════════════ Dashboard Data ══════════════

  static Future<void> saveDashboardData({
    required int totalCompanies,
    required int totalSuppliers,
    required int totalOrders,
    required double totalAmount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalCompanies, totalCompanies);
    await prefs.setInt(_keyTotalSuppliers, totalSuppliers);
    await prefs.setInt(_keyTotalOrders, totalOrders);
    await prefs.setDouble(_keyTotalAmount, totalAmount);
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  static Future<void> clearDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  // ══════════════ Extended Stats ══════════════

  static Future<void> saveExtendedStats({
    required int totalFactories,
    required int totalItems,
    required int totalStockMovements,
    required int totalManufacturingOrders,
    required int totalFinishedProducts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalFactories, totalFactories);
    await prefs.setInt(_keyTotalItems, totalItems);
    await prefs.setInt(_keyTotalStockMovements, totalStockMovements);
    await prefs.setInt(_keyTotalManufacturingOrders, totalManufacturingOrders);
    await prefs.setInt(_keyTotalFinishedProducts, totalFinishedProducts);
  }

  static Future<Map<String, int>> getExtendedStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders':
          prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }

  static Future<void> clearExtendedStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalFactories);
    await prefs.remove(_keyTotalItems);
    await prefs.remove(_keyTotalStockMovements);
    await prefs.remove(_keyTotalManufacturingOrders);
    await prefs.remove(_keyTotalFinishedProducts);
  }

  // ══════════════ Clear All ══════════════

  static Future<void> clearAll() async {
    await clearUser();
    await clearCompanyInfo();
    await clearFactoryInfo();
    await clearDashboardData();
    await clearExtendedStats();
  }
}
 */ */
/* 
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  // ══════════════ Keys ══════════════
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  static const String _keyCompanyIds = 'companyIds';
  static const String _keyFactoryIds = 'factoryIds';
  static const String _keySupplierIds = 'supplierIds';

  static const String _keyCurrentCompanyId = 'currentCompanyId';
  static const String _keyCurrentFactoryId = 'currentFactoryId';

  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  static const String _keyTotalFactories = 'totalFactories';
  static const String _keyTotalItems = 'totalItems';
  static const String _keyTotalStockMovements = 'totalStockMovements';
  static const String _keyTotalManufacturingOrders = 'totalManufacturingOrders';
  static const String _keyTotalFinishedProducts = 'totalFinishedProducts';

  // ══════════════ Helper to get SharedPreferences ══════════════
  static Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      safeDebugPrint('❌ SharedPreferences error: $e');
      return null;
    }
  }

  // ══════════════ User Info ══════════════
/*   static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
    List<String>? companyIds,
    List<String>? factoryIds,
    List<String>? supplierIds,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    final nameToSave = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : email.split('@').first;

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDisplayName, nameToSave);

    if (companyIds != null) {
      await prefs.setStringList(_keyCompanyIds, companyIds);
    }
    if (factoryIds != null) {
      await prefs.setStringList(_keyFactoryIds, factoryIds);
    }
    if (supplierIds != null) {
      await prefs.setStringList(_keySupplierIds, supplierIds);
    }
  }
 */
  
  static Future<void> saveUser({
  required String userId,
  required String email,
  String? displayName,
  List<String>? companyIds,
  List<String>? factoryIds,
  List<String>? supplierIds,
}) async {
  final prefs = await _getPrefs();
  if (prefs == null) return;

  final nameToSave = (displayName?.trim().isNotEmpty ?? false)
      ? displayName!
      : email.split('@').first;

  await prefs.setString(_keyUserId, userId);
  await prefs.setString(_keyEmail, email);
  await prefs.setString(_keyDisplayName, nameToSave);

  if (companyIds != null) {
    await prefs.setStringList(_keyCompanyIds, companyIds);
  }
  if (factoryIds != null) {
    await prefs.setStringList(_keyFactoryIds, factoryIds);
  }
  if (supplierIds != null) {
    await prefs.setStringList(_keySupplierIds, supplierIds);
  }
}
  
  
/*   static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;

    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final displayName = prefs.getString(_keyDisplayName);
    final companyIds = prefs.getStringList(_keyCompanyIds) ?? [];
    final factoryIds = prefs.getStringList(_keyFactoryIds) ?? [];
    final supplierIds = prefs.getStringList(_keySupplierIds) ?? [];

    if (userId == null) return null;

    return {
      'userId': userId,
      'email': email ?? '',
      'displayName': displayName ?? '',
      'companyIds': companyIds,
      'factoryIds': factoryIds,
      'supplierIds': supplierIds,
    };
  }
 */
  
  static Future<Map<String, dynamic>?> getUser() async {
  final prefs = await _getPrefs();
  if (prefs == null) return null;

  final userId = prefs.getString(_keyUserId);
  final email = prefs.getString(_keyEmail);
  final displayName = prefs.getString(_keyDisplayName);
  final companyIds = prefs.getStringList(_keyCompanyIds) ?? [];
  final factoryIds = prefs.getStringList(_keyFactoryIds) ?? [];
  final supplierIds = prefs.getStringList(_keySupplierIds) ?? [];

  if (userId == null) return null;

  return {
    'userId': userId,
    'email': email ?? '',
    'displayName': displayName ?? '',
    'companyIds': companyIds,
    'factoryIds': factoryIds,
    'supplierIds': supplierIds,
  };
}
  
  static Future<bool> hasUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return false;
    return prefs.containsKey(_keyUserId);
  }

  static Future<void> clearUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keySupplierIds);
  }

  // ══════════════ Company & Factory Info ══════════════
  static Future<void> saveCurrentCompanyId(String companyId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentCompanyId, companyId);
  }

  static Future<String?> getCurrentCompanyId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentCompanyId);
  }

  static Future<void> saveCurrentFactoryId(String factoryId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentFactoryId, factoryId);
  }

  static Future<String?> getCurrentFactoryId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentFactoryId);
  }

  static Future<void> clearCompanyInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyCurrentCompanyId);
  }

  static Future<void> clearFactoryInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keyCurrentFactoryId);
  }

  // ══════════════ Dashboard Data ══════════════
/*   static Future<void> saveDashboardData(Map<String, dynamic> stats) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    if (stats['totalCompanies'] != null) {
      await prefs.setInt(_keyTotalCompanies, stats['totalCompanies']);
    }
    if (stats['totalSuppliers'] != null) {
      await prefs.setInt(_keyTotalSuppliers, stats['totalSuppliers']);
    }
    if (stats['totalOrders'] != null) {
      await prefs.setInt(_keyTotalOrders, stats['totalOrders']);
    }
    if (stats['totalAmount'] != null) {
      await prefs.setDouble(_keyTotalAmount, stats['totalAmount']);
    }
    if (stats['totalFactories'] != null) {
      await prefs.setInt(_keyTotalFactories, stats['totalFactories']);
    }
    if (stats['totalItems'] != null) {
      await prefs.setInt(_keyTotalItems, stats['totalItems']);
    }
    if (stats['totalStockMovements'] != null) {
      await prefs.setInt(_keyTotalStockMovements, stats['totalStockMovements']);
    }
    if (stats['totalManufacturingOrders'] != null) {
      await prefs.setInt(
          _keyTotalManufacturingOrders, stats['totalManufacturingOrders']);
    }
    if (stats['totalFinishedProducts'] != null) {
      await prefs.setInt(
          _keyTotalFinishedProducts, stats['totalFinishedProducts']);
    }
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders':
          prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }
 */

  static Future<void> saveDashboardData({
    required int totalCompanies,
    required int totalSuppliers,
    required int totalOrders,
    required double totalAmount,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalCompanies, totalCompanies);
    await prefs.setInt(_keyTotalSuppliers, totalSuppliers);
    await prefs.setInt(_keyTotalOrders, totalOrders);
    await prefs.setDouble(_keyTotalAmount, totalAmount);
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  static Future<void> clearDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  // ══════════════ Extended Stats ══════════════
  static Future<void> saveExtendedStats({
    required int totalFactories,
    required int totalItems,
    required int totalStockMovements,
    required int totalManufacturingOrders,
    required int totalFinishedProducts,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalFactories, totalFactories);
    await prefs.setInt(_keyTotalItems, totalItems);
    await prefs.setInt(_keyTotalStockMovements, totalStockMovements);
    await prefs.setInt(_keyTotalManufacturingOrders, totalManufacturingOrders);
    await prefs.setInt(_keyTotalFinishedProducts, totalFinishedProducts);
  }

  static Future<Map<String, int>> getExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders':
          prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }

  static Future<void> clearExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalFactories);
    await prefs.remove(_keyTotalItems);
    await prefs.remove(_keyTotalStockMovements);
    await prefs.remove(_keyTotalManufacturingOrders);
    await prefs.remove(_keyTotalFinishedProducts);
  }

  // ══════════════ Clear Everything ══════════════
  static Future<void> clearAll() async {
    await clearUser();
    await clearCompanyInfo();
    await clearFactoryInfo();
    await clearDashboardData();
    await clearExtendedStats();
  }
}

 */

import 'dart:convert';
//import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/debug_helper.dart';


class UserLocalStorage {
  // ══════════════ Keys ══════════════
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';
  static const String _keySubscriptionDuration = 'subscriptionDurationInDays';
  static const String _keyCreatedAt = 'createdAt'; // لتخزين تاريخ الاشتراك
  static const String _keyIsActive = 'isActive';

  static const String _keyCompanyIds = 'companyIds';
  static const String _keyFactoryIds = 'factoryIds';
  static const String _keySupplierIds = 'supplierIds';

  static const String _keyCurrentCompanyId = 'currentCompanyId';
  static const String _keyCurrentFactoryId = 'currentFactoryId';

  // Dashboard keys
  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  // Extended stats keys
  static const String _keyTotalFactories = 'totalFactories';
  static const String _keyTotalItems = 'totalItems';
  static const String _keyTotalStockMovements = 'totalStockMovements';
  static const String _keyTotalManufacturingOrders = 'totalManufacturingOrders';
  static const String _keyTotalFinishedProducts = 'totalFinishedProducts';

  // New keys for settings
  static const String _keyTheme = 'theme'; // e.g., "light" or "dark"
  static const String _keyLanguageCode = 'languageCode'; // e.g., "en", "ar"
  static const String _keyLastLogin = 'lastLogin'; // saved as ISO8601 string

  // ══════════════ Helper to get SharedPreferences ══════════════
  static Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      safeDebugPrint('❌ SharedPreferences error: $e');
      return null;
    }
  }

  // ══════════════ User Info ══════════════

  static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
    List<String>? companyIds,
    List<String>? factoryIds,
    List<String>? supplierIds,
    int? subscriptionDurationInDays,
    DateTime? createdAt,
    DateTime? expiryDate,
    bool? isActive,
  }) async {
    final nameToSave = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : email.split('@').first;

    final userData = {
      'userId': userId,
      'email': email,
      'displayName': nameToSave,
      if (companyIds != null) 'companyIds': companyIds,
      if (factoryIds != null) 'factoryIds': factoryIds,
      if (supplierIds != null) 'supplierIds': supplierIds,
      if (subscriptionDurationInDays != null)
        'subscriptionDurationInDays': subscriptionDurationInDays,
      if (createdAt != null) 'createdAt': createdAt.toIso8601String(),
      if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
      if (isActive != null) 'isActive': isActive,
    };

    await setUser(userData);
  }

  static Future<void> setUser(Map<String, dynamic> userData) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    if (userData['userId'] != null) {
      await prefs.setString(_keyUserId, userData['userId']);
    }
    if (userData['email'] != null) {
      await prefs.setString(_keyEmail, userData['email']);
    }
    if (userData['displayName'] != null) {
      await prefs.setString(_keyDisplayName, userData['displayName']);
    }
    if (userData['companyIds'] != null && userData['companyIds'] is List) {
      final list = List<String>.from(userData['companyIds']);
      await prefs.setStringList(_keyCompanyIds, list);
    }
    if (userData['factoryIds'] != null && userData['factoryIds'] is List) {
      final list = List<String>.from(userData['factoryIds']);
      await prefs.setStringList(_keyFactoryIds, list);
    }
    if (userData['supplierIds'] != null && userData['supplierIds'] is List) {
      final list = List<String>.from(userData['supplierIds']);
      await prefs.setStringList(_keySupplierIds, list);
    }
    if (userData['subscriptionDurationInDays'] != null) {
      await prefs.setInt(
          _keySubscriptionDuration, userData['subscriptionDurationInDays']);
    }
/*     if (userData['createdAt'] != null) {
      await prefs.setString(_keyCreatedAt, userData['createdAt']);
    } */
    if (userData['createdAt'] != null) {
      final createdAt = userData['createdAt'];
      if (createdAt is DateTime) {
        await prefs.setString(_keyCreatedAt, createdAt.toIso8601String());
      } else if (createdAt is Timestamp) {
        await prefs.setString(
            _keyCreatedAt, createdAt.toDate().toIso8601String());
      } else if (createdAt is String) {
        // لو هي String فعلاً، خزّنها كما هي
        await prefs.setString(_keyCreatedAt, createdAt);
      }
    }
    
  // أضف هذا الجزء لتخزين تاريخ الانتهاء
  if (userData['expiryDate'] != null) {
    final expiryDate = userData['expiryDate'];
    if (expiryDate is DateTime) {
      await prefs.setString('expiry_date', expiryDate.toIso8601String());
    } else if (expiryDate is Timestamp) {
      await prefs.setString('expiry_date', expiryDate.toDate().toIso8601String());
    } else if (expiryDate is String) {
      await prefs.setString('expiry_date', expiryDate);
    }
  }
    if (userData['isActive'] != null) {
      await prefs.setBool(_keyIsActive, userData['isActive']);
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;

    final userId = prefs.getString(_keyUserId);
    if (userId == null) return null;

    final createdAtString = prefs.getString(_keyCreatedAt);
    DateTime? createdAt;
    if (createdAtString != null) {
      try {
        createdAt = DateTime.parse(createdAtString);
      } catch (_) {
        createdAt = null;
      }
    }
    return {
      'userId': userId,
      'email': prefs.getString(_keyEmail) ?? '',
      'displayName': prefs.getString(_keyDisplayName) ?? '',
      'companyIds': prefs.getStringList(_keyCompanyIds) ?? [],
      'factoryIds': prefs.getStringList(_keyFactoryIds) ?? [],
      'supplierIds': prefs.getStringList(_keySupplierIds) ?? [],
      'subscriptionDurationInDays':
          prefs.getInt(_keySubscriptionDuration) ?? 30, // default value
      'createdAt': createdAt, // as DateTime?
      'isActive': prefs.getBool(_keyIsActive) ?? true, // القيمة الافتراضية true
    };
  }

  static Future<bool> hasUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return false;
    return prefs.containsKey(_keyUserId);
  }

  static Future<void> clearUser() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keySupplierIds);
    await prefs.remove(_keySubscriptionDuration);
    await prefs.remove(_keyCreatedAt);
    await prefs.remove(_keyIsActive);
  }

  // ══════════════ Company & Factory Info ══════════════

  static Future<void> saveCurrentCompanyId(String companyId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentCompanyId, companyId);
  }

  static Future<String?> getCurrentCompanyId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentCompanyId);
  }

  static Future<void> saveCurrentFactoryId(String factoryId) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyCurrentFactoryId, factoryId);
  }

  static Future<String?> getCurrentFactoryId() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyCurrentFactoryId);
  }

  static Future<void> clearCompanyInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyCurrentCompanyId);
  }

  static Future<void> clearFactoryInfo() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_keyFactoryIds);
    await prefs.remove(_keyCurrentFactoryId);
  }

  // ══════════════ Dashboard Data ══════════════

  static Future<void> saveDashboardData({
    required int totalCompanies,
    required int totalSuppliers,
    required int totalOrders,
    required double totalAmount,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalCompanies, totalCompanies);
    await prefs.setInt(_keyTotalSuppliers, totalSuppliers);
    await prefs.setInt(_keyTotalOrders, totalOrders);
    await prefs.setDouble(_keyTotalAmount, totalAmount);
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  static Future<void> clearDashboardData() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  // ══════════════ Extended Stats ══════════════

  static Future<void> saveExtendedStats({
    required int totalFactories,
    required int totalItems,
    required int totalStockMovements,
    required int totalManufacturingOrders,
    required int totalFinishedProducts,
  }) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.setInt(_keyTotalFactories, totalFactories);
    await prefs.setInt(_keyTotalItems, totalItems);
    await prefs.setInt(_keyTotalStockMovements, totalStockMovements);
    await prefs.setInt(_keyTotalManufacturingOrders, totalManufacturingOrders);
    await prefs.setInt(_keyTotalFinishedProducts, totalFinishedProducts);
  }

  static Future<Map<String, int>> getExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return {};

    return {
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders':
          prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }

  static Future<void> clearExtendedStats() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTotalFactories);
    await prefs.remove(_keyTotalItems);
    await prefs.remove(_keyTotalStockMovements);
    await prefs.remove(_keyTotalManufacturingOrders);
    await prefs.remove(_keyTotalFinishedProducts);
  }

  // ══════════════ Settings (Theme, Language, Last Login) ══════════════

  static Future<void> saveTheme(String theme) async {
    // theme: "light" or "dark" (مثال)
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyTheme, theme);
  }

  static Future<String?> getTheme() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyTheme);
  }

  static Future<void> saveLanguageCode(String languageCode) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyLanguageCode, languageCode);
  }

  static Future<String?> getLanguageCode() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyLanguageCode);
  }

  static Future<void> saveLastLogin(DateTime dateTime) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyLastLogin, dateTime.toIso8601String());
  }

  static Future<DateTime?> getLastLogin() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;

    final isoString = prefs.getString(_keyLastLogin);
    if (isoString == null) return null;

    try {
      return DateTime.parse(isoString);
    } catch (e) {
      safeDebugPrint('❌ Failed to parse lastLogin: $e');
      return null;
    }
  }

  static Future<void> clearSettings() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;

    await prefs.remove(_keyTheme);
    await prefs.remove(_keyLanguageCode);
    await prefs.remove(_keyLastLogin);
  }

  // ══════════════ Clear Everything ══════════════

  static Future<void> clearAll() async {
    await clearUser();
    await clearCompanyInfo();
    await clearFactoryInfo();
    await clearDashboardData();
    await clearExtendedStats();
    await clearSettings();
  }

  static Future<String?> getUserId() async {
    final prefs = await _getPrefs();
    return prefs?.getString(_keyUserId);
  }

// في ملف user_local_storage.dart
  static Future<void> saveItemNames(Map<String, String> itemNames) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedData = json.encode(itemNames);
      await prefs.setString('cached_item_names', encodedData);
    } catch (e) {
      safeDebugPrint('Error saving item names: $e');
    }
  }

  static Future<Map<String, String>> getItemNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedData = prefs.getString('cached_item_names');
      if (encodedData != null) {
        final Map<String, dynamic> decoded = json.decode(encodedData);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      safeDebugPrint('Error getting item names: $e');
    }
    return {};
  }

  static Future<void> clearCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_item_names');
    } catch (e) {
      safeDebugPrint('Error clearing cached data: $e');
    }
  }
}
