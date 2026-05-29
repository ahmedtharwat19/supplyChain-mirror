// services/license_service.dart - بدون Hive
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => "LicenseException: $message";
}

class LicenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين
  static const String _keyFingerprint = 'fingerprint';
  static const String _keyLicenseCache = 'license_cache';
  //static const String _keyLastSync = 'last_sync';

  /// تهيئة الخدمة
  Future<void> initialize() async {
    // لا حاجة لتهيئة Hive بعد الآن
    safeDebugPrint('✅ LicenseService initialized');
  }

  /// توليد ID قياسي
  Future<String> generateStandardizedId({bool isLicense = false}) async {
    final fingerprint = await DeviceFingerprint.getFingerprint();
    final baseId = fingerprint.hashCode.toString();
    return isLicense
        ? "LIC-$baseId-${DateTime.now().millisecondsSinceEpoch}"
        : baseId;
  }

  Future<DateTime?> getLicenseExpiryDate(String licenseKey) async {
    try {
      final doc = await _firestore.collection('licenses').doc(licenseKey).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      dynamic expiryDateValue = data['expiryDate'];

      if (expiryDateValue is Timestamp) {
        return expiryDateValue.toDate();
      } else if (expiryDateValue is DateTime) {
        return expiryDateValue;
      } else if (expiryDateValue is String) {
        return DateTime.parse(expiryDateValue);
      }

      return null;
    } catch (e) {
      safeDebugPrint('Error getting expiry date: $e');
      return null;
    }
  }

  Future<bool> checkDeviceFingerprint(String licenseKey) async {
    try {
      final userSubscriptionService = UserSubscriptionService();
      final result = await userSubscriptionService.checkUserSubscription();
      return result.isValid;
    } catch (e) {
      safeDebugPrint('Error in checkDeviceFingerprint: $e');
      return false;
    }
  }

  /// إنشاء لايسنس جديد
  Future<String> createLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
    required String requestId,
  }) async {
    try {
      final secondsInMonth = 30 * 24 * 60 * 60;
      final durationSeconds = durationMonths * secondsInMonth;

      final licenseKey = await generateStandardizedId(isLicense: true);

      final now = DateTime.now().toUtc();
      final expiryDate = now.add(Duration(seconds: durationSeconds));

      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': maxDevices,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'originalRequestId': requestId,
        'devices': [],
        'durationMonths': durationMonths,
        'durationSeconds': durationSeconds,
        'createdAtTimestamp': now.millisecondsSinceEpoch,
        'deviceChanged': false,
        'deviceChangeDate': null,
        'originalDeviceFingerprint': null,
        'canChangeDeviceAgain': true,
      });

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': 'approved',
        'processedAt': DateTime.now().toIso8601String(),
        'linkedLicenseKey': licenseKey,
      });

      await _firestore.collection('users').doc(userId).update({
        'licenseKey': licenseKey,
        'license_expiry': Timestamp.fromDate(expiryDate),
        'isActive': true,
        'maxDevices': maxDevices,
        'lastUpdated': Timestamp.fromDate(now),
      });

      safeDebugPrint('✅ License created: $licenseKey');
      return licenseKey;
    } catch (e) {
      safeDebugPrint('❌ Failed to create license: $e');
      throw Exception("Failed to create license: $e");
    }
  }

  /// التحقق من صلاحية الترخيص
  Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(
          reason: "User not logged in",
          isOffline: false,
        );
      }

      // ✅ قراءة بصمة الجهاز من SecureStorage
      String currentFingerprint = await _secureStorage.read(key: _keyFingerprint) ?? 
          await DeviceFingerprint.getFingerprint();
      await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);

      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          return LicenseStatus.invalid(
            reason: "User document not found",
            isOffline: false,
          );
        }

        final userData = userDoc.data();
        if (userData == null) {
          return LicenseStatus.invalid(
            reason: "User data is null",
            isOffline: false,
          );
        }

        final userLicenseKey = userData['licenseKey'];
        if (userLicenseKey != licenseKey) {
          return LicenseStatus.invalid(
            reason: "License key does not match user's license",
            isOffline: false,
          );
        }

        // الحصول على بيانات الترخيص الكاملة
        final licenseDoc = await _firestore.collection('licenses').doc(licenseKey).get();
        Map<String, dynamic> licenseData = {};
        bool deviceChanged = false;
        bool canChangeDevice = false;
        DateTime? deviceChangeDate;
        String? originalDeviceFingerprint;

        if (licenseDoc.exists) {
          licenseData = licenseDoc.data()!;
          deviceChanged = licenseData['deviceChanged'] ?? false;
          deviceChangeDate = (licenseData['deviceChangeDate'] as Timestamp?)?.toDate();
          originalDeviceFingerprint = licenseData['originalDeviceFingerprint'];
        }

        final expiryDate = (userData['license_expiry'] as Timestamp?)?.toDate();
        if (expiryDate == null) {
          return LicenseStatus.invalid(
            reason: "Invalid expiry date format",
            isOffline: false,
          );
        }

        final maxDevices = userData['maxDevices'] ?? 1;
        final isActive = userData['isActive'] ?? false;

        final devices = List<Map<String, dynamic>>.from(
            userData['deviceIds'] ?? userData['devices'] ?? []);

        if (!isActive) {
          return LicenseStatus.invalid(
            reason: "License inactive",
            isOffline: false,
            deviceChanged: deviceChanged,
            canChangeDevice: canChangeDevice,
          );
        }

        final now = DateTime.now().toUtc();
        final expiryUtc = expiryDate.toUtc();

        if (now.isAfter(expiryUtc)) {
          return LicenseStatus.invalid(
            reason: "License expired",
            isOffline: false,
            deviceChanged: deviceChanged,
            canChangeDevice: canChangeDevice,
          );
        }

        final isRegistered = devices.any((d) => d['fingerprint'] == currentFingerprint);
        canChangeDevice = !deviceChanged && devices.length == maxDevices && devices.isNotEmpty;

        if (!isRegistered) {
          if (devices.length >= maxDevices) {
            return LicenseStatus(
              isValid: false,
              isOffline: false,
              licenseKey: licenseKey,
              expiryDate: expiryDate,
              maxDevices: maxDevices,
              usedDevices: devices.length,
              daysLeft: expiryUtc.difference(now).inDays,
              formattedRemaining: _formatDuration(expiryUtc.difference(now)),
              reason: "Device limit exceeded",
              deviceLimitExceeded: true,
              deviceChanged: deviceChanged,
              canChangeDevice: canChangeDevice,
              deviceChangeDate: deviceChangeDate,
              originalDeviceFingerprint: originalDeviceFingerprint,
            );
          }

          await _registerDeviceInUser(user.uid, currentFingerprint, devices);
        }

        final timeRemaining = expiryUtc.difference(now);
        final formattedTime = _formatDuration(timeRemaining);

        // ✅ حفظ في SharedPreferences كـ JSON
        await _cacheLicenseData(licenseKey, expiryDate, maxDevices,
            devices.length + (isRegistered ? 0 : 1));

        return LicenseStatus.valid(
          licenseKey: licenseKey,
          expiryDate: expiryDate,
          maxDevices: maxDevices,
          usedDevices: devices.length + (isRegistered ? 0 : 1),
          daysLeft: timeRemaining.inDays,
          formattedRemaining: formattedTime,
          isOffline: false,
          deviceChanged: deviceChanged,
          canChangeDevice: canChangeDevice,
          deviceChangeDate: deviceChangeDate,
          originalDeviceFingerprint: originalDeviceFingerprint,
        );
      } catch (e) {
        return await _getOfflineLicenseStatus(licenseKey);
      }
    } catch (e) {
      safeDebugPrint('❌ License check error: $e');
      return LicenseStatus.invalid(
        reason: "System error: $e",
        isOffline: true,
      );
    }
  }

  Future<void> _registerDeviceInUser(String userId, String fingerprint,
      List<Map<String, dynamic>> currentDevices) async {
    try {
      final newDevice = {
        'fingerprint': fingerprint,
        'registeredAt': DateTime.now().toIso8601String(),
        'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
      };

      final updatedDevices = [...currentDevices, newDevice];

      await _firestore.collection('users').doc(userId).update({
        'deviceIds': updatedDevices,
        'lastDeviceRegistration': DateTime.now().toIso8601String(),
      });

      safeDebugPrint('✅ Device registered in user document');
    } catch (e) {
      safeDebugPrint('❌ Error registering device in user: $e');
      rethrow;
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return tr('duration_days_hours',
          args: [days.toString(), hours.toString()]);
    } else if (hours > 0) {
      return tr('duration_hours_minutes',
          args: [hours.toString(), minutes.toString()]);
    } else if (minutes > 0) {
      return tr('duration_minutes_seconds',
          args: [minutes.toString(), seconds.toString()]);
    } else {
      return tr('duration_seconds', args: [seconds.toString()]);
    }
  }

  /// التخزين المؤقت في SharedPreferences
  Future<void> _cacheLicenseData(String licenseKey,
      DateTime expiryDate, int maxDevices, int usedDevices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'licenseKey': licenseKey,
        'expiryDate': expiryDate.toUtc().toIso8601String(),
        'maxDevices': maxDevices,
        'usedDevices': usedDevices,
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(_keyLicenseCache, json.encode(cacheData));
    } catch (e) {
      safeDebugPrint('❌ Error caching license data: $e');
    }
  }

  /// الحصول على حالة الترخيص في حالة عدم الاتصال
  Future<LicenseStatus> _getOfflineLicenseStatus(String licenseKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_keyLicenseCache);

      if (cachedJson != null) {
        final cached = json.decode(cachedJson) as Map<String, dynamic>;
        final expiryDate = DateTime.parse(cached['expiryDate']).toUtc();
        final now = DateTime.now().toUtc();

        if (expiryDate.isAfter(now)) {
          final timeRemaining = expiryDate.difference(now);

          return LicenseStatus.valid(
            licenseKey: cached['licenseKey'] ?? licenseKey,
            expiryDate: expiryDate,
            maxDevices: cached['maxDevices'] ?? 1,
            usedDevices: cached['usedDevices'] ?? 0,
            daysLeft: timeRemaining.inDays,
            formattedRemaining: _formatDuration(timeRemaining),
            isOffline: true,
          );
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Offline license check error: $e');
    }

    return LicenseStatus.invalid(
      reason: "No valid offline license found",
      isOffline: true,
    );
  }

  /// التحقق من وجود طلبات ترخيص pending
  Future<bool> hasPendingLicenseRequests() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final query = await _firestore
          .collection("license_requests")
          .where("userId", isEqualTo: user.uid)
          .where("status", isEqualTo: "pending")
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      safeDebugPrint('❌ License request check failed: $e');
      return false;
    }
  }

  /// الحصول على حالة ترخيص المستخدم الحالي
  Future<LicenseStatus> getCurrentUserLicenseStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return LicenseStatus.invalid(
        reason: "User not logged in",
        isOffline: false,
      );
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return LicenseStatus.invalid(
          reason: "User document not found",
          isOffline: false,
        );
      }

      final licenseKey = userDoc.data()?['licenseKey'];
      if (licenseKey == null || licenseKey.isEmpty) {
        return LicenseStatus.invalid(
          reason: "No license key found",
          isOffline: false,
        );
      }

      return await checkLicenseStatus(licenseKey);
    } catch (e) {
      safeDebugPrint('Error getting user license status: $e');
      return LicenseStatus.invalid(
        reason: "Error checking license: $e",
        isOffline: true,
      );
    }
  }

  // ==================== دوال تغيير الجهاز لمرة واحدة ====================

  Future<bool> canChangeDevice(String licenseKey) async {
    try {
      final licenseDoc = await _firestore.collection('licenses').doc(licenseKey).get();
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

  Future<bool> changeDevice(String licenseKey) async {
    try {
      if (!await canChangeDevice(licenseKey)) {
        safeDebugPrint('❌ Cannot change device - already changed once');
        return false;
      }

      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();
      
      final licenseDoc = await _firestore.collection('licenses').doc(licenseKey).get();
      if (!licenseDoc.exists) return false;

      final data = licenseDoc.data()!;
      final oldDevices = data['devices'] as List<dynamic>? ?? [];
      final originalFingerprint = oldDevices.isNotEmpty 
          ? oldDevices[0]['fingerprint'] 
          : null;
      
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final newDevice = {
        'fingerprint': currentFingerprint,
        'registeredAt': DateTime.now().toIso8601String(),
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'browser': deviceInfo['browser'],
        'lastActive': DateTime.now().toIso8601String(),
        'isReplacement': true,
        'replacedDeviceFingerprint': originalFingerprint,
      };
      
      await _firestore.collection('licenses').doc(licenseKey).update({
        'devices': [newDevice],
        'deviceIds': [currentFingerprint],
        'deviceChanged': true,
        'originalDeviceFingerprint': originalFingerprint,
        'deviceChangeDate': FieldValue.serverTimestamp(),
        'canChangeDeviceAgain': false,
      });
      
      await _firestore.collection('users').doc(user.uid).update({
        'deviceIds': [currentFingerprint],
        'lastDeviceChange': DateTime.now().toIso8601String(),
      });
      
      // ✅ تحديث البصمة في SecureStorage
      await _secureStorage.write(key: _keyFingerprint, value: currentFingerprint);
      
      safeDebugPrint('✅ Device changed successfully for license: $licenseKey');
      return true;
    } catch (e) {
      safeDebugPrint('❌ Error changing device: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getDeviceChangeStatus(String licenseKey) async {
    try {
      final licenseDoc = await _firestore.collection('licenses').doc(licenseKey).get();
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

  Future<bool> _checkIfAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      safeDebugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

// services/license_service.dart - أضف هذه الدالة في نهاية الكلاس

  /// ✅ التحقق مما إذا كان المستخدم الحالي Admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isAdmin = userDoc.data()?['isAdmin'] == true;
      
      if (isAdmin) {
        safeDebugPrint('👑 User ${user.email} is ADMIN');
        // حفظ في SecureStorage للاستخدام السريع
        await _secureStorage.write(key: 'isAdmin', value: 'true');
      } else {
        await _secureStorage.write(key: 'isAdmin', value: 'false');
      }
      
      return isAdmin;
    } catch (e) {
      safeDebugPrint('❌ Error checking admin status: $e');
      // محاولة القراءة من SecureStorage كبديل
      final cachedIsAdmin = await _secureStorage.read(key: 'isAdmin');
      if (cachedIsAdmin != null) {
        return cachedIsAdmin == 'true';
      }
      return false;
    }
  }
  
  Future<void> fixExistingLicenses() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final isAdmin = await _checkIfAdmin(user.uid);
      if (!isAdmin) return;

      final licenses = await _firestore.collection('licenses').get();

      for (var doc in licenses.docs) {
        await _fixLicense(doc);
      }
    } catch (e) {
      safeDebugPrint('❌ Error fixing licenses: $e');
    }
  }

  Future<void> _fixLicense(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final data = doc.data();
      if (data.isEmpty) return;

      final expiryDate = data['expiryDate'];
      if (expiryDate is! Timestamp) {
        DateTime? fixedDate;

        if (expiryDate is DateTime) {
          fixedDate = expiryDate;
        } else if (expiryDate is String) {
          fixedDate = DateTime.parse(expiryDate);
        }

        if (fixedDate != null) {
          await doc.reference.update({
            'expiryDate': Timestamp.fromDate(fixedDate),
            'lastFixed': DateTime.now().toIso8601String(),
          });
          safeDebugPrint('✅ Fixed license: ${doc.id}');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error fixing license ${doc.id}: $e');
    }
  }
}