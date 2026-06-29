// services/auto_license_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AutoLicenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ============================================================
  // ✅ إنشاء ترخيص تلقائي للمستخدم الجديد — شهر واحد / جهاز واحد
  // ============================================================
  Future<String?> createAutoLicenseForNewUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      // ── إنشاء user document لو مش موجود (حالة فشل التسجيل السابق) ──
      if (!userDoc.exists) {
        safeDebugPrint('⚠️ User document missing — creating it for: $userId');

        final authUser = FirebaseAuth.instance.currentUser;
        final email = authUser?.email ?? '';
        final displayName = authUser?.displayName ??
            (email.isNotEmpty ? email.split('@')[0] : '');

        await _firestore.collection('users').doc(userId).set({
          'userId': userId,
          'email': email,
          'displayName': displayName,
          'phoneNumber': authUser?.phoneNumber ?? '',
          'companyIds': [],
          'supplierIds': [],
          'factoryIds': [],
          'isActive': true,
          'isAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'trialUsed': false,
        });
      }

      // ── إعادة جلب البيانات بعد الإنشاء ──
      final userData =
          (await _firestore.collection('users').doc(userId).get()).data()!;

      // ── هل سبق استخدام التجربة؟ ──
      final trialUsed = userData['trialUsed'] == true;
      if (trialUsed) {
        safeDebugPrint('🚫 Trial already used for: $userId');
        return null;
      }

      // ── هل لديه license صالح؟ ──
      final existingLicense = await _getExistingLicense(userId);
      if (existingLicense != null) {
        safeDebugPrint('✅ Found existing valid license: $existingLicense');
        return existingLicense;
      }

      // ── إنشاء trial license جديد ──
      safeDebugPrint('🆕 Creating trial license for: $userId');

      final licenseKey = _generateLicenseKey(userId);
      final expiryDate = DateTime.now().add(const Duration(days: 30));

      // ✅ جلب بيانات الجهاز الكاملة
      final fingerprint = await DeviceFingerprint.getFingerprint();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      final deviceEntry = {
        'fingerprint': fingerprint,
        'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'registeredAt': DateTime.now().toIso8601String(),
        // ✅ بيانات الجهاز الكاملة
        'platform': deviceInfo['platform'] ?? '',
        'brand': deviceInfo['brand'] ?? '',
        'model': deviceInfo['model'] ?? '',
        'manufacturer': deviceInfo['manufacturer'] ?? '',
        'androidVersion': deviceInfo['androidVersion'] ?? '',
        'buildId': deviceInfo['buildId'] ?? '',
        'deviceName': deviceInfo['deviceName'] ?? '',
      };

      // ── إنشاء license document ──
      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': 1,
        'isActive': true,
        'isTrialLicense': true,
        'licenseType': 'trial',       // ✅ نوع الترخيص
        'licensePrefix': 'AUTO',
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'devices': [deviceEntry],
        'deviceIds': [fingerprint],
        'durationMonths': 1,
        'isAutoCreated': true,
        'deviceChanged': false,
        'canChangeDeviceAgain': false,
      });

      // ── تحديث user document ──
      await _firestore.collection('users').doc(userId).update({
        'licenseKey': licenseKey,
        'license_expiry': Timestamp.fromDate(expiryDate),
        'isActive': true,
        'maxDevices': 1,
        'hasAutoLicense': true,
        'trialUsed': true,            // ✅ لن يُنشأ trial مرة ثانية أبداً
        'trialExpiryDate': Timestamp.fromDate(expiryDate),
        'licenseType': 'trial',       // ✅ ظاهر مباشرة في user document
        'autoLicenseCreatedAt': FieldValue.serverTimestamp(),
        'primaryDevice': deviceInfo['deviceName'] ?? '',
        'deviceIds': [deviceEntry],
        'lastDeviceRegistration': DateTime.now().toIso8601String(),
      });

      // ── حفظ محلي ──
      await _secureStorage.write(key: 'fingerprint', value: fingerprint);
      await _secureStorage.write(key: 'license_key', value: licenseKey);
      await _secureStorage.write(
          key: 'license_expiry', value: expiryDate.toIso8601String());
      await _secureStorage.write(key: 'license_status', value: 'active');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'licenseStatus',
          json.encode({
            'isValid': true,
            'licenseKey': licenseKey,
            'expiryDate': expiryDate.toIso8601String(),
            'daysLeft': 30,
            'licenseType': 'trial',
          }));

      safeDebugPrint(
          '✅ Trial license created: $licenseKey — expires: $expiryDate');
      safeDebugPrint(
          '✅ Device: ${deviceInfo['deviceName']} (${deviceInfo['platform']})');
      return licenseKey;
    } catch (e) {
      safeDebugPrint('❌ Failed to create auto-license: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ نوع الترخيص من اسمه
  // ============================================================
  static String getLicenseType(String licenseKey) {
    if (licenseKey.startsWith('AUTO-')) return 'trial';
    if (licenseKey.startsWith('LIC-')) return 'licensed';
    return 'unknown';
  }

  static bool isTrialLicense(String licenseKey) =>
      licenseKey.startsWith('AUTO-');

  static String getLicenseTypeLabel(String licenseKey) {
    if (licenseKey.startsWith('AUTO-')) return '🔬 Trial';
    if (licenseKey.startsWith('LIC-')) return '✅ Licensed';
    return '❓ Unknown';
  }

  // ============================================================
  // ✅ الحصول على الترخيص الموجود للمستخدم
  // ============================================================
  Future<String?> _getExistingLicense(String userId) async {
    try {
      // البحث في licenses collection
      final licensesSnapshot = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in licensesSnapshot.docs) {
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          safeDebugPrint('✅ Found valid existing license: ${doc.id}');
          return doc.id;
        }
      }

      // البحث في user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final licenseKey = userDoc.data()?['licenseKey'] as String?;

      if (licenseKey != null && licenseKey.isNotEmpty) {
        final licenseDoc =
            await _firestore.collection('licenses').doc(licenseKey).get();
        if (licenseDoc.exists) {
          final expiry =
              (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
          if (expiry != null && expiry.isAfter(DateTime.now())) {
            safeDebugPrint('✅ Found valid license from user doc: $licenseKey');
            return licenseKey;
          }
        }
      }

      return null;
    } catch (e) {
      safeDebugPrint('Error checking existing license: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ توليد مفتاح ترخيص فريد
  // ============================================================
  String _generateLicenseKey(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart =
        timestamp.toString().substring(timestamp.toString().length - 6);
    final shortUserId = userId.length > 8 ? userId.substring(0, 8) : userId;
    return 'AUTO-$shortUserId-$randomPart';
  }

  // ============================================================
  // ✅ التحقق مما إذا كان المستخدم لديه ترخيص تلقائي صالح
  // ============================================================
  Future<bool> hasValidAutoLicense(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final hasAutoLicense = userDoc.data()?['hasAutoLicense'] == true;
      final licenseKey = userDoc.data()?['licenseKey'] as String?;

      if (!hasAutoLicense || licenseKey == null) return false;

      final licenseDoc =
          await _firestore.collection('licenses').doc(licenseKey).get();
      if (!licenseDoc.exists) return false;

      final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
      final isActive = licenseDoc.get('isActive') ?? false;

      return isActive && expiry != null && expiry.isAfter(DateTime.now());
    } catch (e) {
      safeDebugPrint('Error checking auto license: $e');
      return false;
    }
  }
}