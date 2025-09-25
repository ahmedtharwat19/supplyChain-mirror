/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:puresip_purchasing/services/device_fingerprint.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

// صفحة إدارة الأجهزة
// device_management_page.dart
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

  @override
  void initState() {
    super.initState();
    _resolveLicenseId();
  }

  Future<void> _resolveLicenseId() async {
    setState(() => _isLoading = true);

    // إذا تم توفير licenseId، استخدمه
    if (widget.licenseId != null) {
      _resolvedLicenseId = widget.licenseId;
      await _loadData();
      return;
    }

    // إذا لم يتم توفير licenseId، حاول الحصول عليه من المستخدم الحالي
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
          await _loadData();
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

/*   Future<void> _loadData() async {
    if (_resolvedLicenseId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final status = await _licenseService.getCurrentUserLicenseStatus();
    await _loadDevices();
    await _loadCurrentDeviceId();

    setState(() {
      _licenseStatus = status;
      _isLoading = false;
    });
  }
 */

Future<void> _loadData() async {
  if (_resolvedLicenseId == null) {
    setState(() => _isLoading = false);
    return;
  }
  
  setState(() => _isLoading = true);
  
  try {
    final status = await _licenseService.getCurrentUserLicenseStatus();
    await _loadDevices();
    await _loadCurrentDeviceId();
    
    setState(() {
      _licenseStatus = status;
      _isLoading = false;
    });
    
    // إذا أصبح الاشتراك صالحاً، الانتقال للداشبورد
    if (status.isValid) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          context.go('/dashboard');
        }
      });
    }
  } catch (e) {
    setState(() => _isLoading = false);
    safeDebugPrint('Error loading data: $e');
  }
}

  Future<void> _loadDevices() async {
    if (_resolvedLicenseId == null) return;
    final devices = await _service.getRegisteredDevices(_resolvedLicenseId!);
    setState(() => _devices = devices);
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      setState(() => _currentDeviceId = currentFingerprint);
    } catch (e) {
      safeDebugPrint('Error loading current device ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('device_management'.tr())),
      body: _isLoading || _licenseStatus == null
          ? const Center(child: CircularProgressIndicator())
          :_buildContent(),
  );
}

Widget _buildContent() {
  if (_licenseStatus == null) {
    return Center(child: Text('loading_failed'.tr()));
  }
  
  return  Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات الترخيص
                  Card(
                    color: Colors.grey[400],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('license_info'.tr(),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          _buildInfoRow('devices_used'.tr(),
                              '${_licenseStatus!.usedDevices}/${_licenseStatus!.maxDevices}'),
                          _buildInfoRow('days_remaining'.tr(),
                              '${_licenseStatus!.daysLeft}'),
                          if (_licenseStatus!.formattedRemaining != null)
                            _buildInfoRow('time_remaining'.tr(),
                                _licenseStatus!.formattedRemaining!),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // تحذير تجاوز الحد
                  if (_licenseStatus!.deviceLimitExceeded)
                    Card(
                      color: Colors.red.withAlpha(75),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: Colors.orange),
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

                  Text('registered_devices'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

  /*                 Expanded(
                    child: _devices.isEmpty
                        ? Center(child: Text('no_devices_registered'.tr()))
                        : ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              final isCurrent =
                                  device['fingerprint'] == _currentDeviceId;

                              return Card(
                                child: ListTile(
                                  title: Text(
                                      device['deviceName'] ?? 'Unknown Device'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(device['fingerprint']?.toString() ??
                                          ''),
                                      if (isCurrent)
                                        Text('current_device'.tr(),
                                            style: const TextStyle(
                                                color: Colors.green)),
                                      if (device['registeredAt'] != null)
                                        Text('registered_on'.tr(args: [
                                          _formatDate(device['registeredAt'])
                                        ])),
                                    ],
                                  ),
                                  trailing: !isCurrent
                                      ? IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _unregisterDevice(
                                              device['fingerprint']),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
 */

// في بناء واجهة الأجهزة
Expanded(
  child: _devices.isEmpty
      ? Center(child: Text('no_devices_registered'.tr()))
      : ListView.builder(
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            final isCurrent = device['fingerprint'] == _currentDeviceId;
            
            return Card(
              child: ListTile(
                title: Text(device['deviceName'] ?? 'Unknown Device'),
                subtitle: _buildDeviceInfoSubtitle(device, isCurrent),
                trailing: !isCurrent ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeviceDeleteDialog(device),
                ) : null,
              ),
            );
          },
        ),
),

                  const SizedBox(height: 16),
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
                ],
              ),
            
    );  
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
          ),
        ],
      ),
    );
  }

/*   String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
    }
    return date.toString();
  }
 */

String _formatDate(dynamic date) {
  try {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } else if (date is String) {
      return date;
    }
    return date.toString();
  } catch (e) {
    return 'Unknown date';
  }
}
  // ... باقي الدوال (registerCurrentDevice, unregisterDevice, requestNewDeviceSlot)

  Future<void> _registerCurrentDevice() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final success =
        await _service.registerDeviceFingerprint(_resolvedLicenseId!);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_registered_successfully'.tr())),
        );
        _loadDevices();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_register_device'.tr())),
        );
      }
    }
  }

/*   Future<void> _unregisterDevice(String fingerprint) async {
  if (_resolvedLicenseId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('license_not_found'.tr())),
    );
    return;
  }
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('unregister_device'.tr()),
      content: Text('confirm_unregister_device'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('confirm'.tr()),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final success = await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_unregistered_successfully'.tr())),
        );
        
        // إعادة تحميل البيانات وتحديث الواجهة
        await _loadData();
        
        // التحقق إذا تم التسجيل التلقائي والانتقال للداشبورد إذا كان صالحاً
        _checkAndNavigateToDashboard();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_to_unregister_device'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
 */

Future<void> _unregisterDevice(String fingerprint) async {
  if (_resolvedLicenseId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('license_not_found'.tr())),
    );
    return;
  }
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('unregister_device'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('confirm_unregister_device'.tr()),
          const SizedBox(height: 8),
          Text(
            'auto_register_warning'.tr(),
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
            ),
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
          child: Text('confirm'.tr()),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    // عرض مؤشر التحميل
    setState(() => _isLoading = true);
    
    final success = await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_unregistered_and_registered'.tr())),
        );
        
        // إعادة تحميل البيانات وتحديث الواجهة
        await _loadData();
        
        // التحقق إذا تم التسجيل التلقائي والانتقال للداشبورد إذا كان صالحاً
        _checkAndNavigateToDashboard();
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_to_unregister_device'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


// دالة للتحقق من صحة الاشتراك والانتقال للداشبورد
void _checkAndNavigateToDashboard() async {
  if (_resolvedLicenseId == null) return;
  
  final status = await _licenseService.getCurrentUserLicenseStatus();
  
  if (status.isValid) {
    // الانتقال للداشبورد بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/dashboard');
      }
    });
  }
}

/*   Future<void> _unregisterDevice(String fingerprint) async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unregister_device'.tr()),
        content: Text('confirm_unregister_device'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('device_unregistered_successfully'.tr())),
          );
          _loadDevices();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('failed_to_unregister_device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
 */

/* Future<void> _unregisterDevice(String fingerprint) async {
  if (_resolvedLicenseId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('license_not_found'.tr())),
    );
    return;
  }
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('unregister_device'.tr()),
      content: Text('confirm_unregister_device'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('confirm'.tr()),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final success = await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_unregistered_successfully'.tr())),
        );
        _loadDevices();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_unregister_device'.tr())),
        );
      }
    }
  }
}
 */

  Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('request_new_device_slot'.tr()),
        content: TextField(
          decoration: InputDecoration(hintText: 'reason_for_request'.tr()),
          onChanged: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('submit'.tr()),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await _service.requestNewDeviceSlot(_resolvedLicenseId!, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );
      }
    }
  }


// دالة لعرض معلومات الجهاز
Widget _buildDeviceInfoSubtitle(Map<String, dynamic> device, bool isCurrent) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (device['platform'] != null) 
        Text('${device['platform']} ${device['model'] ?? ''}'),
      if (device['os'] != null) 
        Text('OS: ${device['os']}'),
      if (device['browser'] != null && device['browser'] != 'N/A') 
        Text('Browser: ${device['browser']}'),
      if (device['registeredAt'] != null)
        Text('Registered: ${_formatDate(device['registeredAt'])}'),
      if (device['lastActive'] != null)
        Text('Last active: ${_formatDate(device['lastActive'])}'),
      if (isCurrent) 
        Text('current_device'.tr(), style: const TextStyle(color: Colors.green)),
    ],
  );
}

// دالة لعرض تأكيد الحذف مع معلومات الجهاز
Future<void> _showDeviceDeleteDialog(Map<String, dynamic> device) async {
  final fingerprint = device['fingerprint'];
  
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('unregister_device'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('confirm_unregister_specific_device'.tr()),
          const SizedBox(height: 16),
          _buildDeviceInfoCard(device),
          const SizedBox(height: 8),
          Text(
            'auto_register_warning'.tr(),
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _unregisterDevice(fingerprint);
          },
          child: Text('unregister'.tr()),
        ),
      ],
    ),
  );
}

// بطاقة معلومات الجهاز
Widget _buildDeviceInfoCard(Map<String, dynamic> device) {
  return Card(
    color: Colors.grey[100],
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            device['deviceName'] ?? 'Unknown Device',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (device['platform'] != null) 
            Text('Platform: ${device['platform']}'),
          if (device['model'] != null) 
            Text('Model: ${device['model']}'),
          if (device['os'] != null) 
            Text('OS: ${device['os']}'),
          if (device['browser'] != null && device['browser'] != 'N/A') 
            Text('Browser: ${device['browser']}'),
          if (device['registeredAt'] != null)
            Text('Registered: ${_formatDate(device['registeredAt'])}'),
        ],
      ),
    ),
  );
}

}
 */

/*  Future<List<String>> getAdminFcmTokens() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isAdmin', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .get();

    List<String> tokens = [];
    for (var doc in snapshot.docs) {
      final fcmTokens = doc.data()['fcmTokens'];
      if (fcmTokens is List) {
        tokens.addAll(fcmTokens.whereType<String>());
      }
    }
    return tokens;
  }
 */

/*   Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    String? userReason; // المتغير النهائي للاستخدام بعد Dialog

    // فتح Dialog للحصول على السبب
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempReason = '';
        return AlertDialog(
          title: Text('request_new_device_slot'.tr()),
          content: TextField(
            decoration: InputDecoration(hintText: 'reason_for_request'.tr()),
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

    userReason = result;

    if (userReason != null && userReason.isNotEmpty) {
      // إرسال طلب الفتحة
      await _service.requestNewDeviceSlot(_resolvedLicenseId!, userReason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );
      }

      // استدعاء قائمة توكنات المشرفين
      final adminTokens = await getAdminFcmTokens();
      final user = _auth.currentUser;
      if (user != null && adminTokens.isNotEmpty) {
        await LicenseNotifications.sendApprovalNotification(
          userId: user.uid,
          licenseKey: _resolvedLicenseId!,
          requestId: 'request_slot_${DateTime.now().millisecondsSinceEpoch}',
       //   adminTokens: adminTokens,
        );
      }
    }
  }
 */
/* 
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/license_status.dart';
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
  StreamSubscription<DocumentSnapshot>? _deviceRequestSubscription;

  @override
  void initState() {
    super.initState();
    _resolveLicenseId();
    //_listenForPendingDeviceRequests();
    _listenForApprovedDeviceRequests();
  }

  StreamSubscription<QuerySnapshot>? _deviceRequestsSubscription;

  Future<void> _listenForApprovedDeviceRequests() async {
  final user = _auth.currentUser;
  if (user == null) return;

  try {
    safeDebugPrint('🔄 Starting to listen for APPROVED device requests');

    _deviceRequestsSubscription = FirebaseFirestore.instance
        .collection('device_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .where('processed', isEqualTo: true)
        .orderBy('processedAt', descending: true)
        .snapshots()
        .listen((querySnapshot) {
      if (!mounted) return;

      safeDebugPrint('📡 Received ${querySnapshot.docs.length} APPROVED device requests');

      for (final doc in querySnapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
          safeDebugPrint('🎉 New approved request found: ${doc.doc.id}');
          
        //  _deviceRequestsSubscription?.cancel();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('device_request_approved_title'.tr())),
              );
             
            //  _loadData(navigateIfValid: true);
             //  _loadDataAndNavigate();
               context.go('/dashboard');
            }
          });
          break;
        }
      }
    });
  } catch (e) {
    safeDebugPrint('Error listening for approved device requests: $e');
  }
}


Future<void> _loadDataAndNavigate() async {
  if (_resolvedLicenseId == null) {
    safeDebugPrint('❌ No license ID resolved');
    return;
  }

  safeDebugPrint('🔄 Loading data and checking navigation...');

  try {
    // تحميل حالة الترخيص أولاً
    final status = await _licenseService.getCurrentUserLicenseStatus();
    safeDebugPrint('📊 License status after approval: isValid=${status.isValid}');
    
    // تحميل الأجهزة والبيانات
    await _loadDevices();
    await _loadCurrentDeviceId();

    if (mounted) {
      setState(() {
        _licenseStatus = status;
        _isLoading = false;
      });
    }

    // إذا كان الترخيص صالحاً، التوجيه فوراً
    if (status.isValid) {
      safeDebugPrint('✅ License is valid, navigating to dashboard immediately');
      final wasMounted = mounted;
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (wasMounted && mounted) {
          safeDebugPrint('➡️ Navigating to dashboard now');
          context.go('/dashboard');
        }
      });
    } else {
      safeDebugPrint('❌ License still not valid after approval');
      safeDebugPrint('Used devices: ${status.usedDevices}, Max devices: ${status.maxDevices}');
      
      // إذا لم يكن صالحاً، إظهار رسالة توضيحية
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الترخيص لا يزال غير صالح. يرجى الانتظار...')),
        );
      }
    }
  } catch (e) {
    safeDebugPrint('❌ Error in _loadDataAndNavigate: $e');
  }
}

  /* Future<void> _listenForPendingDeviceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
          safeDebugPrint('🔄 Starting to listen for device requests'); // أضف هذا

      // الاستماع لجميع الطلبات المعلقة للمستخدم
      _deviceRequestsSubscription = FirebaseFirestore.instance
          .collection('device_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        if (!mounted) return;

      safeDebugPrint('📡 Device requests snapshot received: ${querySnapshot.docs.length} documents');

        for (final doc in querySnapshot.docChanges) {
                  safeDebugPrint('📝 Document change: ${doc.type}, doc: ${doc.doc.id}'); // أضف هذا

          if (doc.type == DocumentChangeType.modified) {
            final data = doc.doc.data();
            final status = data?['status'];
            final isApproved = status == 'approved';
            final isProcessed = data?['processed'] == true;

            safeDebugPrint(
                'Device request update: status=$status, approved=$isApproved, processed=$isProcessed');

            if (isApproved && isProcessed) {
              safeDebugPrint(
                  'Device request approved, navigating to dashboard');

              // إغلاق الاشتراك أولاً
              _deviceRequestsSubscription?.cancel();

              // الانتقال إلى dashboard مع تحديث البيانات
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('device_request_approved_success'.tr())),
                  );
                  _loadData(navigateIfValid: true);
                }
              });
              break; // الخروج بعد معالجة الطلب المعتمد
            }
          }
        }
      });
    } catch (e) {
      safeDebugPrint('Error listening for device requests: $e');
    }
  }
 */
  /*  Future<void> _listenForPendingDeviceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // البحث عن أي طلب معلق للمستخدم
      final pendingRequests = await FirebaseFirestore.instance
          .collection('device_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (pendingRequests.docs.isNotEmpty) {
        final doc = pendingRequests.docs.first;

        // الاستماع لتحديثات هذا الطلب المحدد
        _deviceRequestSubscription =
            doc.reference.snapshots().listen((snapshot) {
          if (!snapshot.exists) return;

          final data = snapshot.data();
          final status = data?['status'];
          final isApproved = status == 'approved';
          final isProcessed = data?['processed'] == true;

          safeDebugPrint(
              'Device request update: status=$status, approved=$isApproved, processed=$isProcessed');

          if (isApproved && isProcessed && mounted) {
            safeDebugPrint('Device request approved, navigating to dashboard');

            // إغلاق الاشتراك أولاً
            _deviceRequestSubscription?.cancel();

            // الانتقال إلى dashboard مع تحديث البيانات
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('device_request_approved_success'.tr())),
                );
                _loadData(navigateIfValid: true); // إعادة تحميل البيانات
              }
            });
          }
        });
      }
    } catch (e) {
      safeDebugPrint('Error listening for device request: $e');
    }
  }
 */
  @override
  void dispose() {
    // إذا لديك مستمعين أو مؤقتات، أوقفهم هنا.
    _deviceRequestSubscription?.cancel();
    _deviceRequestsSubscription?.cancel();
    super.dispose();
  }

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

/*   Future<void> _loadData({bool navigateIfValid = true}) async {
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

      safeDebugPrint(
          'License status after approval: isValid=${status.isValid}');

      if (navigateIfValid && status.isValid) {
        safeDebugPrint('Navigating to dashboard after device approval');
        final wasMounted = mounted;

        // تأخير بسيط للسماح بتحديث الواجهة
        Future.delayed(const Duration(milliseconds: 500), () {
          if (wasMounted && mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      safeDebugPrint('Error loading data after approval: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }
 */

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

      safeDebugPrint(
          'License status: isValid=${status.isValid}, usedDevices=${status.usedDevices}, maxDevices=${status.maxDevices}');

      if (navigateIfValid && status.isValid) {
        safeDebugPrint('✅ License is valid, navigating to dashboard');
        final wasMounted = mounted;

        // تأخير بسيط للسماح بتحديث الواجهة
        Future.delayed(const Duration(milliseconds: 500), () {
          if (wasMounted && mounted) {
            context.go('/dashboard');
          }
        });
      } else {
        safeDebugPrint(
            '❌ License is not valid, staying on device management page');
      }
    } catch (e) {
      safeDebugPrint('Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDevices() async {
    if (_resolvedLicenseId == null) return;
    final devices = await _service.getRegisteredDevices(_resolvedLicenseId!);
    if (!mounted) return;
    setState(() => _devices = devices);
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      if (!mounted) return;
      setState(() => _currentDeviceId = currentFingerprint);
    } catch (e) {
      safeDebugPrint('Error loading current device ID: $e');
    }
  }

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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات الترخيص
          Card(
            color: Colors.grey[400],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'license_info'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // تحذير تجاوز الحد
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
                        child: ListTile(
                          title: Text(device['deviceName'] ?? 'Unknown Device'),
                          subtitle: _buildDeviceInfoSubtitle(device, isCurrent),
                          trailing: !isCurrent
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeviceDeleteDialog(device),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _licenseStatus!.usedDevices < _licenseStatus!.maxDevices
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      } else if (date is String) {
        return date;
      }
      return date.toString();
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _registerCurrentDevice() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final success =
        await _service.registerDeviceFingerprint(_resolvedLicenseId!);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_registered_successfully'.tr())),
        );
        _loadDevices();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_register_device'.tr())),
        );
      }
    }
  }

  Future<void> _unregisterDevice(String fingerprint) async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unregister_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('confirm_unregister_device'.tr()),
            const SizedBox(height: 8),
            Text(
              'auto_register_warning'.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
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
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final success =
          await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('device_unregistered_and_registered'.tr()),
            ),
          );
          await _loadData(navigateIfValid: false);
          _checkAndNavigateToDashboard();
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('failed_to_unregister_device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _checkAndNavigateToDashboard() async {
    if (_resolvedLicenseId == null) return;
    final status = await _licenseService.getCurrentUserLicenseStatus();
    if (status.isValid) {
      final wasMounted = mounted;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (wasMounted && mounted) {
          context.go('/dashboard');
        }
      });
    }
  }

  /*  Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final licenseId = _resolvedLicenseId!;
    final requestId =
        'request_${licenseId}_${DateTime.now().millisecondsSinceEpoch}';

    // تحقق أولاً من وجود طلب سابق لم تتم الموافقة عليه
    final existingRequests = await FirebaseFirestore.instance
        .collection('device_requests')
        .where('licenseId', isEqualTo: licenseId)
        .where('userId', isEqualTo: user.uid)
        .where('approved', isEqualTo: false)
        .where('processed', isEqualTo: false)
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

    // فتح Dialog للحصول على السبب
    String? userReason = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempReason = '';
        return AlertDialog(
          title: Text('request_new_device_slot'.tr()),
          content: TextField(
            decoration: InputDecoration(hintText: 'reason_for_request'.tr()),
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
      // الحصول على بيانات الجهاز الحالي
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      // إرسال الطلب إلى Firestore مع بيانات الجهاز
      final requestRef = FirebaseFirestore.instance
          .collection('device_requests')
          .doc(requestId);

      await requestRef.set({
        'userId': user.uid,
        'licenseId': licenseId,
        'reason': userReason,
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'processed': false,
        'status': 'pending',

        // إضافة بيانات الجهاز
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'browser': deviceInfo['browser'],
        'fingerprint': currentFingerprint,
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );
      }

      // إضافة Listener للاستماع لتحديث الطلب
      requestRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        final isApproved = data?['approved'] == true;

        if (isApproved && mounted) {
          context.go('/dashboard');
        }
      });
    } catch (e) {
      safeDebugPrint('Error creating device request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_create_request'.tr())),
        );
      }
    }
  }
 */

  Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    // أولاً: التحقق من حالة الترخيص الحالية
    final currentStatus = await _licenseService.getCurrentUserLicenseStatus();
    if (currentStatus.isValid) {
      // إذا الترخيص صالح الآن، لا داعي لطلب جديد
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('license_already_valid_no_need_for_request'.tr())),
        );
        _loadData(navigateIfValid: true);
      }
      return;
    }

    final licenseId = _resolvedLicenseId!;
    final requestId =
        'request_${licenseId}_${DateTime.now().millisecondsSinceEpoch}';

    // تحقق من وجود طلب سابق
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

    // فتح Dialog للحصول على السبب
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
      // الحصول على بيانات الجهاز الحالي
      final currentFingerprint = await DeviceFingerprint.generate();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();

      safeDebugPrint(
          'Creating device request with fingerprint: $currentFingerprint');

      // إرسال الطلب إلى Firestore مع بيانات الجهاز
      final requestRef = FirebaseFirestore.instance
          .collection('device_requests')
          .doc(requestId);

      await requestRef.set({
        'userId': user.uid,
        'licenseId': licenseId,
        'reason': userReason,
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'processed': false,
        'status': 'pending',
        'userEmail': user.email,
        'userDisplayName': user.displayName,

        // إضافة بيانات الجهاز
        'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
        'platform': deviceInfo['platform'] ?? 'Unknown Platform',
        'browser': deviceInfo['browser'] ?? 'Unknown Browser',
        'fingerprint': currentFingerprint,
        'model': deviceInfo['model'] ?? 'Unknown Model',
        'os': deviceInfo['os'] ?? 'Unknown OS',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );

        // إعادة تحميل المستمع للطلبات
        _deviceRequestsSubscription?.cancel();
       // _listenForPendingDeviceRequests();
          _listenForApprovedDeviceRequests(); // استدع الدالة الصحيحة

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

  Widget _buildDeviceInfoSubtitle(Map<String, dynamic> device, bool isCurrent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (device['platform'] != null)
          Text('${device['platform']} ${device['model'] ?? ''}'),
        if (device['os'] != null) Text('OS: ${device['os']}'),
        if (device['browser'] != null && device['browser'] != 'N/A')
          Text('Browser: ${device['browser']}'),
        if (device['registeredAt'] != null)
          Text('Registered: ${_formatDate(device['registeredAt'])}'),
        if (device['lastActive'] != null)
          Text('Last active: ${_formatDate(device['lastActive'])}'),
        if (isCurrent)
          Text('current_device'.tr(),
              style: const TextStyle(color: Colors.green)),
      ],
    );
  }

  Future<void> _showDeviceDeleteDialog(Map<String, dynamic> device) async {
    final fingerprint = device['fingerprint'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unregister_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('confirm_unregister_specific_device'.tr()),
            const SizedBox(height: 16),
            _buildDeviceInfoCard(device),
            const SizedBox(height: 8),
            Text(
              'auto_register_warning'.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unregisterDevice(fingerprint);
            },
            child: Text('unregister'.tr()),
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
              device['deviceName'] ?? 'Unknown Device',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (device['platform'] != null)
              Text('Platform: ${device['platform']}'),
            if (device['model'] != null) Text('Model: ${device['model']}'),
            if (device['os'] != null) Text('OS: ${device['os']}'),
            if (device['browser'] != null && device['browser'] != 'N/A')
              Text('Browser: ${device['browser']}'),
            if (device['registeredAt'] != null)
              Text('Registered: ${_formatDate(device['registeredAt'])}'),
          ],
        ),
      ),
    );
  }
}
 */

/*   Future<void> _listenForDeviceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      safeDebugPrint('🔄 Starting to listen for device requests');

      _deviceRequestsSubscription = FirebaseFirestore.instance
          .collection('device_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        if (!mounted) return;

        safeDebugPrint('📡 Received ${querySnapshot.docs.length} device requests');

        for (final doc in querySnapshot.docChanges) {
          final data = doc.doc.data();
          safeDebugPrint('📝 Change: ${doc.type}, ID: ${doc.doc.id}, Status: ${data?['status']}');

          if (doc.type == DocumentChangeType.modified) {
            final status = data?['status'];
            final isApproved = data?['approved'] == true;
            final isProcessed = data?['processed'] == true;

            safeDebugPrint('🔍 Checking: status=$status, approved=$isApproved, processed=$isProcessed');

            if (status == 'approved' && isApproved && isProcessed) {
              safeDebugPrint('🎉 Device request approved! Processing...');
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('device_request_approved'.tr())),
                  );
                  
                  _handleApprovedRequest();
                }
              });
              break;
            }
          }
        }
      }, onError: (error) {
        safeDebugPrint('❌ Error in device request listener: $error');
      });
    } catch (e) {
      safeDebugPrint('Error listening for device requests: $e');
    }
  }
 */

/* Future<void> _listenForDeviceRequests() async {
  final user = _auth.currentUser;
  if (user == null) return;

  try {
    safeDebugPrint('🔄 Starting to listen for device requests');

    _deviceRequestsSubscription = FirebaseFirestore.instance
        .collection('device_requests')
        .where('userId', isEqualTo: user.uid)
        .orderBy('processedAt', descending: true) // نرتب حسب تاريخ المعالجة
        .limit(5) // نأخذ آخر 5 طلبات فقط
        .snapshots()
        .listen((querySnapshot) {
      if (!mounted) return;

      safeDebugPrint('📡 Received ${querySnapshot.docs.length} device requests');

      for (final doc in querySnapshot.docChanges) {
        final data = doc.doc.data();
        final status = data?['status'];
        final isApproved = data?['approved'] == true;
        final isProcessed = data?['processed'] == true;
        final requestId = doc.doc.id;

        safeDebugPrint('📝 Request: $requestId, status=$status, approved=$isApproved, processed=$isProcessed');

        // إذا كان هذا الطلب تمت الموافقة عليه ومعالجته حديثاً
        if ((doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) &&
            status == 'approved' && isApproved && isProcessed) {
          
          // تحقق إذا كان هذا الطلب حديث (في آخر 5 دقائق)
          final processedAt = data?['processedAt'] as Timestamp?;
          if (processedAt != null) {
            final processedTime = processedAt.toDate();
            final now = DateTime.now();
            final difference = now.difference(processedTime);

            if (difference.inMinutes <= 5) { // طلب حديث
              safeDebugPrint('🎉 Recent approved request found: $requestId');
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('device_request_approved'.tr())),
                  );
                  
                  // الانتقال مباشرة إلى dashboard دون التحقق من الترخيص
                  _navigateToDashboard();
                }
              });
              break;
            }
          }
        }
      }
    }, onError: (error) {
      safeDebugPrint('❌ Error in device request listener: $error');
    });
  } catch (e) {
    safeDebugPrint('Error listening for device requests: $e');
  }
} */

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/license_status.dart';
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
  StreamSubscription<QuerySnapshot>? _deviceRequestsSubscription;
  // int _checkAttempts = 0;
  // final int _maxCheckAttempts = 10;

  @override
  void initState() {
    super.initState();
    _resolveLicenseId();
    _listenForDeviceRequests();
  }

  Future<void> _listenForDeviceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      safeDebugPrint('🔄 Starting to listen for ALL device requests');

      _deviceRequestsSubscription = FirebaseFirestore.instance
          .collection('device_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('processedAt', descending: true) // نرتب حسب تاريخ المعالجة
          .snapshots()
          .listen((querySnapshot) {
        if (!mounted) return;

        safeDebugPrint(
            '📡 Received ${querySnapshot.docs.length} device requests');

        for (final doc in querySnapshot.docChanges) {
          final data = doc.doc.data();
          final status = data?['status'];
          final isApproved = data?['approved'] == true;
          final isProcessed = data?['processed'] == true;
          final requestId = doc.doc.id;
          final processedAt = data?['processedAt'] as Timestamp?;

          safeDebugPrint(
              '📝 Request: $requestId, status=$status, approved=$isApproved, processed=$isProcessed, processedAt=$processedAt');

          // إذا كان الطلب تمت الموافقة عليه ومعالجته
          if (status == 'approved' &&
              isApproved &&
              isProcessed &&
              processedAt != null) {
            safeDebugPrint('🎉 Approved request found: $requestId');

            // التحقق إذا كان هذا هو أحدث طلب معالج
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

  void _checkIfLatestApprovedRequest(List<DocumentSnapshot> allRequests) {
    if (allRequests.isEmpty) return;

    // البحث عن أحدث طلب معالج
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
      final status = data['status'];
      final isApproved = data['approved'] == true;

      if (status == 'approved' && isApproved) {
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
    safeDebugPrint(
        '➡️ Navigating to dashboard based on latest approved request');

    // إلغاء الاشتراك أولاً
    _deviceRequestsSubscription?.cancel();

    // تأخير بسيط لضمان استقرار الواجهة
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      try {
        context.go('/dashboard');
        safeDebugPrint('✅ Successfully navigated to dashboard');
      } catch (e) {
        safeDebugPrint('❌ Navigation error: $e');
        // Fallback: محاولة أخرى
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/dashboard');
        }
      }
    }
  }

/* Future<void> _navigateToDashboard() async {
  safeDebugPrint('➡️ Navigating directly to dashboard based on approved request');
  
  // إظهار رسالة للمستخدم
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('navigating_to_dashboard'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // إلغاء الاشتراك أولاً
  _deviceRequestsSubscription?.cancel();
  
  // تأخير لرؤية الرسالة
  await Future.delayed(const Duration(seconds: 2));
  
  if (mounted) {
    // الانتقال مباشرة دون أي تحقق
    context.go('/dashboard');
    
    // تأكيد الانتقال
    safeDebugPrint('✅ Successfully navigated to dashboard');
  }
}
 */
/*   Future<void> _handleApprovedRequest() async {
    safeDebugPrint('🔄 Handling approved request');
    _checkAttempts = 0;
    await _checkLicenseRepeatedly();
  }
 */

  /*  Future<void> _checkLicenseRepeatedly() async {
    if (_checkAttempts >= _maxCheckAttempts) {
      safeDebugPrint('❌ Max check attempts reached');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('license_check_timeout'.tr())),
        );
      }
      return;
    }

    _checkAttempts++;
    safeDebugPrint('🔄 Checking license status attempt $_checkAttempts');

    try {
      final status = await _licenseService.getCurrentUserLicenseStatus();
      
      if (status.isValid) {
        safeDebugPrint('✅ License is valid after $_checkAttempts attempts');
        if (mounted) {
          await _loadData(navigateIfValid: true);
        }
        return;
      }

      safeDebugPrint('⏳ License not yet valid, waiting...');
      await Future.delayed(const Duration(seconds: 2));
      await _checkLicenseRepeatedly();
    } catch (e) {
      safeDebugPrint('❌ Error checking license status: $e');
      await Future.delayed(const Duration(seconds: 2));
      await _checkLicenseRepeatedly();
    }
  }
 */
  @override
  void dispose() {
    _deviceRequestsSubscription?.cancel();
    super.dispose();
  }

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
      await _diagnoseDeviceData();

      if (!mounted) return;
      setState(() {
        _licenseStatus = status;
        _isLoading = false;
      });

      safeDebugPrint(
          'License status: isValid=${status.isValid}, usedDevices=${status.usedDevices}, maxDevices=${status.maxDevices}');

      if (navigateIfValid && status.isValid) {
        safeDebugPrint('✅ Navigating to dashboard');
        final wasMounted = mounted;

        Future.delayed(const Duration(milliseconds: 500), () {
          if (wasMounted && mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      safeDebugPrint('Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

/*   Future<void> _loadDevices() async {
    if (_resolvedLicenseId == null) return;
    final devices = await _service.getRegisteredDevices(_resolvedLicenseId!);
    if (!mounted) return;
    setState(() => _devices = devices);
  }
 */

  Future<void> _loadDevices() async {
    if (_resolvedLicenseId == null) return;

    try {
      safeDebugPrint('🔄 Loading devices for license: $_resolvedLicenseId');

      final devices = await _service.getRegisteredDevices(_resolvedLicenseId!);

      safeDebugPrint('📊 Loaded ${devices.length} devices');

      if (!mounted) return;
      setState(() => _devices = devices);
    } catch (e) {
      safeDebugPrint('❌ Error loading devices: $e');

      if (!mounted) return;
      setState(() => _devices = []);
    }
  }

  Future<void> _diagnoseDeviceData() async {
    try {
      safeDebugPrint('🔍 Diagnosing device data...');

      // فحص بيانات الترخيص
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(_resolvedLicenseId!)
          .get();

      if (licenseDoc.exists) {
        final licenseData = licenseDoc.data()!;
        final devices = licenseData['devices'] as List<dynamic>? ?? [];

        safeDebugPrint('📋 License devices count: ${devices.length}');
        safeDebugPrint('📋 Local devices count: ${_devices.length}');

        for (int i = 0; i < devices.length; i++) {
          safeDebugPrint('Device $i: ${devices[i]}');
        }
      }

      // فحص بيانات المستخدم
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userDevices = userData['deviceIds'] as List<dynamic>? ?? [];
          safeDebugPrint('👤 User devices count: ${userDevices.length}');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Diagnosis error: $e');
    }
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      final currentFingerprint = await DeviceFingerprint.generate();
      if (!mounted) return;
      setState(() => _currentDeviceId = currentFingerprint);
    } catch (e) {
      safeDebugPrint('Error loading current device ID: $e');
    }
  }

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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.grey[400],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'license_info'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                        child: ListTile(
                          title: Text(
                              device['deviceName'] ?? 'unknown_device'.tr()),
                          subtitle: _buildDeviceInfoSubtitle(device, isCurrent),
                          trailing: !isCurrent
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeviceDeleteDialog(device),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _licenseStatus!.usedDevices < _licenseStatus!.maxDevices
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      } else if (date is String) {
        return date;
      }
      return date.toString();
    } catch (e) {
      return 'unknown_date'.tr();
    }
  }

  Future<void> _registerCurrentDevice() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final success =
        await _service.registerDeviceFingerprint(_resolvedLicenseId!);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_registered_successfully'.tr())),
        );
        _loadDevices();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_register_device'.tr())),
        );
      }
    }
  }
/* 
  Future<void> _unregisterDevice(String fingerprint) async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unregister_device'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('confirm_unregister_device'.tr()),
            const SizedBox(height: 8),
            Text(
              'auto_register_warning'.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
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
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final success = await _service.unregisterDevice(_resolvedLicenseId!, fingerprint);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('device_unregistered_successfully'.tr())),
          );
          await _loadData(navigateIfValid: false);
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('failed_to_unregister_device'.tr())),
          );
        }
      }
    }
  }
 */

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
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('user_not_authenticated'.tr())),
        );
      }
      return;
    }

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      safeDebugPrint('🔍 Searching for device with fingerprint: $fingerprint');

      // ✅ البحث عن الجهاز المراد حذفه
      final deviceToRemove = _devices.firstWhere(
        (device) => device['fingerprint'] == fingerprint,
        orElse: () => {},
      );

      if (deviceToRemove.isEmpty) {
        throw Exception('Device not found in local list');
      }

      safeDebugPrint('✅ Found device to remove: $deviceToRemove');

      // ✅ حذف الجهاز من الترخيص في Firestore
      await FirebaseFirestore.instance
          .collection('licenses')
          .doc(_resolvedLicenseId!)
          .update({
        'devices': FieldValue.arrayRemove([deviceToRemove]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      safeDebugPrint('✅ Device removed from license successfully');

      // ✅ حذف الجهاز من المستخدم في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'deviceIds': FieldValue.arrayRemove([deviceToRemove]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      safeDebugPrint('✅ Device removed from user successfully');

      // ✅ تحديث الواجهة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_unregistered_successfully'.tr())),
        );

        // إعادة تحميل البيانات
        await _loadData(navigateIfValid: false);
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

  Future<void> _requestNewDeviceSlot() async {
    if (_resolvedLicenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_not_found'.tr())),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final currentStatus = await _licenseService.getCurrentUserLicenseStatus();
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

      final requestRef = FirebaseFirestore.instance
          .collection('device_requests')
          .doc(requestId);

      await requestRef.set({
        'userId': user.uid,
        'licenseId': licenseId,
        'reason': userReason,
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'processed': false,
        'status': 'pending',
        'userEmail': user.email,
        'userDisplayName': user.displayName,
        'deviceName': deviceInfo['deviceName'] ?? 'unknown_device'.tr(),
        'platform': deviceInfo['platform'] ?? 'unknown_platform'.tr(),
        'browser': deviceInfo['browser'] ?? 'unknown_browser'.tr(),
        'fingerprint': currentFingerprint,
        'model': deviceInfo['model'] ?? 'unknown_model'.tr(),
        'os': deviceInfo['os'] ?? 'unknown_os'.tr(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_submitted'.tr())),
        );
        // إعادة تحميل المستمع للطلبات
        _deviceRequestsSubscription?.cancel();
        _listenForDeviceRequests(); // استدعاء الدالة المحدثة
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

  Widget _buildDeviceInfoSubtitle(Map<String, dynamic> device, bool isCurrent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (device['platform'] != null)
          Text('${device['platform']} ${device['model'] ?? ''}'),
        if (device['os'] != null) Text('${'os'.tr()}: ${device['os']}'),
        if (device['browser'] != null && device['browser'] != 'N/A')
          Text('${'browser'.tr()}: ${device['browser']}'),
        if (device['registeredAt'] != null)
          Text('${'registered'.tr()}: ${_formatDate(device['registeredAt'])}'),
        if (device['lastActive'] != null)
          Text('${'last_active'.tr()}: ${_formatDate(device['lastActive'])}'),
        if (isCurrent)
          Text('current_device'.tr(),
              style: const TextStyle(color: Colors.green)),
      ],
    );
  }

/*   Future<void> _showDeviceDeleteDialog(Map<String, dynamic> device) async {
    final fingerprint = device['fingerprint'];

    await showDialog(
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
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unregisterDevice(fingerprint);
            },
            child: Text('unregister'.tr()),
          ),
        ],
      ),
    );
  }
 */

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
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
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

  Widget _buildDeviceInfoCard(Map<String, dynamic> device) {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device['deviceName'] ?? 'unknown_device'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (device['platform'] != null)
              Text('${'platform'.tr()}: ${device['platform']}'),
            if (device['model'] != null)
              Text('${'model'.tr()}: ${device['model']}'),
            if (device['os'] != null) Text('${'os'.tr()}: ${device['os']}'),
            if (device['browser'] != null && device['browser'] != 'N/A')
              Text('${'browser'.tr()}: ${device['browser']}'),
            if (device['registeredAt'] != null)
              Text(
                  '${'registered'.tr()}: ${_formatDate(device['registeredAt'])}'),
          ],
        ),
      ),
    );
  }
}
