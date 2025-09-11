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
                      color: Colors.orange.withAlpha(75),
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
                                style: const TextStyle(color: Colors.orange),
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
                      ElevatedButton(
                        onPressed: _licenseStatus!.usedDevices <
                                _licenseStatus!.maxDevices
                            ? _registerCurrentDevice
                            : null,
                        child: Text('register_current_device'.tr()),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _requestNewDeviceSlot,
                        child: Text('request_new_slot'.tr()),
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
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
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
