/* // models/license_status.dart
class LicenseStatus {
  final bool isValid;
  final bool isOffline;
  final String? licenseKey;
  final DateTime? expiryDate;
  final int maxDevices;
  final int usedDevices;
  final int daysLeft;
  final String? formattedRemaining;
  final String? reason;
  final bool deviceLimitExceeded;

  LicenseStatus({
    required this.isValid,
    required this.isOffline,
    this.licenseKey,
    this.expiryDate,
    required this.maxDevices,
    required this.usedDevices,
    required this.daysLeft,
    this.formattedRemaining,
    this.reason,
    this.deviceLimitExceeded = false,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
    required String formattedRemaining,
    required bool isOffline,
  }) {
    return LicenseStatus(
      isValid: true,
      licenseKey: licenseKey,
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: usedDevices,
      daysLeft: daysLeft,
      formattedRemaining: formattedRemaining,
      isOffline: isOffline,
    );
  }

  factory LicenseStatus.invalid({
    required String reason,
    required bool isOffline,
  }) {
    return LicenseStatus(
      isValid: false,
      maxDevices: 0,
      usedDevices: 0,
      daysLeft: 0,
      reason: reason,
      isOffline: isOffline,
    );
  }
} */

// models/license_status.dart
class LicenseStatus {
  final bool isValid;
  final bool isOffline;
  final String? licenseKey;
  final DateTime? expiryDate;
  final int maxDevices;
  final int usedDevices;
  final int daysLeft;
  final String? formattedRemaining;
  final String? reason;
  final bool deviceLimitExceeded;
  
  // ✅ الحقول الجديدة لتغيير الجهاز
  final bool deviceChanged;        // هل تم تغيير الجهاز من قبل؟
  final bool canChangeDevice;      // هل يمكن تغيير الجهاز حالياً؟
  final DateTime? deviceChangeDate; // تاريخ تغيير الجهاز
  final String? originalDeviceFingerprint; // بصمة الجهاز الأصلي

  LicenseStatus({
    required this.isValid,
    required this.isOffline,
    this.licenseKey,
    this.expiryDate,
    required this.maxDevices,
    required this.usedDevices,
    required this.daysLeft,
    this.formattedRemaining,
    this.reason,
    this.deviceLimitExceeded = false,
    this.deviceChanged = false,
    this.canChangeDevice = false,
    this.deviceChangeDate,
    this.originalDeviceFingerprint,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
    required String formattedRemaining,
    required bool isOffline,
    bool deviceChanged = false,
    bool canChangeDevice = false,
    DateTime? deviceChangeDate,
    String? originalDeviceFingerprint,
  }) {
    return LicenseStatus(
      isValid: true,
      licenseKey: licenseKey,
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: usedDevices,
      daysLeft: daysLeft,
      formattedRemaining: formattedRemaining,
      isOffline: isOffline,
      deviceChanged: deviceChanged,
      canChangeDevice: canChangeDevice,
      deviceChangeDate: deviceChangeDate,
      originalDeviceFingerprint: originalDeviceFingerprint,
    );
  }

  factory LicenseStatus.invalid({
    required String reason,
    required bool isOffline,
    bool deviceChanged = false,
    bool canChangeDevice = false,
  }) {
    return LicenseStatus(
      isValid: false,
      maxDevices: 0,
      usedDevices: 0,
      daysLeft: 0,
      reason: reason,
      isOffline: isOffline,
      deviceChanged: deviceChanged,
      canChangeDevice: canChangeDevice,
    );
  }

  // ✅ دالة مساعدة للتحقق مما إذا كان يمكن تغيير الجهاز
  bool get canChangeDeviceNow {
    return isValid && !deviceChanged && usedDevices == maxDevices && maxDevices > 0;
  }

  // ✅ دالة مساعدة للحصول على رسالة مناسبة
  String getDeviceChangeMessage() {
    if (deviceChanged) {
      return 'device_already_changed';
    }
    if (canChangeDeviceNow) {
      return 'can_change_device_one_time';
    }
    if (usedDevices < maxDevices) {
      return 'register_new_device_instead';
    }
    return 'purchase_additional_license';
  }

  // ✅ نسخ الموديل مع تعديل بعض الحقول
  LicenseStatus copyWith({
    bool? isValid,
    bool? isOffline,
    String? licenseKey,
    DateTime? expiryDate,
    int? maxDevices,
    int? usedDevices,
    int? daysLeft,
    String? formattedRemaining,
    String? reason,
    bool? deviceLimitExceeded,
    bool? deviceChanged,
    bool? canChangeDevice,
    DateTime? deviceChangeDate,
    String? originalDeviceFingerprint,
  }) {
    return LicenseStatus(
      isValid: isValid ?? this.isValid,
      isOffline: isOffline ?? this.isOffline,
      licenseKey: licenseKey ?? this.licenseKey,
      expiryDate: expiryDate ?? this.expiryDate,
      maxDevices: maxDevices ?? this.maxDevices,
      usedDevices: usedDevices ?? this.usedDevices,
      daysLeft: daysLeft ?? this.daysLeft,
      formattedRemaining: formattedRemaining ?? this.formattedRemaining,
      reason: reason ?? this.reason,
      deviceLimitExceeded: deviceLimitExceeded ?? this.deviceLimitExceeded,
      deviceChanged: deviceChanged ?? this.deviceChanged,
      canChangeDevice: canChangeDevice ?? this.canChangeDevice,
      deviceChangeDate: deviceChangeDate ?? this.deviceChangeDate,
      originalDeviceFingerprint: originalDeviceFingerprint ?? this.originalDeviceFingerprint,
    );
  }

  // ✅ تحويل من Map (من Firestore)
  factory LicenseStatus.fromMap(Map<String, dynamic> map) {
    return LicenseStatus(
      isValid: map['isValid'] ?? false,
      isOffline: map['isOffline'] ?? false,
      licenseKey: map['licenseKey'],
      expiryDate: map['expiryDate'] != null 
          ? (map['expiryDate'] is DateTime 
              ? map['expiryDate'] 
              : DateTime.tryParse(map['expiryDate']))
          : null,
      maxDevices: map['maxDevices'] ?? 0,
      usedDevices: map['usedDevices'] ?? 0,
      daysLeft: map['daysLeft'] ?? 0,
      formattedRemaining: map['formattedRemaining'],
      reason: map['reason'],
      deviceLimitExceeded: map['deviceLimitExceeded'] ?? false,
      deviceChanged: map['deviceChanged'] ?? false,
      canChangeDevice: map['canChangeDevice'] ?? false,
      deviceChangeDate: map['deviceChangeDate'] != null
          ? (map['deviceChangeDate'] is DateTime
              ? map['deviceChangeDate']
              : DateTime.tryParse(map['deviceChangeDate']))
          : null,
      originalDeviceFingerprint: map['originalDeviceFingerprint'],
    );
  }

  // ✅ تحويل إلى Map (للتخزين في Hive)
  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'isOffline': isOffline,
      'licenseKey': licenseKey,
      'expiryDate': expiryDate?.toIso8601String(),
      'maxDevices': maxDevices,
      'usedDevices': usedDevices,
      'daysLeft': daysLeft,
      'formattedRemaining': formattedRemaining,
      'reason': reason,
      'deviceLimitExceeded': deviceLimitExceeded,
      'deviceChanged': deviceChanged,
      'canChangeDevice': canChangeDevice,
      'deviceChangeDate': deviceChangeDate?.toIso8601String(),
      'originalDeviceFingerprint': originalDeviceFingerprint,
    };
  }
}