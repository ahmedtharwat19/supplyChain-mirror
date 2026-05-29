// services/user_subscription_service.dart - تصحيح الأخطاء
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';

// ❌ تم إزالة هذه الاستيرادات لأنها غير مستخدمة:
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين - تم إزالة _keyLicenseCache غير المستخدم
  static const String _keyFingerprint = 'fingerprint';
  // static const String _keyLicenseCache = 'license_cache'; // ❌ تم حذفه

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

      // ✅ البحث عن الترخيص غير المنتهي فقط
      DocumentSnapshot? activeLicenseDoc;
      DateTime? latestExpiry;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final expiryTimestamp = data['expiryDate'] as Timestamp?;

        if (expiryTimestamp == null) continue;

        final expiryDate = expiryTimestamp.toDate();
        final now = DateTime.now();

        if (expiryDate.isAfter(now)) {
          if (latestExpiry == null || expiryDate.isAfter(latestExpiry)) {
            latestExpiry = expiryDate;
            activeLicenseDoc = doc;
          }
        }
      }

      if (activeLicenseDoc == null) {
        safeDebugPrint('⚠️ No active license found for user: ${user.uid}');
        return SubscriptionResult(
          isValid: false,
          isExpired: true,
          isExpiringSoon: false,
          timeLeftFormatted: null,
        );
      }

      final expiryDate = latestExpiry!;
      final now = DateTime.now();
      final isExpired = now.isAfter(expiryDate);

      final fingerprintResult = await _checkDeviceFingerprint(activeLicenseDoc.id);

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

      safeDebugPrint('✅ Active license found: ${activeLicenseDoc.id}, expires: $expiryDate');

      return SubscriptionResult(
        isValid: fingerprintResult['isValid'] && !isExpired,
        isExpired: isExpired,
        isExpiringSoon: isExpiringSoon,
        expiryDate: expiryDate,
        timeLeftFormatted: formattedTimeLeft,
        needsDeviceRegistration: fingerprintResult['needsRegistration'],
        licenseId: activeLicenseDoc.id,
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

  /// ✅ التحقق من بصمة الجهاز (بدون Hive)
  Future<Map<String, dynamic>> _checkDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();
      
      // ✅ قراءة من SecureStorage بدلاً من Hive
      final localFingerprint = await _secureStorage.read(key: _keyFingerprint);

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

      final isDeviceRegistered = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);

      if (isDeviceRegistered) {
        await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);
        return {'isValid': true, 'needsRegistration': false};
      }

      if (devices.length < maxDevices) {
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

        await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);

        return {'isValid': true, 'needsRegistration': false};
      }

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

  Future<bool> registerDeviceFingerprint(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      if (devices.length >= maxDevices) {
        await _fixDeviceLimit(licenseId, maxDevices);
        final updatedDoc = await _fs.collection('licenses').doc(licenseId).get();
        final updatedData = updatedDoc.data()!;
        final updatedDevices = updatedData['devices'] as List<dynamic>? ?? [];

        if (updatedDevices.length >= maxDevices) {
          return false;
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

      await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);

      return true;
    } catch (e) {
      debugPrint('❌ Error registering device fingerprint: $e');
      return false;
    }
  }

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
  Future<bool> unregisterDevice(String licenseId, String fingerprint) async {
    try {
      if (!await _verifyLicenseOwnership(licenseId)) {
        safeDebugPrint('User does not own this license');
        return false;
      }

      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      List<dynamic> devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      devices.removeWhere((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == fingerprint);

      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      if (devices.length < maxDevices) {
        devices.add({
          'fingerprint': currentFingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceName': deviceInfo['deviceName'],
          'platform': deviceInfo['platform'],
          'model': deviceInfo['model'],
          'os': deviceInfo['os'],
          'browser': deviceInfo['browser'],
          'lastActive': DateTime.now().toIso8601String(),
        });

        await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);
      }

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': devices,
        'deviceIds': FieldValue.arrayRemove([fingerprint]),
      });

      final localFingerprint = await _secureStorage.read(key: _keyFingerprint);
      if (localFingerprint == fingerprint) {
        await _secureStorage.delete(key: _keyFingerprint);
      }

      return true;
    } catch (e) {
      safeDebugPrint('❌ Error unregistering device: $e');
      return false;
    }
  }

  /// الحصول على الأجهزة المسجلة
  Future<List<Map<String, dynamic>>> getRegisteredDevices(String licenseId) async {
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
  Future<void> extendSubscription(String licenseId, DateTime newExpiryDate) async {
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

    await _secureStorage.delete(key: _keyFingerprint);
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

  // ==================== دوال تغيير الجهاز لمرة واحدة ====================
// services/user_subscription_service.dart

/* Future<bool> canChangeDevice(String licenseId) async {
  try {
    safeDebugPrint('🔍 Checking if device can be changed for license: $licenseId');
    
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      safeDebugPrint('❌ License not found: $licenseId');
      return false;
    }

    final data = licenseDoc.data()!;
    final deviceChanged = data['deviceChanged'] ?? false;
    
    safeDebugPrint('📱 deviceChanged flag: $deviceChanged');
    
    // إذا تم تغيير الجهاز مسبقاً، لا يمكن التغيير مرة أخرى
    if (deviceChanged) {
      safeDebugPrint('❌ Device already changed once, cannot change again');
      return false;
    }
    
    final devices = data['devices'] as List<dynamic>? ?? [];
    final deviceIds = List<String>.from(data['deviceIds'] ?? []);
    final maxDevices = data['maxDevices'] as int? ?? 1;
    
    safeDebugPrint('📱 Devices count: ${devices.length}');
    safeDebugPrint('📱 DeviceIds count: ${deviceIds.length}');
    safeDebugPrint('📱 Max devices: $maxDevices');
    
    // يمكن التغيير فقط إذا كان هناك جهاز واحد مسجل (الحد الأقصى 1)
    final canChange = !deviceChanged && devices.length == 1 && maxDevices == 1;
    
    safeDebugPrint('📱 Can change device: $canChange');
    return canChange;
  } catch (e) {
    safeDebugPrint('❌ Error checking device change permission: $e');
    return false;
  }
}
 */


// services/user_subscription_service.dart

Future<bool> canChangeDevice(String licenseId) async {
  try {
    safeDebugPrint('🔍 [canChangeDevice] Checking for license: $licenseId');
    
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      safeDebugPrint('❌ License not found');
      return false;
    }

    final data = licenseDoc.data()!;
    final deviceChanged = data['deviceChanged'] ?? false;
    final maxDevices = data['maxDevices'] as int? ?? 1;
    final devices = data['devices'] as List<dynamic>? ?? [];
    final deviceIds = data['deviceIds'] as List<dynamic>? ?? [];
    
    safeDebugPrint('📊 deviceChanged: $deviceChanged');
    safeDebugPrint('📊 maxDevices: $maxDevices');
    safeDebugPrint('📊 devices count: ${devices.length}');
    safeDebugPrint('📊 deviceIds count: ${deviceIds.length}');
    
    // ✅ يمكن تغيير الجهاز إذا:
    // 1. لم يتم تغيير الجهاز مسبقاً
    // 2. يوجد أجهزة مسجلة (للتبديل بينها)
    final canChange = !deviceChanged && (devices.isNotEmpty || deviceIds.isNotEmpty);
    
    safeDebugPrint('✅ canChange: $canChange');
    return canChange;
  } catch (e) {
    safeDebugPrint('❌ Error: $e');
    return false;
  }
}


Future<bool> changeDevice(String licenseId) async {
  try {
    safeDebugPrint('🔄 [changeDevice] Starting for license: $licenseId');
    
    // 1. جلب الترخيص
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      safeDebugPrint('❌ License not found');
      return false;
    }
    
    final data = licenseDoc.data()!;
    final maxDevices = data['maxDevices'] as int? ?? 1;
    final deviceChanged = data['deviceChanged'] ?? false;
    
    safeDebugPrint('📊 Max devices: $maxDevices');
    safeDebugPrint('📊 Device already changed: $deviceChanged');
    
    // 2. التحقق: هل يمكن تغيير الجهاز؟
    if (deviceChanged) {
      safeDebugPrint('❌ Device already changed once, cannot change again');
      return false;
    }
    
    // 3. الحصول على بصمة الجهاز الحالي
    final currentFingerprint = await DeviceFingerprint.generate();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    
    // 4. جلب الأجهزة الحالية
    List<dynamic> devices = List.from(data['devices'] ?? []);
    List<String> deviceIds = List<String>.from(data['deviceIds'] ?? []);
    
    safeDebugPrint('📱 Current devices count: ${devices.length}');
    safeDebugPrint('📱 Current deviceIds: $deviceIds');
    
    // 5. ✅ المنطق الصحيح لاستبدال الجهاز:
    //    إذا كان الجهاز الحالي غير مسجل، استبدل أحد الأجهزة المسجلة
    //    نستبدل الجهاز الأقدم أو الأقل نشاطاً
    
    if (!deviceIds.contains(currentFingerprint)) {
      // الجهاز الحالي غير مسجل → نحتاج إلى استبدال جهاز موجود
      
      if (devices.isEmpty && deviceIds.isEmpty) {
        // لا توجد أجهزة مسجلة → فقط أضف الجهاز الحالي
        devices.add({
          'fingerprint': currentFingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceName': deviceInfo['deviceName'] ?? 'Unknown',
          'platform': deviceInfo['platform'] ?? 'Unknown',
          'model': deviceInfo['model'] ?? 'Unknown',
          'os': deviceInfo['os'] ?? 'Unknown',
          'browser': deviceInfo['browser'] ?? 'Unknown',
          'lastActive': DateTime.now().toIso8601String(),
        });
        deviceIds.add(currentFingerprint);
      } else {
        // يوجد أجهزة مسجلة → استبدل الجهاز الأقدم
        // نبحث عن الجهاز الأقدم (أصغر registeredAt)
        devices.sort((a, b) {
          final aTime = a['registeredAt'] ?? a['lastActive'] ?? '';
          final bTime = b['registeredAt'] ?? b['lastActive'] ?? '';
          return aTime.compareTo(bTime);
        });
        
        // إزالة الأقدم
        final removedDevice = devices.removeAt(0);
        final removedFingerprint = removedDevice['fingerprint'] as String;
        deviceIds.remove(removedFingerprint);
        
        // إضافة الجهاز الجديد
        devices.add({
          'fingerprint': currentFingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceName': deviceInfo['deviceName'] ?? 'Unknown',
          'platform': deviceInfo['platform'] ?? 'Unknown',
          'model': deviceInfo['model'] ?? 'Unknown',
          'os': deviceInfo['os'] ?? 'Unknown',
          'browser': deviceInfo['browser'] ?? 'Unknown',
          'lastActive': DateTime.now().toIso8601String(),
          'replacedDeviceFingerprint': removedFingerprint,
          'replacedAt': DateTime.now().toIso8601String(),
        });
        deviceIds.add(currentFingerprint);
        
        safeDebugPrint('📱 Replaced device: $removedFingerprint with $currentFingerprint');
      }
    } else {
      // الجهاز الحالي مسجل بالفعل → لا حاجة للتغيير
      safeDebugPrint('✅ Current device is already registered, no change needed');
      return true;
    }
    
    // 6. تحديث Firestore
    await _fs.collection('licenses').doc(licenseId).update({
      'devices': devices,
      'deviceIds': deviceIds,
      'deviceChanged': true,  // منع تغيير الجهاز مرة أخرى
      'lastDeviceChangeAt': FieldValue.serverTimestamp(),
    });
    
    // 7. تحديث التخزين المحلي
    await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);
    
    // 8. حفظ معلومات الترخيص
    final expiryDate = data['expiryDate'] as Timestamp?;
    if (expiryDate != null) {
      await _secureStorage.write(key: 'license_expiry', value: expiryDate.toDate().toIso8601String());
    }
    await _secureStorage.write(key: 'license_key', value: licenseId);
    
    safeDebugPrint('✅ Device changed successfully! New device count: ${devices.length}');
    return true;
  } catch (e, stackTrace) {
    safeDebugPrint('❌ Error changing device: $e');
    safeDebugPrint('📚 Stack trace: $stackTrace');
    return false;
  }
}


/*   Future<bool> canChangeDevice(String licenseId) async {
    try {
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final deviceChanged = data['deviceChanged'] ?? false;
      final devices = data['devices'] as List<dynamic>? ?? [];
      final maxDevices = data['maxDevices'] as int? ?? 1;

      return !deviceChanged && devices.length == maxDevices && devices.isNotEmpty;
    } catch (e) {
      safeDebugPrint('Error checking device change permission: $e');
      return false;
    }
  }
 */
// services/user_subscription_service.dart - استبدل دالة changeDevice بهذه النسخة

/* Future<bool> changeDevice(String licenseId) async {
  try {
    safeDebugPrint('🔄 Starting device change for license: $licenseId');
    
    // 1. التحقق من صلاحية التغيير
    if (!await canChangeDevice(licenseId)) {
      safeDebugPrint('❌ Cannot change device - already changed once or invalid');
      return false;
    }
    
    // 2. الحصول على بصمة الجهاز الحالي
    final currentFingerprint = await DeviceFingerprint.generate();
    safeDebugPrint('📱 Current device fingerprint: $currentFingerprint');
    
    // 3. الحصول على معلومات الجهاز
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    safeDebugPrint('📱 Device info: $deviceInfo');
    
    // 4. جلب الترخيص الحالي
    final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
    if (!licenseDoc.exists) {
      safeDebugPrint('❌ License document not found: $licenseId');
      return false;
    }
    
    final data = licenseDoc.data()!;
    final oldDevices = data['devices'] as List<dynamic>? ?? [];
    final oldDeviceIds = List<String>.from(data['deviceIds'] ?? []);
    final maxDevices = data['maxDevices'] as int? ?? 1;
    
    safeDebugPrint('📱 Old devices count: ${oldDevices.length}');
    safeDebugPrint('📱 Old deviceIds: $oldDeviceIds');
    safeDebugPrint('📱 Max devices: $maxDevices');
    
    // 5. حفظ الجهاز القديم للمرجعية
    final originalFingerprint = oldDevices.isNotEmpty 
        ? (oldDevices[0] as Map<String, dynamic>)['fingerprint'] as String? 
        : (oldDeviceIds.isNotEmpty ? oldDeviceIds.first : null);
    
    safeDebugPrint('📱 Original device fingerprint: $originalFingerprint');
    
    // 6. إنشاء جهاز جديد
    final newDevice = {
      'fingerprint': currentFingerprint,
      'registeredAt': DateTime.now().toIso8601String(),
      'deviceName': deviceInfo['deviceName'] ?? 'Unknown',
      'platform': deviceInfo['platform'] ?? 'Unknown',
      'model': deviceInfo['model'] ?? 'Unknown',
      'os': deviceInfo['os'] ?? 'Unknown',
      'browser': deviceInfo['browser'] ?? 'Unknown',
      'lastActive': DateTime.now().toIso8601String(),
      'isCurrentDevice': true,
      'isReplacement': true,
      'replacedDeviceFingerprint': originalFingerprint,
      'replacedAt': DateTime.now().toIso8601String(),
    };
    
    // 7. تحديث الترخيص
    await _fs.collection('licenses').doc(licenseId).update({
      'devices': [newDevice],  // استبدال جميع الأجهزة بالجهاز الجديد فقط
      'deviceIds': [currentFingerprint],  // استبدال deviceIds بالجهاز الجديد
      'deviceChanged': true,
      'originalDeviceFingerprint': originalFingerprint,
      'deviceChangeDate': FieldValue.serverTimestamp(),
      'previousDevices': oldDevices,  // حفظ الأجهزة السابقة للتوثيق
      'previousDeviceIds': oldDeviceIds,
      'canChangeDeviceAgain': false,
      'lastDeviceChangeAt': FieldValue.serverTimestamp(),
    });
    
    // 8. حفظ البصمة في التخزين المحلي
    await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);
    
    // 9. حفظ معلومات الترخيص في التخزين المحلي
    final expiryDate = data['expiryDate'] as Timestamp?;
    if (expiryDate != null) {
      await _secureStorage.write(key: 'license_expiry', value: expiryDate.toDate().toIso8601String());
    }
    await _secureStorage.write(key: 'license_key', value: licenseId);
    
    safeDebugPrint('✅ Device changed successfully for license: $licenseId');
    safeDebugPrint('📱 New device fingerprint: $currentFingerprint');
    
    return true;
  } catch (e, stackTrace) {
    safeDebugPrint('❌ Error changing device: $e');
    safeDebugPrint('📚 Stack trace: $stackTrace');
    return false;
  }
}
 */
/*   Future<bool> changeDevice(String licenseId) async {
    try {
      if (!await canChangeDevice(licenseId)) {
        safeDebugPrint('❌ Cannot change device - already changed once');
        return false;
      }

      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();

      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final oldDevices = data['devices'] as List<dynamic>? ?? [];
      final originalFingerprint = oldDevices.isNotEmpty ? oldDevices[0]['fingerprint'] : null;

      final newDevice = {
        'fingerprint': currentFingerprint,
        'registeredAt': DateTime.now().toIso8601String(),
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': DateTime.now().toIso8601String(),
        'isCurrentDevice': true,
        'isReplacement': true,
        'replacedDeviceFingerprint': originalFingerprint,
      };

      await _fs.collection('licenses').doc(licenseId).update({
        'devices': [newDevice],
        'deviceIds': [currentFingerprint],
        'deviceChanged': true,
        'originalDeviceFingerprint': originalFingerprint,
        'deviceChangeDate': FieldValue.serverTimestamp(),
        'canChangeDeviceAgain': false,
      });

      await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);

      safeDebugPrint('✅ Device changed successfully for license: $licenseId');
      return true;
    } catch (e) {
      safeDebugPrint('❌ Error changing device: $e');
      return false;
    }
  }
 */
// services/user_subscription_service.dart - أضف هذه الدالة بعد دالة canChangeDevice

  /// ✅ التحقق مما إذا كان الجهاز الحالي مسجلاً في الترخيص
  Future<bool> isCurrentDeviceRegistered(String licenseId) async {
    try {
      safeDebugPrint('🔍 Checking if current device is registered for license: $licenseId');
      
      final currentFingerprint = await DeviceFingerprint.generate();
      safeDebugPrint('📱 Current fingerprint: $currentFingerprint');
      
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) {
        safeDebugPrint('❌ License not found: $licenseId');
        return false;
      }
      
      final data = licenseDoc.data()!;
      
      // التحقق من حقل deviceIds (المصفوفة الجديدة)
      final deviceIds = List<String>.from(data['deviceIds'] ?? []);
      if (deviceIds.contains(currentFingerprint)) {
        safeDebugPrint('✅ Device found in deviceIds array');
        return true;
      }
      
      // التحقق من حقل devices القديم (للتوافق مع الإصدارات السابقة)
      final devices = data['devices'] as List<dynamic>? ?? [];
      for (final device in devices) {
        if (device is Map<String, dynamic>) {
          final fingerprint = device['fingerprint'] as String?;
          if (fingerprint == currentFingerprint) {
            safeDebugPrint('✅ Device found in devices array');
            // تحديث deviceIds إذا كان موجوداً في devices فقط
            if (!deviceIds.contains(currentFingerprint)) {
              await _fs.collection('licenses').doc(licenseId).update({
                'deviceIds': FieldValue.arrayUnion([currentFingerprint]),
              });
            }
            return true;
          }
        }
      }
      
      safeDebugPrint('❌ Device not registered');
      return false;
    } catch (e) {
      safeDebugPrint('❌ Error checking isCurrentDeviceRegistered: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getDeviceChangeStatus(String licenseId) async {
    try {
      final licenseDoc = await _fs.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) {
        return {'deviceChanged': false, 'canChange': false};
      }

      final data = licenseDoc.data()!;
      final deviceChanged = data['deviceChanged'] ?? false;
      final deviceChangeDate = data['deviceChangeDate'];
      final originalDeviceFingerprint = data['originalDeviceFingerprint'];

      return {
        'deviceChanged': deviceChanged,
        'deviceChangeDate': deviceChangeDate,
        'originalDeviceFingerprint': originalDeviceFingerprint,
        'canChange': !deviceChanged,
      };
    } catch (e) {
      safeDebugPrint('Error getting device change status: $e');
      return {'deviceChanged': false, 'canChange': false};
    }
  }
}