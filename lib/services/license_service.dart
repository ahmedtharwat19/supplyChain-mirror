import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'device_fingerprint.dart';

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

  // في ملف license_service.dart أضف هذه الدالة
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
      debugPrint('Error getting expiry date: $e');
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
        'expiryDate': Timestamp.fromDate(expiryDate), // تم التصحيح هنا
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

  /// إصلاح التراخيص الموجودة (للاستخدام مرة واحدة)
  /// إصلاح التراخيص الموجودة (للاستخدام مرة واحدة)
  Future<void> fixExistingLicenses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // فقط الأدمن يمكنه إصلاح كل التراخيص
      final isAdmin = await _checkIfAdmin(user.uid);

      if (isAdmin) {
        // الأدمن يمكنه إصلاح كل التراخيص
        final licenses = await _firestore.collection('licenses').get();
        await _fixLicenses(licenses.docs);
      } else {
        // المستخدم العادي يمكنه إصلاح التراخيص الخاصة به فقط
        // استخدم get() بدلاً من where() لتجنب مشاكل الصلاحيات
        try {
          final userLicenses = await _firestore
              .collection('licenses')
              .where('userId', isEqualTo: user.uid)
              .get();
          await _fixLicenses(userLicenses.docs);
        } catch (e) {
          debugPrint(
              'User cannot query licenses, trying individual documents...');
          // حل بديل: حاول الحصول على كل ترخيص على حدة
          await _fixUserLicensesIndividually(user.uid);
        }
      }
    } catch (e) {
      debugPrint('Error fixing licenses: $e');
    }
  }

  /// دالة مساعدة للإصلاح
  /// دالة مساعدة للإصلاح - تقبل أي نوع من الـ snapshots
  Future<void> _fixLicenses(List<dynamic> licenses) async {
    for (var doc in licenses) {
      Map<String, dynamic>? data;

      if (doc is QueryDocumentSnapshot) {
        data = doc.data() as Map<String, dynamic>?;
      } else if (doc is DocumentSnapshot) {
        data = doc.data() as Map<String, dynamic>?;
      }

      if (data == null) continue;

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

        // استخدم reference المناسب حسب نوع الـ snapshot
        DocumentReference ref;
        if (doc is QueryDocumentSnapshot) {
          ref = doc.reference;
        } else if (doc is DocumentSnapshot) {
          ref = doc.reference;
        } else {
          continue;
        }

        await ref.update({'expiryDate': Timestamp.fromDate(date)});
        debugPrint('Fixed license: ${ref.id}');
      }
    }
  }

  /// حل بديل للمستخدم العادي: الحصول على التراخيص بشكل فردي
  Future<void> _fixUserLicensesIndividually(String userId) async {
    try {
      // احصل على قائمة التراخيص من مستند المستخدم
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final licenseKey = userDoc.data()?['licenseKey'];

      if (licenseKey != null) {
        final licenseDoc =
            await _firestore.collection('licenses').doc(licenseKey).get();
        if (licenseDoc.exists) {
          await _fixLicenses([licenseDoc]);
        }
      }
    } catch (e) {
      debugPrint('Error fixing user licenses individually: $e');
    }
  }

  /// دالة التحقق من الأدمن
  Future<bool> _checkIfAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
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

    // معالجة expiryDate بأنواعه المختلفة
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

    final alreadyRegistered =
        devices.any((d) => d['fingerprint'] == fingerprint);

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
  Future<LicenseStatus> checkLicenseStatus(String licenseKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Current user UID: ${user?.uid}');
      debugPrint('Checking license: $licenseKey');
      final box = await Hive.openBox(_deviceBoxName);

      String? currentFingerprint = box.get('fingerprint');
      if (currentFingerprint == null) {
        currentFingerprint = await DeviceFingerprint.getFingerprint();
        await box.put('fingerprint', currentFingerprint);
      }

      try {
        final doc =
            await _firestore.collection('licenses').doc(licenseKey).get();

        if (!doc.exists) {
          debugPrint('License document does not exist');
          return LicenseStatus.invalid(
            reason: "License not found",
            isOffline: false,
          );
        }

        final data = doc.data();
        if (data == null) {
          debugPrint('License document data is null');
          return LicenseStatus.invalid(
            reason: "License data is null",
            isOffline: false,
          );
        }

        // تحقق من مطابقة userId
        final licenseUserId = data['userId'];
        debugPrint('License user ID: $licenseUserId');
        debugPrint('Current user UID: ${user?.uid}');
        debugPrint('User match: ${licenseUserId == user?.uid}');

        // معالجة expiryDate بأنواعه المختلفة
        dynamic expiryDateValue = data['expiryDate'];
        DateTime expiryDate;

        if (expiryDateValue is Timestamp) {
          expiryDate = expiryDateValue.toDate();
        } else if (expiryDateValue is DateTime) {
          expiryDate = expiryDateValue;
        } else if (expiryDateValue is String) {
          expiryDate = DateTime.parse(expiryDateValue);
        } else {
          debugPrint('Unknown expiryDate type: ${expiryDateValue.runtimeType}');
          return LicenseStatus.invalid(
            reason: "Invalid expiry date format",
            isOffline: false,
          );
        }

        debugPrint('Expiry date: $expiryDate');
        debugPrint('Current time: ${DateTime.now()}');

        final maxDevices = data['maxDevices'] ?? 1;
        final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
        final isActive = data['isActive'] ?? false;

        debugPrint('License isActive: $isActive');
        debugPrint('Max devices: $maxDevices');
        debugPrint('Registered devices: ${devices.length}');

        if (!isActive) {
          debugPrint('License is not active');
          return LicenseStatus.invalid(
            reason: "License inactive",
            isOffline: false,
          );
        }

        if (expiryDate.isBefore(DateTime.now())) {
          debugPrint('License expired: $expiryDate');
          return LicenseStatus.invalid(
            reason: "License expired",
            isOffline: false,
          );
        }

        final isRegistered =
            devices.any((d) => d['fingerprint'] == currentFingerprint);
        debugPrint('Device is registered: $isRegistered');

        if (!isRegistered) {
          if (devices.length < maxDevices) {
            await _firestore.collection('licenses').doc(licenseKey).update({
              'devices': FieldValue.arrayUnion([
                {'fingerprint': currentFingerprint}
              ]),
            });
          } else {
            debugPrint('Device limit exceeded');
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

        debugPrint('License is valid. Days left: ${durationLeft.inDays}');

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
        // لا يوجد إنترنت
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

        // لا يوجد كاش محلي
        return LicenseStatus.invalid(
          reason: "No internet and no cached license found",
          isOffline: true,
        );
      }

/*       } catch (e) {
        debugPrint('Online license check failed: $e');
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
      } */
    } catch (e) {
      debugPrint('License check overall error: $e');
      return LicenseStatus.invalid(
        reason: "Error: $e",
        isOffline: true,
      );
    }
  }

  /// دالة مساعدة لتهيئة الوقت المتبقي بشكل نصي
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

  /// هل يوجد طلب ترخيص معلق للمستخدم الحالي؟
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
      debugPrint('License request check failed: $e');
      return false;
    }
  }

  /// الحصول على حالة الترخيص للمستخدم الحالي
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
      debugPrint('Error getting user license status: $e');
      return LicenseStatus.invalid(
        reason: "Error checking license: $e",
        isOffline: true,
      );
    }
  }
}
