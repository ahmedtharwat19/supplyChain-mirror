// services/license_service.dart
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
 */}