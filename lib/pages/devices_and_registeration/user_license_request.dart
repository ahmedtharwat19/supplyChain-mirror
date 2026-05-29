/* import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
//import '../../services/license_service.dart';
import 'package:collection/collection.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  //final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  //final _secureStorage = const FlutterSecureStorage();

  StreamSubscription? _licenseStatusSubscription;
  StreamSubscription? _requestStatusSubscription;
  StreamSubscription? _licenseListenerSubscription;
  bool _isPending = false;
  int _selectedDuration = 1;
  int _selectedDevices = 1;
  bool _isSubmitting = false;
  int _currentDevicesCount = 0;
  String _currentDeviceId = '';

  /// ✅ غيرت من final إلى متغير عادي ليسمح بالتحديث
  bool _hasSubmittedRequest = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
    _setupLicenseListener();
    _setupRequestStatusListener();
    _setupLicenseStatusListener();
    _setupMainLicenseListener();
  }

  void _setupMainLicenseListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // ألغِ جميع الاشتراكات السابقة
    _licenseStatusSubscription?.cancel();
    _requestStatusSubscription?.cancel();
    _licenseListenerSubscription?.cancel();

    // اشترك في التغييرات على كل من التراخيص والطلبات
    _licenseStatusSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _checkAndRedirect();
    });

    _requestStatusSubscription = _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _checkAndRedirect();
    });
  }

Future<void> _checkAndRedirect() async {
  if (!mounted) return;
  await Future.delayed(const Duration(seconds: 2));
  final user = _auth.currentUser;
  if (user == null) return;

  final licenseSnapshot = await _firestore
      .collection('licenses')
      .where('userId', isEqualTo: user.uid)
      .where('isActive', isEqualTo: true)
      .get();

  final validDoc = licenseSnapshot.docs.firstWhereOrNull((doc) {
    final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
    return expiry != null && expiry.isAfter(DateTime.now());
  });

  if (validDoc != null) {
    // ✅ احفظ licenseKey في SecureStorage قبل الانتقال
    final secureStorage = const FlutterSecureStorage();
    await secureStorage.write(key: 'licenseKey', value: validDoc.id);
    
    safeDebugPrint('Redirecting to dashboard - active license found');
    Future.microtask(() {
      if (mounted) context.go('/dashboard');
    });
    return;
  }

    // تحقق من وجود طلب معتمد
    final requestSnapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .get();

    if (requestSnapshot.docs.isNotEmpty) {
      safeDebugPrint('Redirecting to dashboard - approved request found');
      Future.microtask(() {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  @override
  void dispose() {
    _licenseStatusSubscription?.cancel();
    _requestStatusSubscription?.cancel();
    _licenseListenerSubscription?.cancel();
    super.dispose();
  }

  /// تراقب الترخيص النشط وتنقل المستخدم بناءً على الحالة
  void _setupLicenseStatusListener() {
    final user = _auth.currentUser;
    if (user == null) return;
    _licenseStatusSubscription?.cancel();
    _licenseStatusSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final licenseDoc =
          snapshot.docs.where((doc) => doc.exists).firstWhereOrNull((doc) {
        final isActive = doc.get('isActive') as bool? ?? false;
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        final now = DateTime.now().toUtc();
        final isExpired = expiry != null && expiry.isBefore(now);
        return isActive && !isExpired;
      });

      if (licenseDoc == null) {
        safeDebugPrint('user license page : No License found ...');
        context.go('/license/request');
        return;
      }

      final isActive = licenseDoc.get('isActive') as bool? ?? false;
      final expiryDate = (licenseDoc.get('expiryDate') as Timestamp?)?.toDate();
      final nowUtc = DateTime.now().toUtc();
      final isExpired = expiryDate != null && expiryDate.isBefore(nowUtc);

      safeDebugPrint('expiryDate: $expiryDate');
      safeDebugPrint('nowUtc: $nowUtc');
      safeDebugPrint('isExpired: $isExpired');
      safeDebugPrint('isActive: $isActive');

      if (!isActive || isExpired) {
        safeDebugPrint('user license page : License is canceled or expired...');
        context.go('/license/request');
      }

     
        safeDebugPrint('Active license found, redirecting to dashboard');
        Future.microtask(() {
          if (mounted) context.go('/dashboard');
        });
      
    });
  }

  /// تراقب حالة طلبات الترخيص النشطة (pending أو approved)
  void _setupRequestStatusListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _requestStatusSubscription = _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'approved'])
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final status = doc.get('status');

            switch (status) {
              case 'approved':
                // أوقف الاشتراك بعد الموافقة
                _requestStatusSubscription?.cancel();
                _requestStatusSubscription = null;

                Future.microtask(() {
                  if (mounted) context.go('/dashboard');
                });
                break;

              case 'pending':
                setState(() {
                  _isPending = true;
                });
                break;
            }
          }
        });
  }

  /// تراقب الترخيص النشط بعد إرسال الطلب للتحويل التلقائي
  void _setupLicenseListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _licenseListenerSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.docs.isNotEmpty && _hasSubmittedRequest) {
        Future.microtask(() {
          if (mounted) context.go('/dashboard');
        });
      }
    });
  }

  Future<void> _loadDeviceData() async {
    await _loadCurrentDeviceCount();
    await _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final licenseQuery = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _currentDevicesCount = 0;
          if (licenseQuery.docs.isNotEmpty) {
            final doc = licenseQuery.docs.first.data();
            final deviceIds = doc['deviceIds'];

            if (deviceIds is List) {
              _currentDevicesCount = deviceIds.length;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('load_device_count_error'.tr())),
        );
      }
    }
  }



  Future<void> _loadCurrentDeviceId() async {
    try {
      String deviceId = '';
      String deviceDetails = '';

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceId = "${webInfo.vendor ?? 'web'}-${webInfo.userAgent.hashCode}";
        deviceDetails = webInfo.browserName.name;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        
        // 1. جلب المعرف الأساسي لحمايته من الـ Null
        String rawId = androidInfo.id;
        if (rawId.isEmpty || rawId == 'null') {
          rawId = androidInfo.hardware.hashCode.toString();
        }
        
        // 2. جلب نوع وموديل الهاتف (مثل: Oppo - CPH2125)
        // واستبدال الفراغات بشرطة منعاً للمشاكل البرمجية
        final String manufacturer = (androidInfo.manufacturer).toUpperCase().trim();
        final String model = (androidInfo.model).toUpperCase().trim();
        
        // 3. دمج البيانات كلها في معرف واحد احترافي
        deviceId = rawId;
        deviceDetails = "$manufacturer - $model";
        
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
        deviceDetails = "APPLE - ${iosInfo.model}";
      } else {
        deviceId = 'fallback-id-platform';
        deviceDetails = 'UNKNOWN';
      }

      if (mounted) {
        setState(() {
          // يمكنك دمجهم معاً في متغير المعرف لتخزينه بالسيرفر هكذا:
          _currentDeviceId = "$deviceDetails ($deviceId)";
        });
        
        // طباعة تشخيصية ممتازة في الـ Terminal لرؤية النتيجة
        safeDebugPrint('📱 Secure Device Info Loaded: $_currentDeviceId');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading device info: $e');
      if (mounted) {
        setState(() {
          _currentDeviceId = 'FALLBACK-${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_request.title'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDurationSelector(),
                const SizedBox(height: 14),
                _buildDeviceSelector(),
                const SizedBox(height: 14),
                _buildDeviceWarning(),
                const SizedBox(height: 14),
                _buildRequestInfoCard(),
                const SizedBox(height: 14),
                if (_isPending)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty,
                              color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'license_request_pending'.tr(),
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'subscription_duration'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedDuration,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [1, 3, 6, 12].map((months) {
                return DropdownMenuItem(
                  value: months,
                  child: Text('$months ${'months'.tr()}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDuration = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'number_of_devices'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedDevices,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [1, 2, 3, 5].map((deviceCount) {
                return DropdownMenuItem(
                  value: deviceCount,
                  child: Text('$deviceCount ${'devices'.tr()}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDevices = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceWarning() {
    if (_currentDevicesCount >= _selectedDevices) {
      return Card(
        color: Colors.orange.withAlpha(75),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'device_limit_warning'
                      .tr(args: [_selectedDevices.toString()]),
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildRequestInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'request_summary'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                'duration'.tr(), '$_selectedDuration ${'months'.tr()}'),
            _buildInfoRow('devices_allowed'.tr(), '$_selectedDevices'),
            _buildInfoRow('current_devices'.tr(), '$_currentDevicesCount'),
            _buildInfoRow('device_id'.tr(), _currentDeviceId),
            if (_isPending)
              _buildInfoRow('request_status'.tr(), 'pending'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isPending) ? null : _submitRequest,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Text('submit_request'.tr()),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_currentDeviceId.isEmpty) {
      _showErrorSnackBar('device_id_not_loaded'.tr());
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('user_not_authenticated'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      // 1. تحقق من وجود طلب سابق بحالة pending أو approved
      final existingRequestSnapshot = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'approved']).get();

      bool hasActiveRequest = false;

      for (var doc in existingRequestSnapshot.docs) {
        final status = doc.get('status');

        if (status == 'pending') {
          hasActiveRequest = true;
          break;
        }

        if (status == 'approved') {
          final licenseSnapshot = await _firestore
              .collection('licenses')
              .where('userId', isEqualTo: user.uid)
              .where('isActive', isEqualTo: true)
              .get();

          final now = DateTime.now().toUtc();
          bool hasValidLicense = licenseSnapshot.docs.any((licenseDoc) {
            final expiryTimestamp = licenseDoc.get('expiryDate') as Timestamp?;
            if (expiryTimestamp == null) return false;
            final expiryDate = expiryTimestamp.toDate();
            return expiryDate.isAfter(now);
          });

          if (hasValidLicense) {
            hasActiveRequest = true;
            break;
          }
        }
      }

      if (hasActiveRequest) {
        _showErrorSnackBar('existing_request_found'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      // إنشاء رقم طلب مفهوم
      final String requestNumber = await _generateRequestNumber();

      // إنشاء الطلب الجديد
      final batch = _firestore.batch();
      final newRequestRef =
          _firestore.collection('license_requests').doc(requestNumber);

      batch.set(newRequestRef, {
        'requestId': requestNumber, // إضافة حقل requestId للتوثيق
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'deviceIds': [_currentDeviceId],
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email,
      });

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _hasSubmittedRequest = true;
        _isSubmitting = false;
        _isPending = true;
      });

      _showSuccessMessage(requestNumber);
      await _loadCurrentDeviceCount();
    } catch (e) {
      _showErrorSnackBar('request_failed'.tr(args: [e.toString()]));
      setState(() => _isSubmitting = false);
    }
  }

  Future<String> _generateRequestNumber() async {
    try {
      final now = DateTime.now();
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // الحصول على آخر رقم تسلسلي لهذا اليوم
      final todayRequests = await _firestore
          .collection('license_requests')
          .where('requestId', isGreaterThanOrEqualTo: 'REQ-$datePart-')
          .where('requestId', isLessThan: 'REQ-$datePart-9999')
          .orderBy('requestId', descending: true)
          .limit(1)
          .get();

      int sequenceNumber = 1;

      if (todayRequests.docs.isNotEmpty) {
        final lastRequestId = todayRequests.docs.first.id;
        final parts = lastRequestId.split('-');
        if (parts.length == 3) {
          final lastSequence = int.tryParse(parts[2]) ?? 0;
          sequenceNumber = lastSequence + 1;
        }
      }

      // التأكد من أن الرقم التسلسلي لا يتجاوز 4 أرقام
      sequenceNumber = sequenceNumber.clamp(1, 9999);

      return 'REQ-$datePart-${sequenceNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      safeDebugPrint('Error generating request number: $e');
      // Fallback: استخدام UUID إذا فشل التوليد
      return 'REQ-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${_uuid.v4().substring(0, 4)}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }



  void _showSuccessMessage(String requestNumber) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('request_successful'.tr()),
            const SizedBox(height: 4),
            Text(
              '${'request_number'.tr()}: $requestNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }
}
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StreamSubscription? _licenseStatusSubscription;
  StreamSubscription? _requestStatusSubscription;
  StreamSubscription? _licenseListenerSubscription;
  bool _isPending = false;
  int _selectedDuration = 1;
  int _selectedDevices = 1;
  bool _isSubmitting = false;
  int _currentDevicesCount = 0;
  String _currentDeviceId = '';
  bool _hasSubmittedRequest = false;
  bool _hasRedirected = false;

  // ✅ متغيرات لعرض خيار استبدال الجهاز
  bool _isLoading = true;
  bool _showDeviceReplacement = false;
  String? _existingLicenseKey;
  DateTime? _existingLicenseExpiry;
  int _existingMaxDevices = 1;

  static const String _keyLicenseKey = 'license_key';
  static const String _keyLicenseExpiry = 'license_expiry';

  @override
  void initState() {
    super.initState();
    safeDebugPrint('🔵 [UserLicenseRequestPage] initState started');
    _checkForExistingLicense();
  }

// user_license_request.dart - تعديل دالة _checkForExistingLicense

  Future<void> _checkForExistingLicense() async {
    setState(() => _isLoading = true);

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final licensesSnapshot = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      safeDebugPrint(
          '🔍 Found ${licensesSnapshot.docs.length} active licenses');

      for (final doc in licensesSnapshot.docs) {
        final data = doc.data();
        final expiryTimestamp = data['expiryDate'] as Timestamp?;

        if (expiryTimestamp == null) {
          safeDebugPrint('⚠️ License ${doc.id} has no expiry date');
          continue;
        }

        final expiry = expiryTimestamp.toDate();
        safeDebugPrint('📅 License ${doc.id} expires: $expiry');

        if (expiry.isAfter(DateTime.now())) {
          final licenseKey = doc.id;
          final maxDevices = data['maxDevices'] as int? ?? 1;

          safeDebugPrint('✅ Valid license found: $licenseKey');
          safeDebugPrint('📱 Max devices: $maxDevices');
          safeDebugPrint('📅 Expiry date: $expiry');

          // ✅ التحقق من الجهاز الحالي
          final subscriptionService = UserSubscriptionService();
          final isRegistered =
              await subscriptionService.isCurrentDeviceRegistered(licenseKey);

          safeDebugPrint('📱 Is current device registered: $isRegistered');

          if (!isRegistered) {
            // ✅ يوجد ترخيص صالح ولكن الجهاز غير مسجل
            final canChange =
                await subscriptionService.canChangeDevice(licenseKey);

            safeDebugPrint('📱 Can change device: $canChange');

            if (canChange) {
              // ✅ يمكن استبدال الجهاز
              setState(() {
                _existingLicenseKey = licenseKey;
                _existingLicenseExpiry = expiry;
                _existingMaxDevices = maxDevices;
                _showDeviceReplacement = true;
                _isLoading = false;
              });
              safeDebugPrint('✅ Showing device replacement UI');
              return;
            } else {
              // ❌ لا يمكن استبدال الجهاز (تم الاستبدال سابقاً)
              setState(() {
                _showDeviceReplacement = false;
                _isLoading = false;
              });
              _showCannotReplaceDialog();
              return;
            }
          } else {
            // ✅ الجهاز مسجل - اذهب إلى Dashboard
            safeDebugPrint('✅ Device registered, redirecting to dashboard');
            await _saveLicenseToStorage(licenseKey, expiry);
            _navigateToDashboard();
            return;
          }
        }
      }

      // ❌ لا يوجد ترخيص صالح - اعرض نموذج الطلب العادي
      safeDebugPrint('❌ No valid license found, showing request form');
      setState(() => _isLoading = false);
      _loadDeviceData();
      _setupListeners();
    } catch (e) {
      safeDebugPrint('❌ Error checking license: $e');
      setState(() => _isLoading = false);
      _loadDeviceData();
    }
  }

  /// ✅ التحقق من وجود ترخيص صالح لجهاز آخر
/*   Future<void> _checkForExistingLicense() async {
    setState(() => _isLoading = true);
    
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final licensesSnapshot = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in licensesSnapshot.docs) {
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          final licenseKey = doc.id;
          final maxDevices = doc.get('maxDevices') as int? ?? 1;
          
          // ✅ التحقق من الجهاز الحالي
          final subscriptionService = UserSubscriptionService();
          final isRegistered = await subscriptionService.isCurrentDeviceRegistered(licenseKey);
          
          if (!isRegistered) {
            // ✅ يوجد ترخيص صالح ولكن الجهاز غير مسجل
            final canChange = await subscriptionService.canChangeDevice(licenseKey);
            
            safeDebugPrint('📱 Valid license found but device not registered!');
            safeDebugPrint('   License: $licenseKey');
            safeDebugPrint('   Can change device: $canChange');
            
            if (canChange) {
              // ✅ يمكن استبدال الجهاز
              setState(() {
                _existingLicenseKey = licenseKey;
                _existingLicenseExpiry = expiry;
                _existingMaxDevices = maxDevices;
                _showDeviceReplacement = true;
                _isLoading = false;
              });
              return;
            } else {
              // ❌ لا يمكن استبدال الجهاز (تم الاستبدال سابقاً)
              setState(() {
                _showDeviceReplacement = false;
                _isLoading = false;
              });
              _showCannotReplaceDialog();
              return;
            }
          } else {
            // ✅ الجهاز مسجل - اذهب إلى Dashboard
            safeDebugPrint('✅ Device registered, redirecting to dashboard');
            await _saveLicenseToStorage(licenseKey, expiry);
            _navigateToDashboard();
            return;
          }
        }
      }
      
      // ❌ لا يوجد ترخيص صالح - اعرض نموذج الطلب العادي
      setState(() => _isLoading = false);
      _loadDeviceData();
      _setupLicenseListener();
      _setupRequestStatusListener();
      _setupLicenseStatusListener();
      _setupMainLicenseListener();
      
    } catch (e) {
      safeDebugPrint('❌ Error checking license: $e');
      setState(() => _isLoading = false);
      _loadDeviceData();
    }
  }
 */
  /// ✅ عرض حوار "لا يمكن استبدال الجهاز"
  void _showCannotReplaceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('cannot_replace_device'.tr()),
        content: Text('device_replacement_already_used'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDeviceData();
              _setupListeners();
            },
            child: Text('request_new_license'.tr()),
          ),
        ],
      ),
    );
  }

  void _setupListeners() {
    _setupLicenseListener();
    _setupRequestStatusListener();
    _setupLicenseStatusListener();
    _setupMainLicenseListener();
  }

// user_license_request.dart - تعديل دالة _handleReplaceDevice

  Future<void> _handleReplaceDevice() async {
    setState(() => _isSubmitting = true);

    safeDebugPrint('🔄 Starting device replacement process...');
    safeDebugPrint('📱 License key: $_existingLicenseKey');

    try {
      if (_existingLicenseKey == null) {
        safeDebugPrint('❌ No license key found');
        throw Exception('No license key found');
      }

      final subscriptionService = UserSubscriptionService();

      // التحقق من صلاحية التغيير أولاً
      final canChange =
          await subscriptionService.canChangeDevice(_existingLicenseKey!);
      safeDebugPrint('📱 Can change device: $canChange');

      if (!canChange) {
        safeDebugPrint('❌ Cannot change device - already changed or invalid');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cannot change device. You have already used your one-time device change.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // تنفيذ تغيير الجهاز
      final success =
          await subscriptionService.changeDevice(_existingLicenseKey!);
      safeDebugPrint('📱 Device change result: $success');

      if (!mounted) return;

      if (success) {
        safeDebugPrint('✅ Device replaced successfully!');

        // حفظ الترخيص في التخزين المحلي
        if (_existingLicenseExpiry != null) {
          await _saveLicenseToStorage(
              _existingLicenseKey!, _existingLicenseExpiry!);
        }
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device changed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // التوجيه إلى Dashboard
        _navigateToDashboard();
      } else {
        safeDebugPrint('❌ Device replacement failed - service returned false');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Device change failed. Please try again or contact support.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      safeDebugPrint('❌ Error replacing device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// ✅ استبدال الجهاز
/*   Future<void> _handleReplaceDevice() async {
    setState(() => _isSubmitting = true);

    try {
      if (_existingLicenseKey == null) {
        throw Exception('No license key found');
      }

      final subscriptionService = UserSubscriptionService();
      final success =
          await subscriptionService.changeDevice(_existingLicenseKey!);

      if (!mounted) return;

      if (success) {
        safeDebugPrint('✅ Device replaced successfully!');

        // حفظ الترخيص في التخزين المحلي
        if (_existingLicenseExpiry != null) {
          await _saveLicenseToStorage(
              _existingLicenseKey!, _existingLicenseExpiry!);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('device_changed_successfully'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // التوجيه إلى Dashboard
        _navigateToDashboard();
      } else {
        throw Exception('Device replacement failed');
      }
    } catch (e) {
      safeDebugPrint('❌ Error replacing device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('device_change_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
 */
  /// ✅ عرض حوار تأكيد استبدال الجهاز
  void _showReplaceConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('change_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ ${'warning_one_time_change'.tr()}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('change_device_description'.tr()),
            const SizedBox(height: 12),
            Text('• ${'current_device_will_be_removed'.tr()}'),
            Text('• ${'new_device_will_be_registered'.tr()}'),
            Text('• ${'cannot_change_back'.tr()}'),
            const SizedBox(height: 8),
            Text(
              'max_devices_allowed'.tr(args: [_existingMaxDevices.toString()]),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx, true);
              _handleReplaceDevice();
            },
            child: Text('confirm_change'.tr()),
          ),
        ],
      ),
    );
  }

  /// ✅ حفظ الترخيص في SecureStorage
  Future<void> _saveLicenseToStorage(String licenseKey, DateTime expiry) async {
    await _secureStorage.write(key: _keyLicenseKey, value: licenseKey);
    await _secureStorage.write(
        key: _keyLicenseExpiry, value: expiry.toIso8601String());
    safeDebugPrint('✅ License saved to storage: $licenseKey');
  }

  void _navigateToDashboard() {
    if (_hasRedirected) return;
    _hasRedirected = true;

    safeDebugPrint('🟢 [NAVIGATE] Redirecting to dashboard');
    if (!mounted) return;

    try {
      context.go('/dashboard');
      safeDebugPrint('🟢 [NAVIGATE] go() to /dashboard successful');
    } catch (e) {
      safeDebugPrint('🔴 [NAVIGATE] go() error: $e');
    }
  }

  void _setupMainLicenseListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _licenseStatusSubscription?.cancel();
    _requestStatusSubscription?.cancel();
    _licenseListenerSubscription?.cancel();

    _licenseStatusSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _checkAndRedirect();
    });

    _requestStatusSubscription = _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _checkAndRedirect();
    });
  }

  Future<void> _checkAndRedirect() async {
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    final user = _auth.currentUser;
    if (user == null) return;

    final licenseSnapshot = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .get();

    final validDoc = licenseSnapshot.docs.firstWhereOrNull((doc) {
      final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
      return expiry != null && expiry.isAfter(DateTime.now());
    });

    if (validDoc != null) {
      await _secureStorage.write(key: _keyLicenseKey, value: validDoc.id);
      safeDebugPrint('Redirecting to dashboard - active license found');
      Future.microtask(() {
        if (mounted) context.go('/dashboard');
      });
      return;
    }

    final requestSnapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .get();

    if (requestSnapshot.docs.isNotEmpty) {
      safeDebugPrint('Redirecting to dashboard - approved request found');
      Future.microtask(() {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  @override
  void dispose() {
    _licenseStatusSubscription?.cancel();
    _requestStatusSubscription?.cancel();
    _licenseListenerSubscription?.cancel();
    super.dispose();
  }

  void _setupLicenseStatusListener() {
    final user = _auth.currentUser;
    if (user == null) return;
    _licenseStatusSubscription?.cancel();
    _licenseStatusSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final licenseDoc =
          snapshot.docs.where((doc) => doc.exists).firstWhereOrNull((doc) {
        final isActive = doc.get('isActive') as bool? ?? false;
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        final now = DateTime.now().toUtc();
        final isExpired = expiry != null && expiry.isBefore(now);
        return isActive && !isExpired;
      });

      if (licenseDoc == null) {
        safeDebugPrint('user license page : No License found ...');
        return;
      }

      safeDebugPrint('Active license found, redirecting to dashboard');
      Future.microtask(() {
        if (mounted) context.go('/dashboard');
      });
    });
  }

  void _setupRequestStatusListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _requestStatusSubscription = _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'approved'])
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final status = doc.get('status');

            switch (status) {
              case 'approved':
                _requestStatusSubscription?.cancel();
                _requestStatusSubscription = null;
                Future.microtask(() {
                  if (mounted) context.go('/dashboard');
                });
                break;
              case 'pending':
                setState(() {
                  _isPending = true;
                });
                break;
            }
          }
        });
  }

  void _setupLicenseListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _licenseListenerSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.docs.isNotEmpty && _hasSubmittedRequest) {
        Future.microtask(() {
          if (mounted) context.go('/dashboard');
        });
      }
    });
  }

  Future<void> _loadDeviceData() async {
    await _loadCurrentDeviceCount();
    await _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final licenseQuery = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _currentDevicesCount = 0;
          if (licenseQuery.docs.isNotEmpty) {
            final doc = licenseQuery.docs.first.data();
            final deviceIds = doc['deviceIds'];
            if (deviceIds is List) {
              _currentDevicesCount = deviceIds.length;
            }
          }
        });
      }
    } catch (e) {
      safeDebugPrint('Error loading device count: $e');
    }
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      String deviceId = '';
      String deviceDetails = '';

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceId = "${webInfo.vendor ?? 'web'}-${webInfo.userAgent.hashCode}";
        deviceDetails = webInfo.browserName.name;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        String rawId = androidInfo.id;
        if (rawId.isEmpty || rawId == 'null') {
          rawId = androidInfo.hardware.hashCode.toString();
        }
        final String manufacturer =
            (androidInfo.manufacturer).toUpperCase().trim();
        final String model = (androidInfo.model).toUpperCase().trim();
        deviceId = rawId;
        deviceDetails = "$manufacturer - $model";
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
        deviceDetails = "APPLE - ${iosInfo.model}";
      } else {
        deviceId = 'fallback-id-platform';
        deviceDetails = 'UNKNOWN';
      }

      if (mounted) {
        setState(() {
          _currentDeviceId = "$deviceDetails ($deviceId)";
        });
        safeDebugPrint('📱 Secure Device Info Loaded: $_currentDeviceId');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading device info: $e');
      if (mounted) {
        setState(() {
          _currentDeviceId =
              'FALLBACK-${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ عرض شاشة التحميل
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('license_request.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ عرض خيار استبدال الجهاز
    // في user_license_request.dart - تعديل جزء عرض معلومات الترخيص

// ✅ في build method، قسم عرض استبدال الجهاز
    if (_showDeviceReplacement && _existingLicenseKey != null) {
      // تنسيق التاريخ بشكل صحيح
      String expiryText = 'unknown';
      String maxDevicesText = 'unknown';

      if (_existingLicenseExpiry != null) {
        // تنسيق التاريخ: 15/06/2026
        expiryText =
            '${_existingLicenseExpiry!.day}/${_existingLicenseExpiry!.month}/${_existingLicenseExpiry!.year}';
      }

      if (_existingMaxDevices > 0) {
        maxDevicesText = _existingMaxDevices.toString();
      }

      return Scaffold(
        appBar: AppBar(title: Text('device_registration'.tr())),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phonelink_off_rounded,
                  size: 72, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                'device_not_registered'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'device_not_registered_description'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'license_info'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('expires_on'.tr()),
                        const SizedBox(width: 4),
                        Text(
                          expiryText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.devices, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('max_devices_allowed'.tr()),
                        const SizedBox(width: 4),
                        Text(
                          maxDevicesText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'device_replacement_note'.tr(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // زر استبدال الجهاز
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _showReplaceConfirmDialog,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.swap_horiz_rounded),
                label: Text(
                  'replace_device'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ النموذج العادي لطلب ترخيص جديد
    return Scaffold(
      appBar: AppBar(
        title: Text('license_request.title'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDurationSelector(),
                const SizedBox(height: 14),
                _buildDeviceSelector(),
                const SizedBox(height: 14),
                _buildDeviceWarning(),
                const SizedBox(height: 14),
                _buildRequestInfoCard(),
                const SizedBox(height: 14),
                if (_isPending)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty,
                              color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'license_request_pending'.tr(),
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'subscription_duration'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedDuration,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [1, 3, 6, 12].map((months) {
                return DropdownMenuItem(
                  value: months,
                  child: Text('$months ${'months'.tr()}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDuration = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'number_of_devices'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedDevices,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [1, 2, 3, 5].map((deviceCount) {
                return DropdownMenuItem(
                  value: deviceCount,
                  child: Text('$deviceCount ${'devices'.tr()}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDevices = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceWarning() {
    if (_currentDevicesCount >= _selectedDevices) {
      return Card(
        color: Colors.orange.withAlpha(75),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'device_limit_warning'
                      .tr(args: [_selectedDevices.toString()]),
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildRequestInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'request_summary'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                'duration'.tr(), '$_selectedDuration ${'months'.tr()}'),
            _buildInfoRow('devices_allowed'.tr(), '$_selectedDevices'),
            _buildInfoRow('current_devices'.tr(), '$_currentDevicesCount'),
            _buildInfoRow('device_id'.tr(), _currentDeviceId),
            if (_isPending)
              _buildInfoRow('request_status'.tr(), 'pending'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isPending) ? null : _submitRequest,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Text('submit_request'.tr()),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_currentDeviceId.isEmpty) {
      _showErrorSnackBar('device_id_not_loaded'.tr());
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('user_not_authenticated'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      final existingRequestSnapshot = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'approved']).get();

      bool hasActiveRequest = false;

      for (var doc in existingRequestSnapshot.docs) {
        final status = doc.get('status');

        if (status == 'pending') {
          hasActiveRequest = true;
          break;
        }

        if (status == 'approved') {
          final licenseSnapshot = await _firestore
              .collection('licenses')
              .where('userId', isEqualTo: user.uid)
              .where('isActive', isEqualTo: true)
              .get();

          final now = DateTime.now().toUtc();
          bool hasValidLicense = licenseSnapshot.docs.any((licenseDoc) {
            final expiryTimestamp = licenseDoc.get('expiryDate') as Timestamp?;
            if (expiryTimestamp == null) return false;
            final expiryDate = expiryTimestamp.toDate();
            return expiryDate.isAfter(now);
          });

          if (hasValidLicense) {
            hasActiveRequest = true;
            break;
          }
        }
      }

      if (hasActiveRequest) {
        _showErrorSnackBar('existing_request_found'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      final String requestNumber = await _generateRequestNumber();

      final batch = _firestore.batch();
      final newRequestRef =
          _firestore.collection('license_requests').doc(requestNumber);

      batch.set(newRequestRef, {
        'requestId': requestNumber,
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'deviceIds': [_currentDeviceId],
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email,
      });

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _hasSubmittedRequest = true;
        _isSubmitting = false;
        _isPending = true;
      });

      _showSuccessMessage(requestNumber);
      await _loadCurrentDeviceCount();
    } catch (e) {
      _showErrorSnackBar('request_failed'.tr(args: [e.toString()]));
      setState(() => _isSubmitting = false);
    }
  }

  Future<String> _generateRequestNumber() async {
    try {
      final now = DateTime.now();
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final todayRequests = await _firestore
          .collection('license_requests')
          .where('requestId', isGreaterThanOrEqualTo: 'REQ-$datePart-')
          .where('requestId', isLessThan: 'REQ-$datePart-9999')
          .orderBy('requestId', descending: true)
          .limit(1)
          .get();

      int sequenceNumber = 1;

      if (todayRequests.docs.isNotEmpty) {
        final lastRequestId = todayRequests.docs.first.id;
        final parts = lastRequestId.split('-');
        if (parts.length == 3) {
          final lastSequence = int.tryParse(parts[2]) ?? 0;
          sequenceNumber = lastSequence + 1;
        }
      }

      sequenceNumber = sequenceNumber.clamp(1, 9999);
      return 'REQ-$datePart-${sequenceNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      safeDebugPrint('Error generating request number: $e');
      return 'REQ-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${_uuid.v4().substring(0, 4)}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }

  void _showSuccessMessage(String requestNumber) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('request_successful'.tr()),
            const SizedBox(height: 4),
            Text(
              '${'request_number'.tr()}: $requestNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }
}
