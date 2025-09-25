/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() => _isLoading = true);
    _deviceId = await _licenseService.getDeviceUniqueId();
    setState(() => _isLoading = false);
  }

  Future<void> _submitRequest() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_required'.tr())),
      );

      return;
    }

    final isConnected = await _licenseService.checkInternetConnection();
  if (!isConnected && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('no_internet'.tr())),
    );
    return;
  }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('confirm_request'.tr()),
            content: Text('confirm_request_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('confirm'.tr()),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_sent'.tr())),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'request_error'.tr()}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDeviceCount = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDuration = value!);
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */
/* 

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(String message, String route) async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    
    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : (value) {
                      if (value != null) {
                        setState(() => _selectedDeviceCount = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : (value) {
                      if (value != null) {
                        setState(() => _selectedDuration = value);
                      }
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  Map<String, dynamic>? _currentLicenseRequest;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _initializeLicenseRequest();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } catch (e) {
      // Handle error if needed
      print('Error loading device ID: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeLicenseRequest() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      // جلب الطلب الحالي للمستخدم
      final existingRequest = await _licenseService.getUserLicenseRequest(user.uid);

      if (mounted) {
        setState(() {
          _currentLicenseRequest = existingRequest;
        });
      }

      // إذا الطلب موجود وحالته "approved" توجيه مباشر
      if (existingRequest != null && existingRequest['status'] == 'approved') {
        if (mounted) {
          context.go('/dashboard');
        }
      }

      // يمكن الاستماع لتغييرات الطلب في حال وجود دعم Stream (اختياري)
      _listenToLicenseStatus(user.uid);

    } catch (e) {
      print('Error initializing license request: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // استماع لتغير حالة الترخيص (اختياري، لتحويل المستخدم تلقائيًا)
  void _listenToLicenseStatus(String userId) {
    _licenseService.licenseRequestStream(userId).listen((docSnapshot) {
      final data = docSnapshot.data();
      if (data != null) {
        setState(() {
          _currentLicenseRequest = data;
        });
        if (data['status'] == 'approved' && mounted) {
          context.go('/dashboard');
        }
      }
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(String message, String route) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    // منع إرسال طلب جديد إذا يوجد طلب معلق
    if (_currentLicenseRequest != null && _currentLicenseRequest!['status'] == 'pending') {
      await _showErrorSnackBar('existing_request_pending'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      // تحديث حالة الطلب الحالي
      await _initializeLicenseRequest();

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _listenToLicenseStatus();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToLicenseStatus() {
    final user = _auth.currentUser;
    if (user == null) return;

    _licenseService.licenseRequestStream(user.uid).listen((docSnapshot) {
      if (!mounted) return;

      final data = docSnapshot.data() as Map<String, dynamic>?;
      safeDebugPrint('License Request Data: $data'); // تحقق من البيانات

      if (data != null) {
        final status = data['status'] as String?;
        if (status == 'approved') {
          safeDebugPrint('License approved, navigating to dashboard');

          // عند الموافقة، تحويل المستخدم للوحة التحكم
          context.go('/dashboard');
        }
      }
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(
      String message, String route) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

/*   Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // فحص وجود طلب ترخيص معلق مسبقاً
      final hasPending = await _licenseService.hasPendingLicenseRequests();
      if (hasPending) {
        await _showErrorSnackBar('existing_request_pending'.tr());
        return;
      }

      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  } */

/* Future<void> _submitRequest() async {
  if (!mounted || _isLoading) return;

  final user = _auth.currentUser;
  if (user == null) {
    await _showErrorSnackBar('login_required'.tr());
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 1. تحقق من وجود طلب سابق "موافق عليه"
    final approvedRequestsSnapshot = await _licenseService._firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    if (approvedRequestsSnapshot.docs.isNotEmpty) {
      // الطلب موافق عليه سابقاً => توجه للـ dashboard مع رسالة نجاح
      await _showSuccessSnackBarAndRedirect('request_already_approved'.tr(), '/dashboard');
      return;
    }

    // 2. تحقق من وجود طلب "معلق" قيد الانتظار
    final pendingRequestsSnapshot = await _licenseService._firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pendingRequestsSnapshot.docs.isNotEmpty) {
      await _showErrorSnackBar('existing_request_pending'.tr());
      return;
    }

    // 3. تحقق من الاتصال بالإنترنت
    final isConnected = await _licenseService.checkInternetConnection();
    if (!isConnected) {
      await _showErrorSnackBar('no_internet'.tr());
      return;
    }

    final confirm = await _showConfirmationDialog();
    if (!confirm) return;

    // 4. إرسال طلب جديد
    await _licenseService.requestNewLicense(
      userId: user.uid,
      durationMonths: _selectedDuration,
      maxDevices: _selectedDeviceCount,
    );

    await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
  } catch (e) {
    await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
 */

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasApproved =
          await _licenseService.hasApprovedLicenseRequest(user.uid);
      if (hasApproved) {
        await _showSuccessSnackBarAndRedirect(
            'request_already_approved'.tr(), '/dashboard');
        return;
      }

      final hasPending =
          await _licenseService.hasPendingLicenseRequest(user.uid);
      if (hasPending) {
        await _showErrorSnackBar('existing_request_pending'.tr());
        return;
      }

      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */

/* 
// lib/widgets/auth/user_license_request.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 1;
  bool _isLoading = false;

  StreamSubscription? _requestSub;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _startListeningToRequest();
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) setState(() => _deviceId = deviceId);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startListeningToRequest() {
    final user = _auth.currentUser;
    if (user == null) return;

    _requestSub =
        _licenseService.licenseRequestStream(user.uid).listen((docSnapshot) {
      if (!mounted) return;

      final data = docSnapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'approved') {
        // إظهار Snack ثم التحويل للوحة التحكم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_approved'.tr())),
        );
        // ننتظر لحظة بسيطة حتى يرى المستخدم الاشعار
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          context.go('/dashboard');
        });
      } else if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_rejected'.tr())),
        );
      }
    }, onError: (e) {
      safeDebugPrint('licenseRequest stream error: $e');
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. تحقق من وجود طلب سابق للمستخدم
      final lastRequest = await _licenseService.getUserLicenseRequest(user.uid);
      if (lastRequest != null) {
        final status = lastRequest['status'] as String? ?? '';
        if (status == 'pending') {
          await _showErrorSnackBar('existing_request_pending'.tr());
          return;
        } else if (status == 'approved') {
          // لو تمت الموافقة مسبقًا، حول للداشبورد وأخبره
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('request_already_approved'.tr())));
          // ننتظر قليلاً ثم نذهب
          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) context.go('/dashboard');
          return;
        }
        // إذا حالة سابقة كانت rejected أو غير موجودة — مسموح بالإرسال
      }

      // 2. تحقق من وجود اتصال
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      // 3. أرسل الطلب (الـ service سيمنع التكرار بالمرة إذا وجد طلب pending)
      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('request_sent'.tr())));

      // نترك المستخدم في الصفحة أو نعيده للداشبورد حسب متطلباتك:
      // هنا نعيده للوحة التحكم بعد فترة قصيرة
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final msg = e is LicenseException ? e.message : e.toString();
      await _showErrorSnackBar('${'request_error'.tr()}: $msg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/license_service.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int _selectedDuration = 1;
  int _selectedDevices = 1;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('license_request'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDurationSelector(),
            const SizedBox(height: 20),
            _buildDeviceSelector(),
            const SizedBox(height: 20),
            _buildDeviceWarning(),
            const Spacer(),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('subscription_duration'.tr(),
            style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<int>(
          value: _selectedDuration,
          items: [1, 3, 6, 12].map((months) {
            return DropdownMenuItem(
              value: months,
              child: Text('$months ${'months'.tr()}'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedDuration = value!),
        ),
      ],
    );
  }

  Widget _buildDeviceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('number_of_devices'.tr(),
            style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<int>(
          value: _selectedDevices,
          items: [1, 2, 3, 5].map((deviceCount) {
            return DropdownMenuItem(
              value: deviceCount,
              child: Text('$deviceCount ${'devices'.tr()}'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedDevices = value!),
        ),
      ],
    );
  }

  Widget _buildDeviceWarning() {
    return FutureBuilder<int>(
      future: _getCurrentDevicesCount(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data! >= _selectedDevices) {
          return Text(
            'device_limit_warning'.tr(args: [_selectedDevices.toString()]),
            style: const TextStyle(color: Colors.orange),
          );
        }
        return const SizedBox();
      },
    );
  }

  Future<int> _getCurrentDevicesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final license = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (license.docs.isEmpty) return 0;
    return (license.docs.first['deviceIds'] as List).length;
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        child: _isSubmitting
            ? const CircularProgressIndicator()
            : Text('submit_request'.tr()),
      ),
    );
  }

/*   Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final requestId = _licenseService.generateStandardizedId(isLicense: false);
      
      await _firestore.collection('license_requests').doc(requestId).set({
        'id': requestId,
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp()(),
      });
if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('request_submitted_successfully'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('submit_error'.tr(args: [e.toString()]))),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
 */
  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // التحقق من وجود طلب معلق
      final pendingRequest = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingRequest.docs.isNotEmpty) {
        throw Exception('existing_request_pending'.tr());
      }

      final requestId =
          _licenseService.generateStandardizedId(isLicense: false);

      await _firestore.collection('license_requests').doc(requestId).set({
        'id': requestId,
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('request_submitted_successfully'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('submit_error'.tr(args: [e.toString()]))),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/license_service.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int _selectedDuration = 1;
  int _selectedDevices = 1;
  bool _isSubmitting = false;
  int _currentDevicesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceCount();
  }

  Future<void> _loadCurrentDeviceCount() async {
    try {
      final count = await _getCurrentDevicesCount();
      if (mounted) {
        setState(() => _currentDevicesCount = count);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('load_device_count_error'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_request'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDurationSelector(),
                const SizedBox(height: 10),
                _buildDeviceSelector(),
                const SizedBox(height: 10),
                _buildDeviceWarning(),
                const SizedBox(height: 12),
                _buildRequestInfoCard(),
                const SizedBox(height: 12), // Replaced Spacer with fixed height
                _buildSubmitButton(),
                const SizedBox(height: 8), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'subscription_duration'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedDuration,
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
                onChanged: (value) =>
                    setState(() => _selectedDuration = value!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'number_of_devices'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedDevices,
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
        padding: const EdgeInsets.all(16.0),
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
          ],
        ),
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

/*   Future<int> _getCurrentDevicesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final license = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (license.docs.isEmpty) return 0;
    return (license.docs.first.data()['deviceIds'] as List? ?? []).length;
  } */

  Future<int> _getCurrentDevicesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      // First check if user has a license key in their document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final licenseKey = userDoc.data()?['licenseKey'] as String?;

      if (licenseKey == null || licenseKey.isEmpty) return 0;

      // Then get the license document
      final licenseDoc =
          await _firestore.collection('licenses').doc(licenseKey).get();

      if (!licenseDoc.exists) return 0;

      final deviceIds = licenseDoc.data()?['deviceIds'] as List? ?? [];
      return deviceIds.length;
    } catch (e) {
      safeDebugPrint('Error getting device count: $e');
      return 0;
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _isSubmitting ? null : _submitRequest,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'submit_request'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

/*   Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('user_not_logged_in'.tr());
      }

      // Check for existing pending request
      final pendingRequest = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingRequest.docs.isNotEmpty) {
        throw Exception('existing_request_pending'.tr());
      }

      // Check if user already has an active license
      final activeLicense = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeLicense.docs.isNotEmpty) {
        final expiryDate = activeLicense.docs.first['expiryDate'] as Timestamp?;
        if (expiryDate != null && expiryDate.toDate().isAfter(DateTime.now())) {
          throw Exception('active_license_exists'.tr());
        }
      }

      // Create new request
      final requestId =
          _licenseService.generateStandardizedId(isLicense: false);

      await _firestore.collection('license_requests').doc(requestId).set({
        'id': requestId,
        'userId': user.uid,
        'userEmail': user.email,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success message and optionally navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('request_submitted_successfully'.tr()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Refresh the device count after submission
      await _loadCurrentDeviceCount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('submit_error'.tr(args: [e.toString()])),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
 */

  Future<void> _submitRequest() async {
    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw LicenseException('user_not_logged_in'.tr());
      }

      // Validate request doesn't exist
      final requestQuery = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        throw LicenseException('existing_request_pending'.tr());
      }

      // Validate no active license
      final licenseQuery = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (licenseQuery.docs.isNotEmpty) {
        final expiryDate =
            licenseQuery.docs.first.get('expiryDate') as Timestamp?;
        if (expiryDate?.toDate().isAfter(DateTime.now()) ?? false) {
          throw LicenseException('active_license_exists'.tr());
        }
      }

      // Create and submit new request
      final requestId =
          _licenseService.generateStandardizedId(isLicense: false);
      final batch = _firestore.batch();

      final requestRef =
          _firestore.collection('license_requests').doc(requestId);
      batch.set(requestRef, {
        'id': requestId,
        'userId': user.uid,
        'userEmail': user.email,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      // Show success and update UI
      _showSuccessMessage();
      await _loadCurrentDeviceCount();
    } on FirebaseException catch (e) {
      _handleError('firebase_error'.tr(args: [e.code]));
    } on LicenseException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('unknown_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('request_submitted_successfully'.tr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'ok'.tr(),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _handleError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
  }
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => message;
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
  final _secureStorage = const FlutterSecureStorage();

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
      .collectionGroup('licenses')
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

  // تحقق من وجود ترخيص فعال
  final licenseSnapshot = await _firestore
      .collection('licenses')
      .where('userId', isEqualTo: user.uid)
      .where('isActive', isEqualTo: true)
      .get();

  final hasActiveLicense = licenseSnapshot.docs.any((doc) {
    final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
    return expiry != null && expiry.isAfter(DateTime.now());
  });

  if (hasActiveLicense) {
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

      if (_hasSubmittedRequest) {
        safeDebugPrint('Active license found, redirecting to dashboard');
        Future.microtask(() {
          if (mounted) context.go('/dashboard');
        });
      }
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
      String deviceId;

      if (kIsWeb) {
        // استخدام التخزين الآمن للويب
        deviceId =
            await _secureStorage.read(key: 'deviceId') ?? 'web_${_uuid.v4()}';
        await _secureStorage.write(key: 'deviceId', value: deviceId);
      } else {
        // باقي المنصات: Android / iOS
        final androidInfo = await _deviceInfo.androidInfo;
        final iosInfo = await _deviceInfo.iosInfo;

        if (defaultTargetPlatform == TargetPlatform.android) {
          deviceId = 'android_${androidInfo.id}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          deviceId = 'ios_${iosInfo.identifierForVendor ?? _uuid.v4()}';
        } else {
          deviceId = 'unknown_${_uuid.v4()}';
        }
      }

      if (mounted) {
        setState(() => _currentDeviceId = deviceId);
      }
    } catch (e) {
      safeDebugPrint('Error loading device ID: $e');
      if (mounted) {
        setState(() => _currentDeviceId = 'error_${_uuid.v4()}');
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

  /*   Future<void> _submitRequest() async {
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

      // تأكد من عدم وجود طلب سابق معلق أو مقبول
      final existingRequestSnapshot = await _firestore
          .collection('license_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      if (existingRequestSnapshot.docs.isNotEmpty) {
        _showErrorSnackBar('existing_request_found'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      final batch = _firestore.batch();

      final newRequestRef =
          _firestore.collection('license_requests').doc(_uuid.v4());

      batch.set(newRequestRef, {
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'deviceCount': _selectedDevices,
        'deviceIds': [_currentDeviceId],
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _hasSubmittedRequest = true;
        _isSubmitting = false;
        _isPending = true;
      });

      _showSuccessMessage();
      await _loadCurrentDeviceCount();
    } catch (e) {
      _showErrorSnackBar('request_failed'.tr(args: [e.toString()]));
      setState(() => _isSubmitting = false);
    }
  }
 */

/*   Future<void> _submitRequest() async {
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
        // final requestId = doc.id;

        if (status == 'pending') {
          hasActiveRequest = true;
          break; // إذا يوجد طلب معلق فلا تنشئ طلب جديد
        }

        if (status == 'approved') {
          // تحقق من الرخصة المرتبطة بهذا الطلب
          // نفترض أن ترخيص مرتبط بـ license_requests عبر userId وليس requestId
          // لذا نبحث عن رخصة نشطة للمستخدم

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
            // لا تسمح بإنشاء طلب جديد طالما الترخيص فعال وغير منتهي
            hasActiveRequest = true;
            break;
          }
          // إذا الترخيص منتهي لا تمنع إنشاء طلب جديد
        }
      }

      if (hasActiveRequest) {
        _showErrorSnackBar('existing_request_found'.tr());
        setState(() => _isSubmitting = false);
        return;
      }

      // إنشاء الطلب الجديد
      final batch = _firestore.batch();

      final newRequestRef =
          _firestore.collection('license_requests').doc(_uuid.v4());

      batch.set(newRequestRef, {
        'userId': user.uid,
        'durationMonths': _selectedDuration,
        'maxDevices': _selectedDevices,
        'deviceIds': [_currentDeviceId],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _hasSubmittedRequest = true;
        _isSubmitting = false;
        _isPending = true;
      });

      _showSuccessMessage();
      await _loadCurrentDeviceCount();
    } catch (e) {
      _showErrorSnackBar('request_failed'.tr(args: [e.toString()]));
      setState(() => _isSubmitting = false);
    }
  }
 */

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
        .where('status', whereIn: ['pending', 'approved'])
        .get();

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
    final newRequestRef = _firestore.collection('license_requests').doc(requestNumber);

    batch.set(newRequestRef, {
      'requestId': requestNumber, // إضافة حقل requestId للتوثيق
      'userId': user.uid,
      'durationMonths': _selectedDuration,
      'maxDevices': _selectedDevices,
      'deviceIds': [_currentDeviceId],
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'displayName': user.displayName ?? user.email?.split('@').first ?? 'User',
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
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
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

/*   void _showSuccessMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('request_successful'.tr()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }
 */
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
