// lib/pages/license/device_managment_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

class DeviceManagementPage extends StatefulWidget {
  final String? licenseId;

  const DeviceManagementPage({super.key, this.licenseId});

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  final UserSubscriptionService _service = UserSubscriptionService();
  final LicenseService _licenseService = LicenseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  LicenseStatus? _licenseStatus;
  String _currentDeviceId = '';
  String? _resolvedLicenseId;
  String _licenseKey = '';        // ✅ مفتاح الترخيص لعرض النوع

  StreamSubscription<QuerySnapshot>? _deviceRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _resolveLicenseId();
    _listenForDeviceRequests();
    _verifyFingerprintStability();
    _checkRegisteredDevices(); // ✅ جلب بيانات الأجهزة وتحديث الـ UI
  }

  // ============================================================
  // ✅ الاستماع لطلبات الأجهزة
  // ============================================================
  Future<void> _listenForDeviceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      safeDebugPrint('🔄 Starting to listen for device requests');

      _deviceRequestsSubscription = FirebaseFirestore.instance
          .collection('device_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('processedAt', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        if (!mounted) return;

        for (final doc in querySnapshot.docChanges) {
          final data = doc.doc.data();
          final status = data?['status'];
          final isApproved = data?['approved'] == true;
          final isProcessed = data?['processed'] == true;
          final processedAt = data?['processedAt'] as Timestamp?;

          if (status == 'approved' &&
              isApproved &&
              isProcessed &&
              processedAt != null) {
            safeDebugPrint('🎉 Approved request found: ${doc.doc.id}');
            _checkIfLatestApprovedRequest(querySnapshot.docs);
            break;
          }
        }
      }, onError: (error) {
        safeDebugPrint('❌ Error in device request listener: $error');
      });
    } catch (e) {
      safeDebugPrint('Error listening for device requests: $e');
    }
  }

  // ============================================================
  // ✅ جلب بيانات الأجهزة المسجلة وتحديث الـ UI
  // ============================================================
  Future<void> _checkRegisteredDevices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final licenseKey = userDoc.data()?['licenseKey'] as String?;
      if (licenseKey == null) return;

      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(licenseKey)
          .get();

      if (!licenseDoc.exists) return;

      final rawDevices =
          (licenseDoc.data()?['devices'] as List<dynamic>? ?? [])
              .map((d) => Map<String, dynamic>.from(d as Map))
              .toList();

      final licenseTypeFromDoc =
          licenseDoc.data()?['licenseType'] as String? ??
              AutoLicenseService.getLicenseType(licenseKey);

      safeDebugPrint(
          '📱 Registered devices count: ${rawDevices.length} | type: $licenseTypeFromDoc');

      // ✅ تحديث الـ UI مباشرة
      if (mounted) {
        setState(() {
          _devices = rawDevices;
          _licenseKey = licenseKey;
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error in _checkRegisteredDevices: $e');
    }
  }

  void _checkIfLatestApprovedRequest(List<DocumentSnapshot> allRequests) {
    if (allRequests.isEmpty) return;

    DocumentSnapshot? latestProcessedRequest;
    DateTime? latestProcessedTime;

    for (final doc in allRequests) {
      final data = doc.data() as Map<String, dynamic>?;
      final processedAt = data?['processedAt'] as Timestamp?;

      if (processedAt != null) {
        final processedTime = processedAt.toDate();
        if (latestProcessedTime == null ||
            processedTime.isAfter(latestProcessedTime)) {
          latestProcessedTime = processedTime;
          latestProcessedRequest = doc;
        }
      }
    }

    if (latestProcessedRequest != null) {
      final data = latestProcessedRequest.data() as Map<String, dynamic>;
      if (data['status'] == 'approved' && data['approved'] == true) {
        safeDebugPrint(
            '🎯 Latest request is approved: ${latestProcessedRequest.id}');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('device_request_approved'.tr())),
            );
            _navigateToDashboard();
          }
        });
      }
    }
  }

  Future<void> _navigateToDashboard() async {
    safeDebugPrint('➡️ Navigating to dashboard after approval');
    _deviceRequestsSubscription?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('device_request_approved_redirecting'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 2));

    try {
      safeDebugPrint('🔄 Reloading license status after approval...');
      final status = await _licenseService.getCurrentUserLicenseStatus();
      safeDebugPrint(
          '📊 License status after approval: isValid=${status.isValid}');

      await _loadDevices();
      await _loadCurrentDeviceId();

      if (mounted) {
        setState(() {
          _licenseStatus = status;
          _isLoading = false;
        });

        if (status.isValid) {
          safeDebugPrint('✅ License valid, navigating to dashboard');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) context.go('/dashboard');
        } else {
          safeDebugPrint('⚠️ License still not valid after approval');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error navigating after approval: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/dashboard');
      }
    }
  }

  @override
  void dispose() {
    _deviceRequestsSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // ✅ تحديد الـ licenseId وتحميل البيانات
  // ============================================================
  Future<void> _resolveLicenseId() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (widget.licenseId != null) {
      _resolvedLicenseId = widget.licenseId;
      await _loadData(navigateIfValid: true);
      return;
    }

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final licenseQuery = await FirebaseFirestore.instance
            .collection('licenses')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (licenseQuery.docs.isNotEmpty) {
          _resolvedLicenseId = licenseQuery.docs.first.id;
          await _loadData(navigateIfValid: true);
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
        }
      } catch (e) {
        safeDebugPrint('Error resolving licenseId: $e');
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDevices() async {
    if (_resolvedLicenseId == null) return;

    try {
      safeDebugPrint('🔄 Loading devices for license: $_resolvedLicenseId');

      final devices =
          await _service.getRegisteredDevices(_resolvedLicenseId!);
      final currentFingerprint = await DeviceFingerprint.generate();

      // ✅ جلب نوع الترخيص من Firestore
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(_resolvedLicenseId!)
          .get();
      final licenseKeyFromDoc =
          licenseDoc.data()?['licenseKey'] as String? ?? _resolvedLicenseId!;
      final licenseTypeFromDoc =
          licenseDoc.data()?['licenseType'] as String? ??
              AutoLicenseService.getLicenseType(licenseKeyFromDoc);

      if (!mounted) return;
      setState(() {
        _currentDeviceId = currentFingerprint;
        _devices = devices;
        _licenseKey = licenseKeyFromDoc;
      });

      safeDebugPrint(
          '📊 Loaded ${devices.length} devices | licenseType: $licenseTypeFromDoc');
    } catch (e) {
      safeDebugPrint('❌ Error loading devices: $e');
      if (!mounted) return;
      setState(() => _devices = []);
    }
  }

  Future<void> _loadData({bool navigateIfValid = true}) async {
    if (_resolvedLicenseId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final status = await _licenseService.getCurrentUserLicenseStatus();
      await _loadDevices();
      await _loadCurrentDeviceId();

      if (!mounted) return;
      setState(() {
        _licenseStatus = status;
        _isLoading = false;
      });

      final isCurrentDeviceRegistered =
          _devices.any((d) => d['fingerprint'] == _currentDeviceId);

      safeDebugPrint(
          '🔍 License valid: ${status.isValid} | Device registered: $isCurrentDeviceRegistered');

      if (navigateIfValid && status.isValid && isCurrentDeviceRegistered) {
        safeDebugPrint('✅ All conditions met! Navigating to dashboard...');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) context.go('/dashboard');
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      final currentFingerprint =
          await DeviceFingerprint.getStableFingerprint();
      safeDebugPrint('🔍 Stable device fingerprint: $currentFingerprint');

      if (!mounted) return;
      setState(() => _currentDeviceId = currentFingerprint);
      _checkIfDeviceRegistered(currentFingerprint);
    } catch (e) {
      safeDebugPrint('❌ Error loading current device ID: $e');
      final fallback =
          "fallback-${DateTime.now().millisecondsSinceEpoch}";
      if (!mounted) return;
      setState(() => _currentDeviceId = fallback);
    }
  }

  Future<void> _verifyFingerprintStability() async {
    safeDebugPrint('🔍 Verifying fingerprint stability...');
    final fingerprint1 = await DeviceFingerprint.generate();
    await Future.delayed(const Duration(seconds: 1));
    final fingerprint2 = await DeviceFingerprint.generate();

    if (fingerprint1 == fingerprint2) {
      safeDebugPrint('✅ Fingerprint is stable: $fingerprint1');
    } else {
      safeDebugPrint('❌ Fingerprint unstable: $fingerprint1 vs $fingerprint2');
    }
  }

  void _checkIfDeviceRegistered(String currentFingerprint) {
    final isRegistered =
        _devices.any((d) => d['fingerprint'] == currentFingerprint);

    safeDebugPrint(
        '🔍 Device registered: $isRegistered | fingerprint: $currentFingerprint');

    if (isRegistered && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  // ============================================================
  // ✅ Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('device_management'.tr())),
      body: _isLoading || _licenseStatus == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_licenseStatus == null) {
      return Center(child: Text('loading_failed'.tr()));
    }

    final isCurrentDeviceRegistered =
        _devices.any((d) => d['fingerprint'] == _currentDeviceId);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── حالة الجهاز الحالي ──
          Card(
            color: isCurrentDeviceRegistered
                ? Colors.green[50]
                : Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'current_device_status'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isCurrentDeviceRegistered
                              ? Colors.green
                              : Colors.orange,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'device_fingerprint'.tr(),
                    _currentDeviceId.length > 16
                        ? '${_currentDeviceId.substring(0, 16)}...'
                        : _currentDeviceId,
                  ),
                  _buildInfoRow(
                    'registration_status'.tr(),
                    isCurrentDeviceRegistered
                        ? 'registered'.tr()
                        : 'not_registered'.tr(),
                  ),
                  if (!isCurrentDeviceRegistered) ...[
                    const SizedBox(height: 8),
                    Text(
                      'register_device_to_access'.tr(),
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── معلومات الترخيص مع نوعه ──
          Card(
            color: Colors.grey[400],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'license_info'.tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // ✅ badge نوع الترخيص
                      if (_licenseKey.isNotEmpty)
                        _buildLicenseTypeBadge(_licenseKey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'devices_used'.tr(),
                    '${_licenseStatus!.usedDevices}/${_licenseStatus!.maxDevices}',
                  ),
                  _buildInfoRow(
                    'days_remaining'.tr(),
                    '${_licenseStatus!.daysLeft}',
                  ),
                  if (_licenseStatus!.formattedRemaining != null)
                    _buildInfoRow(
                      'time_remaining'.tr(),
                      _licenseStatus!.formattedRemaining!,
                    ),
                  // ✅ عرض مفتاح الترخيص المختصر
                  if (_licenseKey.isNotEmpty)
                    _buildInfoRow(
                      'license_key'.tr(),
                      _licenseKey.length > 20
                          ? '${_licenseKey.substring(0, 20)}...'
                          : _licenseKey,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── تحذير تجاوز حد الأجهزة ──
          if (_licenseStatus!.deviceLimitExceeded)
            Card(
              color: Colors.red.withAlpha(75),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'device_limit_exceeded_warning'.tr(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── تسجيل الجهاز (لو مفيش slots كافية) ──
          if (!isCurrentDeviceRegistered &&
              _licenseStatus!.usedDevices < _licenseStatus!.maxDevices)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.device_hub,
                        size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'register_this_device'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'register_device_description'.tr(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _registerCurrentDevice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'register_now'.tr(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── قائمة الأجهزة المسجلة ──
          Text('registered_devices'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Expanded(
            child: _devices.isEmpty
                ? Center(child: Text('no_devices_registered'.tr()))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isCurrent =
                          device['fingerprint'] == _currentDeviceId;

                      return Card(
                        color: isCurrent ? Colors.green[50] : null,
                        child: ListTile(
                          leading: Icon(
                            isCurrent
                                ? Icons.check_circle
                                : Icons.device_hub,
                            color:
                                isCurrent ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            device['deviceName'] ??
                                device['displayName'] ??
                                'unknown_device'.tr(),
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle:
                              _buildDeviceInfoSubtitle(device, isCurrent),
                          trailing: !isCurrent
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeviceDeleteDialog(device),
                                )
                              : const Icon(Icons.check,
                                  color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // ── أزرار رئيسية ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _licenseStatus!.usedDevices <
                          _licenseStatus!.maxDevices
                      ? _registerCurrentDevice
                      : null,
                  child: Text('register_current_device'.tr()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _requestNewDeviceSlot,
                  child: Text('request_new_slot'.tr()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── زر تغيير الجهاز ──
          FutureBuilder<bool>(
            future: _resolvedLicenseId != null
                ? _service.canChangeDevice(_resolvedLicenseId!)
                : Future.value(false),
            builder: (context, snapshot) {
              final canChange = snapshot.data ?? false;

              if (!canChange && _resolvedLicenseId != null) {
                return FutureBuilder(
                  future: _service
                      .getDeviceChangeStatus(_resolvedLicenseId!),
                  builder: (context, statusSnapshot) {
                    final status = statusSnapshot.data;
                    if (status?['deviceChanged'] == true) {
                      return Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange),
                              const SizedBox(height: 8),
                              Text(
                                'device_already_changed'.tr(),
                                style: const TextStyle(
                                    color: Colors.orange),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'purchase_additional_license'.tr(),
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              }

              if (canChange) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDeviceChangeDialog,
                    icon: const Icon(Icons.device_hub),
                    label: Text('change_device_one_time'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ Badge نوع الترخيص
  // ============================================================
  Widget _buildLicenseTypeBadge(String licenseKey) {
    final isTrial = AutoLicenseService.isTrialLicense(licenseKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isTrial ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTrial ? Colors.orange : Colors.green,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrial ? Icons.science_outlined : Icons.verified,
            size: 14,
            color: isTrial ? Colors.orange.shade800 : Colors.green.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            isTrial ? 'trial'.tr() : 'licensed'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color:
                  isTrial ? Colors.orange.shade800 : Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ Subtitle بيانات الجهاز الكاملة
  // ============================================================
  Widget _buildDeviceInfoSubtitle(
      Map<String, dynamic> device, bool isCurrent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ brand + model
        if (device['brand'] != null || device['model'] != null)
          Text(
              '${device['brand'] ?? ''} ${device['model'] ?? ''}'.trim(),
              style: const TextStyle(fontSize: 12)),
        // ✅ نظام التشغيل
        if (device['androidVersion'] != null)
          Text('Android ${device['androidVersion']}',
              style: const TextStyle(fontSize: 12)),
        if (device['os'] != null && device['androidVersion'] == null)
          Text('${'os'.tr()}: ${device['os']}',
              style: const TextStyle(fontSize: 12)),
        // ✅ platform fallback
        if (device['platform'] != null &&
            device['brand'] == null &&
            device['model'] == null)
          Text('${device['platform']}',
              style: const TextStyle(fontSize: 12)),
        // ✅ تاريخ التسجيل
        if (device['registeredAt'] != null)
          Text(
              '${'registered'.tr()}: ${_formatDate(device['registeredAt'])}',
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        // ✅ علامة الجهاز الحالي
        if (isCurrent)
          Text(
            'current_device'.tr(),
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
      ],
    );
  }

  // ============================================================
  // ✅ Widget مساعد: صف معلومات
  // ============================================================
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(Map<String, dynamic> device) {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device['deviceName'] ??
                  device['displayName'] ??
                  'unknown_device'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (device['brand'] != null || device['model'] != null)
              Text(
                  '${device['brand'] ?? ''} ${device['model'] ?? ''}'
                      .trim()),
            if (device['androidVersion'] != null)
              Text('Android ${device['androidVersion']}'),
            if (device['platform'] != null)
              Text('${'platform'.tr()}: ${device['platform']}'),
            if (device['os'] != null)
              Text('${'os'.tr()}: ${device['os']}'),
            if (device['registeredAt'] != null)
              Text(
                  '${'registered'.tr()}: ${_formatDate(device['registeredAt'])}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
      } else if (date is String) {
        return date.length > 16 ? date.substring(0, 16) : date;
      }
      return date.toString();
    } catch (e) {
      return 'unknown_date'.tr();
    }
  }

  // ============================================================
  // ✅ تسجيل الجهاز
  // ============================================================
  Future<void> _registerCurrentDevice() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      if (_currentDeviceId.isEmpty) await _loadCurrentDeviceId();

      safeDebugPrint(
          '🔄 Registering device: $_currentDeviceId');

      final success =
          await _service.registerDeviceFingerprint(_resolvedLicenseId!);

      if (success) {
        safeDebugPrint('✅ Device registered successfully');
        await Future.delayed(const Duration(seconds: 3));
        await _loadData(navigateIfValid: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('device_registered_successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        safeDebugPrint('❌ Device registration failed');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('failed_to_register_device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error in device registration: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr())),
        );
      }
    }
  }

  // ============================================================
  // ✅ إلغاء تسجيل جهاز
  // ============================================================
  Future<void> _unregisterDevice(String fingerprint) async {
    if (_resolvedLicenseId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('license_not_found'.tr())),
        );
      }
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final deviceToRemove = _devices.firstWhere(
        (d) => d['fingerprint'] == fingerprint,
        orElse: () => {},
      );

      if (deviceToRemove.isEmpty) {
        throw Exception('Device not found in local list');
      }

      await FirebaseFirestore.instance
          .collection('licenses')
          .doc(_resolvedLicenseId!)
          .update({
        'devices': FieldValue.arrayRemove([deviceToRemove]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'deviceIds': FieldValue.arrayRemove([fingerprint]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      final newFingerprint = await DeviceFingerprint.generate();
      if (!mounted) return;
      setState(() => _currentDeviceId = newFingerprint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('device_unregistered_successfully'.tr())),
        );
        await _loadData(navigateIfValid: false);
        await _attemptAutoRegister();
      }
    } catch (e) {
      safeDebugPrint('❌ Error unregistering device: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_unregister_device'.tr())),
        );
      }
    }
  }

  Future<void> _attemptAutoRegister() async {
    try {
      if (_resolvedLicenseId != null &&
          _licenseStatus != null &&
          _licenseStatus!.usedDevices < _licenseStatus!.maxDevices) {
        final success =
            await _service.registerDeviceFingerprint(_resolvedLicenseId!);

        if (success) {
          safeDebugPrint('✅ Auto-registration successful');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('device_auto_registered'.tr())),
            );
            await _loadData(navigateIfValid: true);
          }
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error in auto-registration: $e');
    }
  }

  // ============================================================
  // ✅ طلب slot جديد من الأدمن
  // ============================================================
  Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final currentStatus =
        await _licenseService.getCurrentUserLicenseStatus();
    if (currentStatus.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('license_already_valid'.tr())),
        );
        _loadData(navigateIfValid: true);
      }
      return;
    }

    final licenseId = _resolvedLicenseId!;
    final requestId =
        'request_${licenseId}_${DateTime.now().millisecondsSinceEpoch}';

    final existingRequests = await FirebaseFirestore.instance
        .collection('device_requests')
        .where('licenseId', isEqualTo: licenseId)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequests.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('pending_request_exists'.tr())),
      );
      return;
    }

    if (!mounted) return;

    String? userReason = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempReason = '';
        return AlertDialog(
          title: Text('request_new_device_slot'.tr()),
          content: TextField(
            decoration: InputDecoration(
              hintText: 'reason_for_request'.tr(),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) => tempReason = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempReason),
              child: Text('submit'.tr()),
            ),
          ],
        );
      },
    );

    if (userReason == null || userReason.trim().isEmpty) return;

    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      await FirebaseFirestore.instance
          .collection('device_requests')
          .doc(requestId)
          .set({
        'userId': user.uid,
        'licenseId': licenseId,
        'reason': userReason,
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'processed': false,
        'status': 'pending',
        'userEmail': user.email,
        'userDisplayName': user.displayName,
        'fingerprint': currentFingerprint,
        'deviceName': deviceInfo['displayName'] ?? 'unknown_device'.tr(),
        'platform': deviceInfo['platform'] ?? '',
        'brand': deviceInfo['brand'] ?? '',
        'model': deviceInfo['model'] ?? '',
        'androidVersion': deviceInfo['androidVersion'] ?? '',
        'os': deviceInfo['os'] ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );
        _deviceRequestsSubscription?.cancel();
        _listenForDeviceRequests();
      }
    } catch (e) {
      safeDebugPrint('Error creating device request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_create_request'.tr())),
        );
      }
    }
  }

  // ============================================================
  // ✅ تغيير الجهاز (مرة واحدة فقط)
  // ============================================================
  Future<void> _showDeviceChangeDialog() async {
    if (_resolvedLicenseId == null) return;

    final canChange = await _service.canChangeDevice(_resolvedLicenseId!);
    if (!mounted) return;

    if (!canChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('cannot_change_device'.tr())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('change_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ ${'warning_one_time_change'.tr()}',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('change_device_description'.tr()),
            const SizedBox(height: 16),
            Text('• ${'current_device_will_be_removed'.tr()}'),
            Text('• ${'new_device_will_be_registered'.tr()}'),
            Text('• ${'cannot_change_back'.tr()}'),
            Text('• ${'purchase_new_license_if_need_more'.tr()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
            child: Text('confirm_change'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      try {
        safeDebugPrint('🔄 Starting device change...');
        final success =
            await _service.changeDevice(_resolvedLicenseId!);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('device_changed_successfully'.tr())),
          );

          await Future.delayed(const Duration(seconds: 2));
          await _loadDevices();
          await _loadCurrentDeviceId();

          final status =
              await _licenseService.getCurrentUserLicenseStatus();
          final isRegistered = _devices
              .any((d) => d['fingerprint'] == _currentDeviceId);

          if (mounted) {
            setState(() {
              _licenseStatus = status;
              _isLoading = false;
            });

            if (status.isValid && isRegistered) {
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) context.go('/dashboard');
            }
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('device_change_failed'.tr())),
          );
        }
      } catch (e) {
        safeDebugPrint('❌ Error changing device: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error_changing_device'.tr())),
          );
        }
      }
    }
  }

  // ============================================================
  // ✅ Dialog حذف الجهاز
  // ============================================================
  Future<void> _showDeviceDeleteDialog(Map<String, dynamic> device) async {
    final fingerprint = device['fingerprint'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unregister_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('confirm_unregister_device'.tr()),
            const SizedBox(height: 16),
            _buildDeviceInfoCard(device),
            const SizedBox(height: 8),
            Text(
              'auto_register_warning'.tr(),
              style: const TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('unregister'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _unregisterDevice(fingerprint);
      } catch (e) {
        safeDebugPrint('❌ Error in device deletion dialog: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error_occurred'.tr())),
          );
        }
      }
    }
  }
}