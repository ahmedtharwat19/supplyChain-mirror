
/// موديل الحالة
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
}
