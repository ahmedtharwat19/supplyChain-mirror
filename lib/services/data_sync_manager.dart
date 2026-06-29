/* // services/data_sync_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class DataSyncManager {
  static final DataSyncManager _instance = DataSyncManager._internal();
  factory DataSyncManager() => _instance;
  DataSyncManager._internal();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  static const Duration _minSyncInterval = Duration(minutes: 5);

  /// مزامنة البيانات الذكية - فقط إذا مر وقت كافٍ أو تغيرت البيانات
  Future<bool> smartSync({bool force = false}) async {
    if (_isSyncing) {
      safeDebugPrint('⏳ Sync already in progress, skipping...');
      return false;
    }

    if (!force && _lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < _minSyncInterval) {
        safeDebugPrint('⏳ Skipping sync - last sync was ${timeSinceLastSync.inMinutes} minutes ago');
        return false;
      }
    }

    _isSyncing = true;
    try {
      // التحقق من وجود تغييرات في Firestore
      final hasChanges = await _checkForChanges();
      
      if (hasChanges || force) {
        safeDebugPrint('🔄 Changes detected, performing sync...');
        await _performSync();
        _lastSyncTime = DateTime.now();
        await HiveService.saveLastSyncTimestamp();
        return true;
      } else {
        safeDebugPrint('✅ No changes detected, skipping sync');
        return false;
      }
    } catch (e) {
      safeDebugPrint('❌ Smart sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// التحقق من وجود تغييرات في Firestore
  Future<bool> _checkForChanges() async {
    try {
      final lastSync = await HiveService.getLastSyncTimestamp();
      if (lastSync == 0) return true; // أول مزامنة

      // التحقق من آخر تحديث في المجموعات المهمة
      final collectionsToCheck = ['factories', 'suppliers', 'items', 'purchase_orders'];
      
      for (final collection in collectionsToCheck) {
        final query = await FirebaseFirestore.instance
            .collection(collection)
            .where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSync))
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          safeDebugPrint('📝 Changes detected in $collection');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      safeDebugPrint('Error checking for changes: $e');
      return true; // في حالة الخطأ، نقوم بالمزامنة
    }
  }

  /// تنفيذ المزامنة الفعلية
  Future<void> _performSync() async {
    //  تنفيذ المزامنة الفعلية للبيانات
    safeDebugPrint('🔄 Performing full data sync...');
  }
} */

// services/data_sync_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class DataSyncManager {
  static final DataSyncManager _instance = DataSyncManager._internal();
  factory DataSyncManager() => _instance;
  DataSyncManager._internal();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  static const Duration _minSyncInterval = Duration(minutes: 5);
  
  // ✅ مفاتيح التخزين
  static const String _keyLastSync = 'data_sync_last_sync';

  /// مزامنة البيانات الذكية - فقط إذا مر وقت كافٍ أو تغيرت البيانات
  Future<bool> smartSync({bool force = false}) async {
    if (_isSyncing) {
      safeDebugPrint('⏳ Sync already in progress, skipping...');
      return false;
    }

    await _loadLastSyncTime();

    if (!force && _lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < _minSyncInterval) {
        safeDebugPrint('⏳ Skipping sync - last sync was ${timeSinceLastSync.inMinutes} minutes ago');
        return false;
      }
    }

    _isSyncing = true;
    try {
      // التحقق من وجود تغييرات في Firestore
      final hasChanges = await _checkForChanges();
      
      if (hasChanges || force) {
        safeDebugPrint('🔄 Changes detected, performing sync...');
        await _performSync();
        _lastSyncTime = DateTime.now();
        await _saveLastSyncTime();
        return true;
      } else {
        safeDebugPrint('✅ No changes detected, skipping sync');
        return false;
      }
    } catch (e) {
      safeDebugPrint('❌ Smart sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_keyLastSync);
      if (lastSyncMillis != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
      }
    } catch (e) {
      safeDebugPrint('Error loading last sync time: $e');
    }
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastSync, _lastSyncTime!.millisecondsSinceEpoch);
    } catch (e) {
      safeDebugPrint('Error saving last sync time: $e');
    }
  }

  /// التحقق من وجود تغييرات في Firestore
  Future<bool> _checkForChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_keyLastSync);
      
      if (lastSyncMillis == null) return true; // أول مزامنة

      // التحقق من آخر تحديث في المجموعات المهمة
      final collectionsToCheck = ['factories', 'suppliers', 'items', 'purchase_orders'];
      
      for (final collection in collectionsToCheck) {
        final query = await FirebaseFirestore.instance
            .collection(collection)
            .where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSyncMillis))
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          safeDebugPrint('📝 Changes detected in $collection');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      safeDebugPrint('Error checking for changes: $e');
      return true; // في حالة الخطأ، نقوم بالمزامنة
    }
  }

  /// تنفيذ المزامنة الفعلية
  Future<void> _performSync() async {
    safeDebugPrint('🔄 Performing full data sync...');
    // هنا يمكنك استدعاء دوال المزامنة الفعلية
  }
}