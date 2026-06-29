/* // services/auto_license_service.dart - بدون Hive
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

  /// إنشاء ترخيص تلقائي للمستخدم الجديد لمدة شهر لجهاز واحد
/*   Future<String?> createAutoLicenseForNewUser(String userId) async {
    try {
      // التحقق مما إذا كان المستخدم لديه ترخيص بالفعل
      final existingLicense = await _getExistingLicense(userId);
      if (existingLicense != null) {
        safeDebugPrint('✅ User already has license: $existingLicense');
        return existingLicense;
      }

      // إنشاء ترخيص جديد
      final licenseKey = _generateLicenseKey(userId);
      final expiryDate = DateTime.now().add(const Duration(days: 30)); // شهر واحد
      final fingerprint = await DeviceFingerprint.getFingerprint();

      // إنشاء وثيقة الترخيص
      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': 1,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'devices': [
          {
            'fingerprint': fingerprint,
            'registeredAt': DateTime.now().toIso8601String(),
            'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
          }
        ],
        'deviceIds': [fingerprint],
        'durationMonths': 1,
        'isAutoCreated': true,
        'autoCreatedAt': FieldValue.serverTimestamp(),
        'deviceChanged': false,
        'canChangeDeviceAgain': false,
      });

      // تحديث وثيقة المستخدم
      await _firestore.collection('users').doc(userId).update({
        'licenseKey': licenseKey,
        'license_expiry': Timestamp.fromDate(expiryDate),
        'isActive': true,
        'maxDevices': 1,
        'hasAutoLicense': true,
        'autoLicenseCreatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ حفظ بصمة الجهاز في SecureStorage (مشفر)
      await _secureStorage.write(key: 'fingerprint', value: fingerprint);
      
      // ✅ حفظ حالة الترخيص في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      final licenseStatus = {
        'isValid': true,
        'licenseKey': licenseKey,
        'expiryDate': expiryDate.toIso8601String(),
        'maxDevices': 1,
        'usedDevices': 1,
        'deviceFingerprintValid': true,
        'daysLeft': 30,
      };
      await prefs.setString('licenseStatus', json.encode(licenseStatus));

      // ✅ حفظ الترخيص في SecureStorage
      await _secureStorage.write(key: 'licenseKey', value: licenseKey);

      safeDebugPrint('✅ Auto-license created for user $userId: $licenseKey');
      safeDebugPrint('   Expires: $expiryDate');
      safeDebugPrint('   Device fingerprint: $fingerprint');

      return licenseKey;
    } catch (e) {
      safeDebugPrint('❌ Failed to create auto-license: $e');
      return null;
    }
  }
 */

  // services/auto_license_service.dart - تعديل دالة createAutoLicenseForNewUser

  /// إنشاء ترخيص تلقائي للمستخدم الجديد لمدة شهر لجهاز واحد
/*   Future<String?> createAutoLicenseForNewUser(String userId) async {
    try {
      // ✅ التحقق مما إذا كان المستخدم لديه ترخيص بالفعل (من Firestore)
      final existingLicense = await _getExistingLicense(userId);
      if (existingLicense != null) {
        safeDebugPrint('✅ User already has license: $existingLicense');
        return existingLicense;
      }

      // ✅ التحقق: هل هذا مستخدم جديد حقاً؟
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final hasAutoLicense = userDoc.data()?['hasAutoLicense'] == true;
      final licenseKeyFromUser = userDoc.data()?['licenseKey'] as String?;

      // ✅ إذا كان المستخدم لديه ترخيص (قديم أو جديد) لا ننشئ ترخيصاً جديداً
      if (hasAutoLicense ||
          (licenseKeyFromUser != null && licenseKeyFromUser.isNotEmpty)) {
        safeDebugPrint('✅ User already has license key: $licenseKeyFromUser');
        return licenseKeyFromUser;
      }

      // ✅ إنشاء ترخيص جديد فقط للمستخدمين الجدد تماماً
      safeDebugPrint(
          '🆕 New user detected - creating auto-license for: $userId');

      final licenseKey = _generateLicenseKey(userId);
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      final fingerprint = await DeviceFingerprint.getFingerprint();

      // إنشاء وثيقة الترخيص
      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': 1,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'devices': [
          {
            'fingerprint': fingerprint,
            'registeredAt': DateTime.now().toIso8601String(),
            'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
          }
        ],
        'deviceIds': [fingerprint],
        'durationMonths': 1,
        'isAutoCreated': true,
        'autoCreatedAt': FieldValue.serverTimestamp(),
        'deviceChanged': false,
        'canChangeDeviceAgain': false,
      });

      // تحديث وثيقة المستخدم
      await _firestore.collection('users').doc(userId).update({
        'licenseKey': licenseKey,
        'license_expiry': Timestamp.fromDate(expiryDate),
        'isActive': true,
        'maxDevices': 1,
        'hasAutoLicense': true,
        'autoLicenseCreatedAt': FieldValue.serverTimestamp(),
      });

      // حفظ في SecureStorage
      await _secureStorage.write(key: 'fingerprint', value: fingerprint);
      await _secureStorage.write(key: 'licenseKey', value: licenseKey);

      final prefs = await SharedPreferences.getInstance();
      final licenseStatus = {
        'isValid': true,
        'licenseKey': licenseKey,
        'expiryDate': expiryDate.toIso8601String(),
        'maxDevices': 1,
        'usedDevices': 1,
        'deviceFingerprintValid': true,
        'daysLeft': 30,
      };
      await prefs.setString('licenseStatus', json.encode(licenseStatus));

      safeDebugPrint(
          '✅ Auto-license created for NEW user $userId: $licenseKey');
      safeDebugPrint('   Expires: $expiryDate');

      return licenseKey;
    } catch (e) {
      safeDebugPrint('❌ Failed to create auto-license: $e');
      return null;
    }
  }
 */
  
 /*  Future<String?> createAutoLicenseForNewUser(String userId) async {
  try {
    // ✅ 1: جلب بيانات المستخدم أولاً
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();

    if (userData == null) {
      safeDebugPrint('❌ User document not found: $userId');
      return null;
    }

    // ✅ 2: هل سبق استخدام التجربة؟ → لا ننشئ license جديد أبداً
    final trialUsed = userData['trialUsed'] == true;
    if (trialUsed) {
      safeDebugPrint('🚫 Trial already used for user: $userId — cannot create auto license');
      return null; // يجب على المستخدم إرسال طلب للأدمن
    }

    // ✅ 3: هل لديه license موجود وصالح؟
    final existingLicense = await _getExistingLicense(userId);
    if (existingLicense != null) {
      safeDebugPrint('✅ User already has valid license: $existingLicense');
      return existingLicense;
    }

    // ✅ 4: مستخدم جديد حقيقي → أنشئ license تجريبي
    safeDebugPrint('🆕 Creating trial license for new user: $userId');

    final licenseKey = _generateLicenseKey(userId);
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    final fingerprint = await DeviceFingerprint.getFingerprint();

    await _firestore.collection('licenses').doc(licenseKey).set({
      'licenseKey': licenseKey,
      'userId': userId,
      'maxDevices': 1,
      'isActive': true,
      'isTrialLicense': true,         // ✅ علامة واضحة
      'createdAt': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'devices': [
        {
          'fingerprint': fingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        }
      ],
      'deviceIds': [fingerprint],
      'durationMonths': 1,
      'isAutoCreated': true,
      'deviceChanged': false,
      'canChangeDeviceAgain': false,
    });

    // ✅ تحديث المستخدم وتأكيد استخدام التجربة نهائياً
    await _firestore.collection('users').doc(userId).update({
      'licenseKey': licenseKey,
      'license_expiry': Timestamp.fromDate(expiryDate),
      'isActive': true,
      'maxDevices': 1,
      'hasAutoLicense': true,
      'trialUsed': true,              // ✅ لن يُنشأ trial مرة ثانية أبداً
      'trialExpiryDate': Timestamp.fromDate(expiryDate),
      'autoLicenseCreatedAt': FieldValue.serverTimestamp(),
    });

    // ✅ حفظ محلي
    await _secureStorage.write(key: 'fingerprint', value: fingerprint);
    await _secureStorage.write(key: 'license_key', value: licenseKey);
    await _secureStorage.write(key: 'license_expiry', value: expiryDate.toIso8601String());
    await _secureStorage.write(key: 'license_status', value: 'active');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('licenseStatus', json.encode({
      'isValid': true,
      'licenseKey': licenseKey,
      'expiryDate': expiryDate.toIso8601String(),
      'daysLeft': 30,
    }));

    safeDebugPrint('✅ Trial license created: $licenseKey — expires: $expiryDate');
    return licenseKey;

  } catch (e) {
    safeDebugPrint('❌ Failed to create auto-license: $e');
    return null;
  }
}
   */
 


Future<String?> createAutoLicenseForNewUser(String userId) async {
  try {
    final userDoc = await _firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      safeDebugPrint('⚠️ User document missing — creating it for: $userId');

      // ✅ جلب بيانات المستخدم من Firebase Auth
      final authUser = FirebaseAuth.instance.currentUser;
      final email = authUser?.email ?? '';
      final displayName = authUser?.displayName ?? 
                          (email.isNotEmpty ? email.split('@')[0] : '');

      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'email': email,                    // ✅ من Auth
        'displayName': displayName,        // ✅ من Auth
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


    final userData = (await _firestore.collection('users').doc(userId).get()).data()!;

    // ✅ هل سبق استخدام التجربة؟
    final trialUsed = userData['trialUsed'] == true;
    if (trialUsed) {
      safeDebugPrint('🚫 Trial already used for: $userId');
      return null;
    }

    // ✅ هل لديه license صالح؟
    final existingLicense = await _getExistingLicense(userId);
    if (existingLicense != null) {
      safeDebugPrint('✅ Found existing valid license: $existingLicense');
      return existingLicense;
    }

    // ✅ أنشئ trial license
    safeDebugPrint('🆕 Creating trial license for: $userId');

    final licenseKey = _generateLicenseKey(userId);
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    final fingerprint = await DeviceFingerprint.getFingerprint();

    await _firestore.collection('licenses').doc(licenseKey).set({
      'licenseKey': licenseKey,
      'userId': userId,
      'maxDevices': 1,
      'isActive': true,
      'isTrialLicense': true,
      'createdAt': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'devices': [
        {
          'fingerprint': fingerprint,
          'registeredAt': DateTime.now().toIso8601String(),
          'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        }
      ],
      'deviceIds': [fingerprint],
      'durationMonths': 1,
      'isAutoCreated': true,
      'deviceChanged': false,
      'canChangeDeviceAgain': false,
    });

    await _firestore.collection('users').doc(userId).update({
      'licenseKey': licenseKey,
      'license_expiry': Timestamp.fromDate(expiryDate),
      'isActive': true,
      'maxDevices': 1,
      'hasAutoLicense': true,
      'trialUsed': true,
      'trialExpiryDate': Timestamp.fromDate(expiryDate),
      'autoLicenseCreatedAt': FieldValue.serverTimestamp(),
    });

    await _secureStorage.write(key: 'fingerprint', value: fingerprint);
    await _secureStorage.write(key: 'license_key', value: licenseKey);
    await _secureStorage.write(key: 'license_expiry', value: expiryDate.toIso8601String());
    await _secureStorage.write(key: 'license_status', value: 'active');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('licenseStatus', json.encode({
      'isValid': true,
      'licenseKey': licenseKey,
      'expiryDate': expiryDate.toIso8601String(),
      'daysLeft': 30,
    }));

    safeDebugPrint('✅ Trial license created: $licenseKey — expires: $expiryDate');
    return licenseKey;

  } catch (e) {
    safeDebugPrint('❌ Failed to create auto-license: $e');
    return null;
  }
}
 
  /// الحصول على الترخيص الموجود للمستخدم
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
        // التحقق من صلاحية الترخيص
        final licenseDoc =
            await _firestore.collection('licenses').doc(licenseKey).get();
        if (licenseDoc.exists) {
          final expiry = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
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

  /// توليد مفتاح ترخيص فريد
  String _generateLicenseKey(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart =
        timestamp.toString().substring(timestamp.toString().length - 6);
    final shortUserId = userId.length > 8 ? userId.substring(0, 8) : userId;
    return 'AUTO-$shortUserId-$randomPart';
  }

  /// التحقق مما إذا كان المستخدم لديه ترخيص تلقائي صالح
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
 */