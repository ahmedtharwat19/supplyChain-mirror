/* // services/license_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'device_fingerprint.dart';
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

  static const _deviceBoxName = 'deviceBox';

  /// فتح الـ Hive Box عند بداية التشغيل
  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_deviceBoxName)) {
      await Hive.openBox(_deviceBoxName);
    }
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

  /// إنشاء لايسنس جديد
  Future<String> createLicense({
    required String userId,
    required int durationSeconds,
    required int maxDevices,
    required String requestId,
  }) async {
    try {
      final licenseKey = await generateStandardizedId(isLicense: true);
      final expiryDate = DateTime.now().add(Duration(seconds: durationSeconds));

      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': maxDevices,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'originalRequestId': requestId,
        'devices': [],
      });

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'linkedLicenseKey': licenseKey,
      });

      return licenseKey;
    } catch (e) {
      throw Exception("Failed to create license: $e");
    }
  }

  /// إصلاح التراخيص الموجودة
  Future<void> fixExistingLicenses() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final isAdmin = await _checkIfAdmin(user.uid);

      if (isAdmin) {
        final licenses = await _firestore.collection('licenses').get();
        await _fixLicenses(licenses.docs);
      } else {
        try {
          final userLicenses = await _firestore
              .collection('licenses')
              .where('userId', isEqualTo: user.uid)
              .get();
          await _fixLicenses(userLicenses.docs);
        } catch (e) {
          safeDebugPrint('User cannot query licenses, trying individual documents...');
          await _fixUserLicensesIndividually(user.uid);
        }
      }
    } catch (e) {
      safeDebugPrint('Error fixing licenses: $e');
    }
  }

  Future<void> _fixLicenses(List<QueryDocumentSnapshot<Map<String, dynamic>>> licenses) async {
    for (var doc in licenses) {
      final data = doc.data();
      if (data.isEmpty) continue;

      final expiryDate = data['expiryDate'];
      if (expiryDate is! Timestamp) {
        DateTime date;

        if (expiryDate is DateTime) {
          date = expiryDate;
        } else if (expiryDate is String) {
          date = DateTime.parse(expiryDate);
        } else {
          continue;
        }

        await doc.reference.update({'expiryDate': Timestamp.fromDate(date)});
        safeDebugPrint('Fixed license: ${doc.id}');
      }
    }
  }

  Future<void> _fixUserLicensesIndividually(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final licenseKey = userDoc.data()?['licenseKey'];

      if (licenseKey != null) {
        final licenseDoc = await _firestore.collection('licenses').doc(licenseKey).get();
        if (licenseDoc.exists) {
          await _fixLicenses([licenseDoc as QueryDocumentSnapshot<Map<String, dynamic>>]);
        }
      }
    } catch (e) {
      safeDebugPrint('Error fixing user licenses individually: $e');
    }
  }

  Future<bool> _checkIfAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      safeDebugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// تسجيل الجهاز الحالي في اللايسنس
  Future<LicenseStatus> registerCurrentDevice(String licenseKey) async {
    final fingerprint = await DeviceFingerprint.getFingerprint();

    final docRef = _firestore.collection('licenses').doc(licenseKey);
    final doc = await docRef.get();

    if (!doc.exists) {
      return LicenseStatus.invalid(
        reason: "License not found",
        isOffline: false,
      );
    }

    final data = doc.data();
    if (data == null) {
      return LicenseStatus.invalid(
        reason: "License data is null",
        isOffline: false,
      );
    }

    dynamic expiryDateValue = data['expiryDate'];
    DateTime expiryDate;

    if (expiryDateValue is Timestamp) {
      expiryDate = expiryDateValue.toDate();
    } else if (expiryDateValue is DateTime) {
      expiryDate = expiryDateValue;
    } else if (expiryDateValue is String) {
      expiryDate = DateTime.parse(expiryDateValue);
    } else {
      return LicenseStatus.invalid(
        reason: "Invalid expiry date format",
        isOffline: false,
      );
    }

    final maxDevices = data['maxDevices'] ?? 1;
    final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
    final isActive = data['isActive'] ?? false;

    if (!isActive) {
      return LicenseStatus.invalid(
        reason: "License inactive",
        isOffline: false,
      );
    }

    if (expiryDate.isBefore(DateTime.now())) {
      return LicenseStatus.invalid(
        reason: "License expired",
        isOffline: false,
      );
    }

    final alreadyRegistered = devices.any((d) => d['fingerprint'] == fingerprint);

    if (!alreadyRegistered) {
      if (devices.length < maxDevices) {
        await docRef.update({
          'devices': FieldValue.arrayUnion([
            {
              'fingerprint': fingerprint,
              'registeredAt': DateTime.now().toIso8601String(),
            }
          ])
        });
      } else {
        return LicenseStatus.invalid(
          reason: "Device limit exceeded",
          isOffline: false,
        );
      }
    }

    final durationLeft = expiryDate.difference(DateTime.now());
    final formattedRemaining = _formatDuration(durationLeft);

    return LicenseStatus.valid(
      licenseKey: licenseKey,
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: devices.length,
      daysLeft: durationLeft.inDays,
      formattedRemaining: formattedRemaining,
      isOffline: false,
    );
  }

  /// التحقق من حالة اللايسنس

// في license_service.dart
/// التحقق من حالة اللايسنس
Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
  try {
    final user = _auth.currentUser;
    safeDebugPrint('Current user UID: ${user?.uid}');
    safeDebugPrint('Checking license: $licenseKey');
    final box = await Hive.openBox(_deviceBoxName);

    String? currentFingerprint = box.get('fingerprint');
    if (currentFingerprint == null) {
      currentFingerprint = await DeviceFingerprint.getFingerprint();
      await box.put('fingerprint', currentFingerprint);
    }

    try {
      final doc = await _firestore.collection('licenses').doc(licenseKey).get();

      if (!doc.exists) {
        safeDebugPrint('License document does not exist');
        return LicenseStatus.invalid(
          reason: "License not found",
          isOffline: false,
        );
      }

      final data = doc.data();
      if (data == null) {
        safeDebugPrint('License document data is null');
        return LicenseStatus.invalid(
          reason: "License data is null",
          isOffline: false,
        );
      }

      final licenseUserId = data['userId'];
      safeDebugPrint('License user ID: $licenseUserId');
      safeDebugPrint('Current user UID: ${user?.uid}');
      safeDebugPrint('User match: ${licenseUserId == user?.uid}');

      dynamic expiryDateValue = data['expiryDate'];
      DateTime expiryDate;

      if (expiryDateValue is Timestamp) {
        expiryDate = expiryDateValue.toDate();
      } else if (expiryDateValue is DateTime) {
        expiryDate = expiryDateValue;
      } else if (expiryDateValue is String) {
        expiryDate = DateTime.parse(expiryDateValue);
      } else {
        safeDebugPrint('Unknown expiryDate type: ${expiryDateValue.runtimeType}');
        return LicenseStatus.invalid(
          reason: "Invalid expiry date format",
          isOffline: false,
        );
      }

      safeDebugPrint('Expiry date: $expiryDate');
      safeDebugPrint('Current time: ${DateTime.now()}');

      final maxDevices = data['maxDevices'] ?? 1;
      final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
      final isActive = data['isActive'] ?? false;

      safeDebugPrint('License isActive: $isActive');
      safeDebugPrint('Max devices: $maxDevices');
      safeDebugPrint('Registered devices: ${devices.length}');

      if (!isActive) {
        safeDebugPrint('License is not active');
        return LicenseStatus.invalid(
          reason: "License inactive",
          isOffline: false,
        );
      }

      if (expiryDate.isBefore(DateTime.now())) {
        safeDebugPrint('License expired: $expiryDate');
        return LicenseStatus.invalid(
          reason: "License expired",
          isOffline: false,
        );
      }

      final isRegistered = devices.any((d) => d['fingerprint'] == currentFingerprint);
      safeDebugPrint('Device is registered: $isRegistered');

      // حساب الوقت المتبقي
      final durationLeft = expiryDate.difference(DateTime.now());
      final daysLeft = durationLeft.inDays;
      final hours = durationLeft.inHours % 24;
      final minutes = durationLeft.inMinutes % 60;
      final formattedRemaining = '${daysLeft}d ${hours}h ${minutes}m';

      if (!isRegistered) {
        if (devices.length < maxDevices) {
          // يمكن تسجيل الجهاز
          await _firestore.collection('licenses').doc(licenseKey).update({
            'devices': FieldValue.arrayUnion([
              {'fingerprint': currentFingerprint}
            ]),
          });
          
          // تحديث عدد الأجهزة بعد التسجيل
          final updatedDevices = devices.length + 1;
          
          await box.put('license_cache', {
            'licenseKey': licenseKey,
            'expiryDate': expiryDate.toIso8601String(),
            'maxDevices': maxDevices,
            'usedDevices': updatedDevices,
          });

          return LicenseStatus.valid(
            licenseKey: licenseKey,
            expiryDate: expiryDate,
            maxDevices: maxDevices,
            usedDevices: updatedDevices,
            daysLeft: daysLeft,
            formattedRemaining: formattedRemaining,
            isOffline: false,
          );
        } else {
          // تجاوز الحد الأقصى للأجهزة
          safeDebugPrint('Device limit exceeded');
          return LicenseStatus(
            isValid: false,
            isOffline: false,
            licenseKey: licenseKey,
            expiryDate: expiryDate,
            maxDevices: maxDevices,
            usedDevices: devices.length,
            daysLeft: daysLeft,
            formattedRemaining: formattedRemaining,
            reason: "Device limit exceeded",
            deviceLimitExceeded: true,
          );
        }
      }

      // الجهاز مسجل بالفعل
      await box.put('license_cache', {
        'licenseKey': licenseKey,
        'expiryDate': expiryDate.toIso8601String(),
        'maxDevices': maxDevices,
        'usedDevices': devices.length,
      });

      safeDebugPrint('License is valid. Days left: $daysLeft');

      return LicenseStatus.valid(
        licenseKey: licenseKey,
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: devices.length,
        daysLeft: daysLeft,
        formattedRemaining: formattedRemaining,
        isOffline: false,
      );
    } catch (_) {
      // حالة عدم وجود إنترنت
      final cached = box.get('license_cache');

      if (cached != null) {
        final expiryDate = DateTime.parse(cached['expiryDate']);
        if (expiryDate.isBefore(DateTime.now())) {
          return LicenseStatus.invalid(
            reason: "License expired (offline)",
            isOffline: true,
          );
        }

        final durationLeft = expiryDate.difference(DateTime.now());
        final daysLeft = durationLeft.inDays;
        final hours = durationLeft.inHours % 24;
        final minutes = durationLeft.inMinutes % 60;
        final formattedRemaining = '${daysLeft}d ${hours}h ${minutes}m';

        return LicenseStatus.valid(
          licenseKey: cached['licenseKey'],
          expiryDate: expiryDate,
          maxDevices: cached['maxDevices'],
          usedDevices: cached['usedDevices'],
          daysLeft: daysLeft,
          formattedRemaining: formattedRemaining,
          isOffline: true,
        );
      }

      return LicenseStatus.invalid(
        reason: "No internet and no cached license found",
        isOffline: true,
      );
    }
  } catch (e) {
    safeDebugPrint('License check overall error: $e');
    return LicenseStatus.invalid(
      reason: "Error: $e",
      isOffline: true,
    );
  }
}

/*   Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
    try {
      final user = _auth.currentUser;
      safeDebugPrint('Current user UID: ${user?.uid}');
      safeDebugPrint('Checking license: $licenseKey');
      final box = await Hive.openBox(_deviceBoxName);

      String? currentFingerprint = box.get('fingerprint');
      if (currentFingerprint == null) {
        currentFingerprint = await DeviceFingerprint.getFingerprint();
        await box.put('fingerprint', currentFingerprint);
      }

      try {
        final doc = await _firestore.collection('licenses').doc(licenseKey).get();

        if (!doc.exists) {
          safeDebugPrint('License document does not exist');
          return LicenseStatus.invalid(
            reason: "License not found",
            isOffline: false,
          );
        }

        final data = doc.data();
        if (data == null) {
          safeDebugPrint('License document data is null');
          return LicenseStatus.invalid(
            reason: "License data is null",
            isOffline: false,
          );
        }

        final licenseUserId = data['userId'];
        safeDebugPrint('License user ID: $licenseUserId');
        safeDebugPrint('Current user UID: ${user?.uid}');
        safeDebugPrint('User match: ${licenseUserId == user?.uid}');

        dynamic expiryDateValue = data['expiryDate'];
        DateTime expiryDate;

        if (expiryDateValue is Timestamp) {
          expiryDate = expiryDateValue.toDate();
        } else if (expiryDateValue is DateTime) {
          expiryDate = expiryDateValue;
        } else if (expiryDateValue is String) {
          expiryDate = DateTime.parse(expiryDateValue);
        } else {
          safeDebugPrint('Unknown expiryDate type: ${expiryDateValue.runtimeType}');
          return LicenseStatus.invalid(
            reason: "Invalid expiry date format",
            isOffline: false,
          );
        }

        safeDebugPrint('Expiry date: $expiryDate');
        safeDebugPrint('Current time: ${DateTime.now()}');

        final maxDevices = data['maxDevices'] ?? 1;
        final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
        final isActive = data['isActive'] ?? false;

        safeDebugPrint('License isActive: $isActive');
        safeDebugPrint('Max devices: $maxDevices');
        safeDebugPrint('Registered devices: ${devices.length}');

        if (!isActive) {
          safeDebugPrint('License is not active');
          return LicenseStatus.invalid(
            reason: "License inactive",
            isOffline: false,
          );
        }

        if (expiryDate.isBefore(DateTime.now())) {
          safeDebugPrint('License expired: $expiryDate');
          return LicenseStatus.invalid(
            reason: "License expired",
            isOffline: false,
          );
        }

        final isRegistered = devices.any((d) => d['fingerprint'] == currentFingerprint);
        safeDebugPrint('Device is registered: $isRegistered');

        if (!isRegistered) {
          if (devices.length < maxDevices) {
            await _firestore.collection('licenses').doc(licenseKey).update({
              'devices': FieldValue.arrayUnion([
                {'fingerprint': currentFingerprint}
              ]),
            });
          } else {
            safeDebugPrint('Device limit exceeded');
            return LicenseStatus.invalid(
              reason: "Device limit exceeded",
              isOffline: false,
            );
          }
        }

        final durationLeft = expiryDate.difference(DateTime.now());
        final formattedRemaining = _formatDuration(durationLeft);

        await box.put('license_cache', {
          'licenseKey': licenseKey,
          'expiryDate': expiryDate.toIso8601String(),
          'maxDevices': maxDevices,
          'usedDevices': devices.length,
        });

        safeDebugPrint('License is valid. Days left: ${durationLeft.inDays}');

        return LicenseStatus.valid(
          licenseKey: licenseKey,
          expiryDate: expiryDate,
          maxDevices: maxDevices,
          usedDevices: devices.length,
          daysLeft: durationLeft.inDays,
          formattedRemaining: formattedRemaining,
          isOffline: false,
        );
      } catch (_) {
        final cached = box.get('license_cache');

        if (cached != null) {
          final expiryDate = DateTime.parse(cached['expiryDate']);
          if (expiryDate.isBefore(DateTime.now())) {
            return LicenseStatus.invalid(
              reason: "License expired (offline)",
              isOffline: true,
            );
          }

          final durationLeft = expiryDate.difference(DateTime.now());
          final formattedRemaining = _formatDuration(durationLeft);

          return LicenseStatus.valid(
            licenseKey: cached['licenseKey'],
            expiryDate: expiryDate,
            maxDevices: cached['maxDevices'],
            usedDevices: cached['usedDevices'],
            daysLeft: durationLeft.inDays,
            formattedRemaining: formattedRemaining,
            isOffline: true,
          );
        }

        return LicenseStatus.invalid(
          reason: "No internet and no cached license found",
          isOffline: true,
        );
      }
    } catch (e) {
      safeDebugPrint('License check overall error: $e');
      return LicenseStatus.invalid(
        reason: "Error: $e",
        isOffline: true,
      );
    }
  }
 */
  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    String result = "";
    if (days > 0) result += "$days يوم ";
    if (hours > 0) result += "$hours ساعة ";
    if (minutes > 0) result += "$minutes دقيقة ";
    if (seconds > 0 && days == 0) result += "$seconds ثانية ";

    return result.trim().isEmpty ? "منتهي" : "متبقي $result";
  }

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
      safeDebugPrint('License request check failed: $e');
      return false;
    }
  }



/*   Future<LicenseStatus> _checkOfflineLicenseStatus() async {

  
    try {
      final box = await Hive.openBox(_deviceBoxName);
      final cachedLicense = box.get('license_cache');
      
      if (cachedLicense != null && cachedLicense is Map<String, dynamic>) {
        final expiryDate = DateTime.parse(cachedLicense['expiryDate']);
        if (expiryDate.isAfter(DateTime.now())) {
          return LicenseStatus.valid(
            licenseKey: cachedLicense['licenseKey'] ?? 'offline',
            expiryDate: expiryDate,
            maxDevices: cachedLicense['maxDevices'] ?? 1,
            usedDevices: cachedLicense['usedDevices'] ?? 0,
            daysLeft: expiryDate.difference(DateTime.now()).inDays,
            formattedRemaining: 'Offline',
            isOffline: true,
          );
        }
      }
    } catch (e) {
      safeDebugPrint('Offline license check error: $e');
    }
    
    return LicenseStatus.invalid(
      reason: 'No valid offline license',
      isOffline: true,
    );
  }

  Future<Map<String, dynamic>> _checkDeviceStatus(String licenseId) async {
    try {
      final currentFingerprint = await DeviceFingerprint.getFingerprint();
      final box = await Hive.openBox('auth');
      final localFingerprint = box.get('fingerprint');

      if (localFingerprint != null && localFingerprint == currentFingerprint) {
        return {'isValid': true, 'reason': 'Device registered'};
      }

      final licenseDoc = await _firestore.collection('licenses').doc(licenseId).get();
      if (!licenseDoc.exists) {
        return {'isValid': false, 'reason': 'License not found'};
      }

      final data = licenseDoc.data()!;
      final devices = data['devices'] as List<dynamic>? ?? [];

      final isDeviceRegistered = devices.any((device) =>
          device is Map<String, dynamic> &&
          device['fingerprint'] == currentFingerprint);

      if (isDeviceRegistered) {
        await box.put('fingerprint', currentFingerprint);
        return {'isValid': true, 'reason': 'Device registered'};
      }

      return {'isValid': false, 'reason': 'Device not registered'};

    } catch (e) {
      return {'isValid': false, 'reason': 'Device check error: $e'};
    }
  }
 */} */
// services/license_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'device_fingerprint.dart';
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

  static const _deviceBoxName = 'deviceBox';

  /// فتح الـ Hive Box عند بداية التشغيل
  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_deviceBoxName)) {
      await Hive.openBox(_deviceBoxName);
    }
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

  /// إنشاء لايسنس جديد مع التحقق بالثواني
  Future<String> createLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
    required String requestId,
  }) async {
    try {
      // حساب المدة بالثواني بدقة
      final secondsInMonth =
          30 * 24 * 60 * 60; // 30 يوم × 24 ساعة × 60 دقيقة × 60 ثانية
      final durationSeconds = durationMonths * secondsInMonth;

      final licenseKey = await generateStandardizedId(isLicense: true);

      // حساب تاريخ الانتهاء بدقة بالثواني
      final now = DateTime.now().toUtc();
      final expiryDate = now.add(Duration(seconds: durationSeconds));

      await _firestore.collection('licenses').doc(licenseKey).set({
        'licenseKey': licenseKey,
        'userId': userId,
        'maxDevices': maxDevices,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now), // استخدام Timestamp مباشرة
        'expiryDate': Timestamp.fromDate(expiryDate),
        'originalRequestId': requestId,
        'devices': [],
        'durationMonths': durationMonths,
        'durationSeconds': durationSeconds, // حفظ المدة بالثواني
        'createdAtTimestamp': now.millisecondsSinceEpoch,
      });

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': 'approved',
        'processedAt': DateTime.now().toIso8601String(),
        'linkedLicenseKey': licenseKey,
      });

      safeDebugPrint('✅ License created: $licenseKey');
      safeDebugPrint('   Expiry: $expiryDate');
      safeDebugPrint(
          '   Duration: $durationSeconds seconds ($durationMonths months)');

      return licenseKey;
    } catch (e) {
      safeDebugPrint('❌ Failed to create license: $e');
      throw Exception("Failed to create license: $e");
    }
  }

  /// التحقق من صلاحية الترخيص بالثواني
/*   Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(
          reason: "User not logged in",
          isOffline: false,
        );
      }

      final box = await Hive.openBox(_deviceBoxName);

      // الحصول على بصمة الجهاز
      String currentFingerprint =
          box.get('fingerprint') ?? await DeviceFingerprint.getFingerprint();
      await box.put('fingerprint', currentFingerprint);

      try {
        // محاولة الاتصال بـ Firestore
        final doc =
            await _firestore.collection('licenses').doc(licenseKey).get();

        if (!doc.exists) {
          return LicenseStatus.invalid(
            reason: "License not found",
            isOffline: false,
          );
        }

        final data = doc.data();
        if (data == null) {
          return LicenseStatus.invalid(
            reason: "License data is null",
            isOffline: false,
          );
        }

        // التحقق من ملكية الترخيص
        final licenseUserId = data['userId'];
        if (licenseUserId != user.uid) {
          return LicenseStatus.invalid(
            reason: "License does not belong to current user",
            isOffline: false,
          );
        }

        // معالجة تاريخ الانتهاء
        final expiryDate = _parseExpiryDate(data['expiryDate']);
        if (expiryDate == null) {
          return LicenseStatus.invalid(
            reason: "Invalid expiry date format",
            isOffline: false,
          );
        }

        final maxDevices = data['maxDevices'] ?? 1;
        final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
        final isActive = data['isActive'] ?? false;

        // التحقق من الحالة
        if (!isActive) {
          return LicenseStatus.invalid(
            reason: "License inactive",
            isOffline: false,
          );
        }

        // التحقق من الانتهاء بالثواني
        final now = DateTime.now().toUtc();
        final expiryUtc = expiryDate.toUtc();

        if (now.isAfter(expiryUtc)) {
          return LicenseStatus.invalid(
            reason: "License expired",
            isOffline: false,
          );
        }

        // التحقق من تسجيل الجهاز
        final isRegistered =
            devices.any((d) => d['fingerprint'] == currentFingerprint);

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
            );
          }

          // تسجيل الجهاز الجديد
          await _registerDevice(licenseKey, currentFingerprint, devices);
        }

        // حساب الوقت المتبقي بدقة
        final timeRemaining = expiryUtc.difference(now);
        final formattedTime = _formatDuration(timeRemaining);

        // حفظ البيانات للتخزين المؤقت
        await _cacheLicenseData(
            box, licenseKey, expiryDate, maxDevices, devices.length);

        return LicenseStatus.valid(
          licenseKey: licenseKey,
          expiryDate: expiryDate,
          maxDevices: maxDevices,
          usedDevices: devices.length + (isRegistered ? 0 : 1),
          daysLeft: timeRemaining.inDays,
          formattedRemaining: formattedTime,
          isOffline: false,
        );
      } catch (e) {
        // حالة عدم الاتصال - استخدام البيانات المخزنة
        return await _getOfflineLicenseStatus(box, licenseKey);
      }
    } catch (e) {
      safeDebugPrint('❌ License check error: $e');
      return LicenseStatus.invalid(
        reason: "System error: $e",
        isOffline: true,
      );
    }
  }
 */
Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      return LicenseStatus.invalid(
        reason: "User not logged in",
        isOffline: false,
      );
    }

    final box = await Hive.openBox(_deviceBoxName);
    String currentFingerprint = box.get('fingerprint') ?? await DeviceFingerprint.getFingerprint();
    await box.put('fingerprint', currentFingerprint);

    try {
      // ✅ التغيير الرئيسي: الحصول من collection 'users' بدلاً من 'licenses'
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

      // ✅ التحقق من أن الترخيص matches مع licenseKey المطلوب
      final userLicenseKey = userData['licenseKey'];
      if (userLicenseKey != licenseKey) {
        return LicenseStatus.invalid(
          reason: "License key does not match user's license",
          isOffline: false,
        );
      }

      // ✅ معالجة تاريخ الانتهاء من userData
      final expiryDate = (userData['license_expiry'] as Timestamp?)?.toDate();
      if (expiryDate == null) {
        return LicenseStatus.invalid(
          reason: "Invalid expiry date format",
          isOffline: false,
        );
      }

      final maxDevices = userData['maxDevices'] ?? 1;
      final isActive = userData['isActive'] ?? false;

      // ✅ الحصول على قائمة الأجهزة (قد تكون في حقل deviceIds أو devices)
      final devices = List<Map<String, dynamic>>.from(userData['deviceIds'] ?? userData['devices'] ?? []);

      // التحقق من الحالة
      if (!isActive) {
        return LicenseStatus.invalid(
          reason: "License inactive",
          isOffline: false,
        );
      }

      // التحقق من الانتهاء
      final now = DateTime.now().toUtc();
      final expiryUtc = expiryDate.toUtc();

      if (now.isAfter(expiryUtc)) {
        return LicenseStatus.invalid(
          reason: "License expired",
          isOffline: false,
        );
      }

      // التحقق من تسجيل الجهاز
      final isRegistered = devices.any((d) => d['fingerprint'] == currentFingerprint);

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
          );
        }

        // ✅ تسجيل الجهاز الجديد في user document
        await _registerDeviceInUser(user.uid, currentFingerprint, devices);
      }

      // حساب الوقت المتبقي
      final timeRemaining = expiryUtc.difference(now);
      final formattedTime = _formatDuration(timeRemaining);

      // حفظ البيانات للتخزين المؤقت
      await _cacheLicenseData(box, licenseKey, expiryDate, maxDevices, devices.length + (isRegistered ? 0 : 1));

      return LicenseStatus.valid(
        licenseKey: licenseKey,
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: devices.length + (isRegistered ? 0 : 1),
        daysLeft: timeRemaining.inDays,
        formattedRemaining: formattedTime,
        isOffline: false,
      );

    } catch (e) {
      // حالة عدم الاتصال - استخدام البيانات المخزنة
      return await _getOfflineLicenseStatus(box, licenseKey);
    }
  } catch (e) {
    safeDebugPrint('❌ License check error: $e');
    return LicenseStatus.invalid(
      reason: "System error: $e",
      isOffline: true,
    );
  }
}

Future<void> _registerDeviceInUser(String userId, String fingerprint, List<Map<String, dynamic>> currentDevices) async {
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

/*   /// تسجيل الجهاز في الترخيص
  Future<void> _registerDevice(String licenseKey, String fingerprint,
      List<Map<String, dynamic>> currentDevices) async {
    try {
      await _firestore.collection('licenses').doc(licenseKey).update({
        'devices': FieldValue.arrayUnion([
          {
            'fingerprint': fingerprint,
            'registeredAt': DateTime.now().toUtc().toIso8601String(),
            'lastSeen': DateTime.now().toUtc().toIso8601String(),
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      safeDebugPrint('❌ Error registering device: $e');
      throw Exception('Failed to register device');
    }
  }

  /// معالجة تاريخ الانتهاء
  DateTime? _parseExpiryDate(dynamic expiryDateValue) {
    try {
      if (expiryDateValue is Timestamp) {
        return expiryDateValue.toDate();
      } else if (expiryDateValue is DateTime) {
        return expiryDateValue;
      } else if (expiryDateValue is String) {
        return DateTime.parse(expiryDateValue);
      }
      return null;
    } catch (e) {
      safeDebugPrint('❌ Error parsing expiry date: $e');
      return null;
    }
  }
 */
  /// تنسيق المدة الزمنية
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

  /// التخزين المؤقت لبيانات الترخيص
  Future<void> _cacheLicenseData(Box box, String licenseKey,
      DateTime expiryDate, int maxDevices, int usedDevices) async {
    try {
      await box.put('license_cache', {
        'licenseKey': licenseKey,
        'expiryDate': expiryDate.toUtc().toIso8601String(),
        'maxDevices': maxDevices,
        'usedDevices': usedDevices,
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      safeDebugPrint('❌ Error caching license data: $e');
    }
  }

  /// الحصول على حالة الترخيص في حالة عدم الاتصال
  Future<LicenseStatus> _getOfflineLicenseStatus(
      Box box, String licenseKey) async {
    try {
      final cached = box.get('license_cache');

      if (cached != null && cached is Map<String, dynamic>) {
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
/* Future<LicenseStatus> getCurrentUserLicenseStatus() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return LicenseStatus.invalid(reason: "User not logged in", isOffline: false);
  }

  try {
    final licenseSnapshot = await FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .get();

    if (licenseSnapshot.docs.isEmpty) {
      return LicenseStatus.invalid(reason: "No active license found", isOffline: false);
    }

    final doc = licenseSnapshot.docs.first;
    final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
    final maxDevices = doc.get('maxDevices') as int? ?? 0;
    final devices = doc.get('devices') as List<dynamic>? ?? [];

    if (expiry == null || expiry.isBefore(DateTime.now())) {
      return LicenseStatus.invalid(reason: "License expired", isOffline: false);
    }

    final daysLeft = expiry.difference(DateTime.now()).inDays;

    return LicenseStatus.valid(
      licenseKey: doc.get('licenseKey'),
      expiryDate: expiry,
      maxDevices: maxDevices,
      usedDevices: devices.length,
      daysLeft: daysLeft,
      formattedRemaining: '$daysLeft days',
      isOffline: false,
    );
  } catch (e) {
    // fallback to cache
    final authBox = await Hive.openBox('authbox');
    final cachedData = authBox.get('licenseStatus', defaultValue: {});

    if (cachedData['isValid'] == true) {
      return LicenseStatus.valid(
        licenseKey: cachedData['licenseKey'],
        expiryDate: DateTime.parse(cachedData['expiryDate']),
        maxDevices: cachedData['maxDevices'] ?? 0,
        usedDevices: cachedData['usedDevices'] ?? 0,
        daysLeft: cachedData['daysLeft'] ?? 0,
        formattedRemaining: '${cachedData['daysLeft'] ?? 0} days',
        isOffline: true,
      );
    }

    return LicenseStatus.invalid(
      reason: "Error checking license: $e",
      isOffline: true,
    );
  }
}
 */
 /// إصلاح التراخيص الموجودة (للمسؤولين)
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

  Future<bool> _checkIfAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      safeDebugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _fixLicense(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final data = doc.data();
      if (data.isEmpty) return;

      // إصلاح تاريخ الانتهاء إذا كان غير صحيح
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
