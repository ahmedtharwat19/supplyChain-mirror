/* import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      setState(() => _errorMessage = 'admin_check_failed'.tr());
    }
  }

/*   Future<void> _processRequest(String requestId, bool approve) async {
    if (!mounted || !_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Request document not found');
      }

      final requestData = requestDoc.data()!;

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: requestData['userId'],
          durationMonths: requestData['durationMonths'],
          maxDevices: requestData['requestedDevices'],
        );
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                approve ? 'request_approved'.tr() : 'request_rejected'.tr()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'processing_error'.tr());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        safeDebugPrint('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  } */

 Future<void> _processRequest(String requestId, bool approve) async {
  if (!mounted || !_isAdmin) return;

  setState(() {
    _isProcessing = true;
    _errorMessage = null;
  });

  try {
    final requestDoc = await _firestore.collection('license_requests').doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Request document not found');

    final requestData = requestDoc.data()!;
    safeDebugPrint('requestedDevices: ${requestData['maxDevices']}');


    if (approve) {
      // إنشاء الترخيص وتفعيل المستخدم
      await _licenseService.generateLicenseKey(
        userId: requestData['userId'],
        durationMonths: requestData['durationMonths'],
        maxDevices: requestData['maxDevices'],
      );
final int durationMonths = (requestData['durationMonths'] ?? 1).toInt();
      // تفعيل حساب المستخدم
      await _firestore.collection('users').doc(requestData['userId']).update({
        'isActive': true,
      'license_expiry': DateTime.now().add(Duration(days: 30 * durationMonths)),
      });
    }

    await _firestore.collection('license_requests').doc(requestId).update({
      'status': approve ? 'approved' : 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
      'processedBy': _licenseService.currentUserId,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'request_approved'.tr() : 'request_rejected'.tr())),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _errorMessage = 'processing_error'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  Widget _buildIndexErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Index Required',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This query requires a Firestore index to be created.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://console.firebase.google.com');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not launch browser'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Create Index'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_management'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _isAdmin
          ? _buildMainContent(context)
          : _buildAdminRestricted(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    safeDebugPrint(_errorMessage);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'pending_requests'.tr()),
              Tab(text: 'licenses'.tr()),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRequestsList(context),
                _buildLicensesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminRestricted(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text(
            'admin_access_required'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'only_admins_can_access'.tr(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
            return _buildIndexErrorWidget(context);
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestItem(request);
          },
        );
      },
    );
  }

  Widget _buildRequestItem(QueryDocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${data['userId']}'),
            Text('Devices: ${data['maxDevices']}'),
            Text('Duration: ${data['durationMonths']} months'),
            Text('Date: ${_formatDate(data['createdAt']?.toDate())}'),
            const SizedBox(height: 16),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _processRequest(request.id, false),
                    child: Text('reject'.tr()),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _processRequest(request.id, true),
                    child: Text('approve'.tr()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data?.docs ?? [];

        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            return _buildLicenseItem(license);
          },
        );
      },
    );
  }

  Widget _buildLicenseItem(QueryDocumentSnapshot license) {
    final data = license.data() as Map<String, dynamic>;
    final expiryDate = data['expirationDate']?.toDate();
    final isExpired = expiryDate != null && DateTime.now().isAfter(expiryDate);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('License Key: ${data['licenseKey']}'),
            Text('User: ${data['userId']}'),
            Text(
                'Devices: ${(data['deviceIds'] as List?)?.length ?? 0}/${data['maxDevices']}'),
            Text('Expires: ${_formatDate(expiryDate)}'),
            Row(
              children: [
                const Text('Status: '),
                Chip(
                  label: Text(
                    data['isActive'] == true
                        ? isExpired
                            ? 'Expired'
                            : 'Active'
                        : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: data['isActive'] == true
                      ? isExpired
                          ? Colors.orange
                          : Colors.green
                      : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
 */

/*

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isAdmin = false;
/* bool _hasPendingRequests = false;
  StreamSubscription? _pendingRequestsSub;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; */
  
  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      setState(() => _errorMessage = 'admin_check_failed'.tr());
      if (mounted) {
        final message = 'Error: ${e.toString()}';
        setState(() => _errorMessage = message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processRequest(String requestId, bool approve) async {
    if (!mounted || !_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('Request document not found');

      final requestData = requestDoc.data()!;
      final int durationMonths = (requestData['durationMonths'] ?? 1).toInt();

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: requestData['userId'],
          durationMonths: durationMonths,
          maxDevices: requestData['maxDevices'],
        );

        await _firestore.collection('users').doc(requestData['userId']).update({
          'isActive': true,
          'license_expiry':
              DateTime.now().add(Duration(days: 30 * durationMonths)),
        });
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  approve ? 'request_approved'.tr() : 'request_rejected'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'processing_error'.tr());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      if (mounted) {
        final message = 'Error: ${e.toString()}';
        setState(() => _errorMessage = message);
        safeDebugPrint('message : $message');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 🔹 عرض رسائل الخطأ الخاصة بفقدان الـ Index
  Widget _buildIndexErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Index Required',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('This query requires a Firestore index to be created.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://console.firebase.google.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Create Index'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
            return _buildIndexErrorWidget();
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

/*         return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text('User: ${data['userId']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Devices: ${data['maxDevices']}'),
                    Text('Duration: ${data['durationMonths']} months'),
                  ],
                ),
                trailing: _isProcessing
                    ? const CircularProgressIndicator()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _processRequest(request.id, false),
                            child: Text('reject'.tr()),
                          ),
                          ElevatedButton(
                            onPressed: () => _processRequest(request.id, true),
                            child: Text('approve'.tr()),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
       */
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final userId = data['userId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    margin: EdgeInsets.all(8.0),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(),
                    ),
                  );
                }

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                final userName = userData['name'] ?? 'N/A';
                final userEmail = userData['email'] ?? 'N/A';
                final userImage = userData['photoUrl'];

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          userImage != null ? NetworkImage(userImage) : null,
                      child:
                          userImage == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(userName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: $userEmail'),
                        Text('Devices: ${data['maxDevices']}'),
                        Text('Duration: ${data['durationMonths']} months'),
                      ],
                    ),
                    trailing: _isProcessing
                        ? const CircularProgressIndicator()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _processRequest(request.id, false),
                                child: Text('reject'.tr()),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    _processRequest(request.id, true),
                                child: Text('approve'.tr()),
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

/*   Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired = expiryDate != null && DateTime.now().isAfter(expiryDate);

            return FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('devices')
                  .where('licenseId', isEqualTo: license.id)
                  .get(),
              builder: (context, deviceSnap) {
                final currentDevices = deviceSnap.data?.docs.length ?? 0;
                final maxDevices = data['maxDevices'] ?? 0;

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('License Key: ${data['licenseKey']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${data['userId']}'),
                        Text('Devices: $currentDevices / $maxDevices'),
                        Text('Expires: ${_formatDate(expiryDate)}'),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        data['isActive'] == true
                            ? isExpired
                                ? 'Expired'
                                : 'Active'
                            : 'Inactive',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: data['isActive'] == true
                          ? isExpired
                              ? Colors.orange
                              : Colors.green
                          : Colors.red,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
 */

  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired =
                expiryDate != null && DateTime.now().isAfter(expiryDate);

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(data['userId']).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    margin: EdgeInsets.all(8.0),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(),
                    ),
                  );
                }

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                final userName = userData['name'] ?? 'N/A';
                final userEmail = userData['email'] ?? 'N/A';
                final userImage = userData['photoUrl'];
                final isActiveUser = userData['isActive'] ?? false;

                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('devices')
                      .where('licenseId', isEqualTo: license.id)
                      .get(),
                  builder: (context, deviceSnap) {
                    final currentDevices = deviceSnap.data?.docs.length ?? 0;
                    final maxDevices = data['maxDevices'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userImage != null
                              ? NetworkImage(userImage)
                              : null,
                          child: userImage == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(userName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: $userEmail'),
                            Text('License Key: ${data['licenseKey']}'),
                            Text('Devices: $currentDevices / $maxDevices'),
                            Text('Expires: ${_formatDate(expiryDate)}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Chip(
                              label: Text(
                                isActiveUser
                                    ? isExpired
                                        ? 'Expired'
                                        : 'Active'
                                    : 'Inactive',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: isActiveUser
                                  ? isExpired
                                      ? Colors.orange
                                      : Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_management'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _isAdmin
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_errorMessage != null) // <-- عرض الخطأ إذا موجود
                    Container(
                      width: double.infinity,
                      color: Colors.red.withAlpha(75),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  TabBar(
                    tabs: [
                      Tab(text: 'pending_requests'.tr()),
                      Tab(text: 'licenses'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRequestsList(),
                        _buildLicensesList(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _buildAdminRestricted(),
    );
  }

  Widget _buildAdminRestricted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text('admin_access_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('only_admins_can_access'.tr()),
        ],
      ),
    );
  }
}


*/

/*


match /users/{userId} {
  allow create: if isSignedIn();

  // السماح بقراءة المستند الخاص أو لأي أدمن
  allow read: if isSignedIn() && (request.auth.uid == userId || isAdmin());

  // السماح بالتحديث أو الحذف للمستخدم نفسه فقط إذا كان مفعلًا
  allow update, delete: if isSignedIn() && request.auth.uid == userId && isUserActive();
}


*/

/* 

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';


class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;

  bool _isProcessing = false;
  bool _isAdmin = false;
  String? _errorMessage;
StreamSubscription? _pendingRequestsSub;
//bool _hasPendingRequests = false;
  // أزلنا _pendingRequestsSub لأنه غير مستخدم
  // أو يمكنك تفعيله لو أردت استخدامه

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
      
  // إذا كان المستخدم أدمن، اشترك في الطلبات المعلقة
  _pendingRequestsSub = _firestore
      .collection('license_requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snapshot) {
        if (!mounted) return;
        final hasPending = snapshot.docs.isNotEmpty;

        setState(() {
          _hasPendingRequests = hasPending; // لازم تعرف المتغير
        });

        // إذا فيه طلب جديد، اعرض إشعار Snackbar
        if (hasPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هناك طلب جديد في انتظار الموافقة'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });

  }

  @override
void dispose() {
  _pendingRequestsSub?.cancel();
  super.dispose();
}


  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      _showError('admin_check_failed'.tr(), e);
    }
  }

  Future<void> _processRequest(String requestId, bool approve) async {
    if (!_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc = await _firestore
          .collection('license_requests')
          .doc(requestId)
          .get();
      if (!requestDoc.exists) throw Exception('request_not_found'.tr());

      final data = requestDoc.data()!;
      final durationMonths =
          ((data['durationMonths'] ?? 1) as num).toInt(); // ✅ تصحيح النوع

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: data['userId'],
          durationMonths: durationMonths,
          maxDevices: ((data['maxDevices'] ?? 1) as num).toInt(), // ✅ تصحيح النوع
        );

        await _firestore.collection('users').doc(data['userId']).update({
          'isActive': true,
          'license_expiry':
              DateTime.now().add(Duration(days: 30 * durationMonths)),
        });
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      _showSnack(
          approve ? 'request_approved'.tr() : 'request_rejected'.tr());
    } catch (e) {
      _showError('processing_error'.tr(), e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildIndexErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('index_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('create_index_message'.tr()),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url =
                  Uri.parse('https://console.firebase.google.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text('create_index'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return snapshot.error.toString().contains('index')
              ? _buildIndexErrorWidget()
              : Center(
                  child:
                      Text('${'error'.tr()}: ${snapshot.error}'),
                );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final userId = data['userId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return _loadingCard();
                }

                final userData = userSnap.data!.data()
                        as Map<String, dynamic>? ??
                    {};
                return _requestCard(userData, data, request.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired = expiryDate != null &&
                DateTime.now().isAfter(expiryDate);

            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(data['userId']).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return _loadingCard();

                final userData = userSnap.data!.data()
                        as Map<String, dynamic>? ??
                    {};
                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('devices')
                      .where('licenseId', isEqualTo: license.id)
                      .get(),
                  builder: (context, deviceSnap) {
                    final currentDevices =
                        deviceSnap.data?.docs.length ?? 0;
                    return _licenseCard(userData, data, currentDevices,
                        expiryDate, isExpired);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> userData,
      Map<String, dynamic> requestData, String requestId) {
    final userName = userData['name'] ?? 'N/A';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'email'.tr()}: $userEmail'),
            Text(
                '${'devices'.tr()}: ${((requestData['maxDevices'] ?? 0) as num).toInt()}'),
            Text(
                '${'duration'.tr()}: ${((requestData['durationMonths'] ?? 0) as num).toInt()} ${'months'.tr()}'),
          ],
        ),
        trailing: _isProcessing
            ? const CircularProgressIndicator()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () =>
                        _processRequest(requestId, false),
                    child: Text('reject'.tr()),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _processRequest(requestId, true),
                    child: Text('approve'.tr()),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _licenseCard(
      Map<String, dynamic> userData,
      Map<String, dynamic> licenseData,
      int currentDevices,
      DateTime? expiryDate,
      bool isExpired) {
    final userName = userData['name'] ?? 'N/A';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];
    final isActiveUser = userData['isActive'] ?? false;
    final maxDevices =
        ((licenseData['maxDevices'] ?? 0) as num).toInt(); // ✅ تصحيح النوع

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'email'.tr()}: $userEmail'),
            Text('${'license_key'.tr()}: ${licenseData['licenseKey']}'),
            Text('${'devices'.tr()}: $currentDevices / $maxDevices'),
            Text('${'expires'.tr()}: ${_formatDate(expiryDate)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            isActiveUser
                ? (isExpired ? 'expired'.tr() : 'active'.tr())
                : 'inactive'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isActiveUser
              ? (isExpired ? Colors.orange : Colors.green)
              : Colors.red,
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(),
      ),
    );
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showError(String title, dynamic error) {
    final message = '$title\n${error.toString()}';
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
    
        title: Text('license_management'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
     
      body: _isAdmin
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.withAlpha(75),
                      padding: const EdgeInsets.all(8),
                      child: Text(_errorMessage!,
                          style:
                              const TextStyle(color: Colors.red)),
                    ),
                  TabBar(
                    tabs: [
                      Tab(text: 'pending_requests'.tr()),
                      Tab(text: 'licenses'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRequestsList(),
                        _buildLicensesList(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _buildAdminRestricted(),
    );
  }

  Widget _buildAdminRestricted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text('admin_access_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('only_admins_can_access'.tr()),
        ],
      ),
    );
  }
}
 */

/* import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;

  bool _isProcessing = false;
  bool _isAdmin = false;
  bool _hasPendingRequests = false;
  String? _errorMessage;

  StreamSubscription? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
    _listenToPendingRequests();
  }

  /// الاشتراك في الطلبات المعلقة
  void _listenToPendingRequests() {
    _pendingRequestsSub = _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingRequests = snapshot.docs.isNotEmpty;
        });
        // إشعار فوري بالتغيير
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${'pending_requests'.tr()} (${snapshot.docs.length}) ${'updated'.tr()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// التحقق إذا كان المستخدم الحالي Admin
  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      _showError('admin_check_failed'.tr(), e);
    }
  }

  /// معالجة الطلبات (موافقة/رفض)
  Future<void> _processRequest(String requestId, bool approve) async {
    if (!_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('request_not_found'.tr());

      final data = requestDoc.data()!;
      final durationMonths = ((data['durationMonths'] ?? 1) as num).toInt();

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: data['userId'],
          durationMonths: durationMonths,
          maxDevices: data['maxDevices'],
        );

        await _firestore.collection('users').doc(data['userId']).update({
          'isActive': true,
          'license_expiry':
              DateTime.now().add(Duration(days: 30 * durationMonths)),
        });
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      _showSnack(approve ? 'request_approved'.tr() : 'request_rejected'.tr());
    } catch (e) {
      _showError('processing_error'.tr(), e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// عرض خطأ إنشاء Index
  Widget _buildIndexErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('index_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('create_index_message'.tr()),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://console.firebase.google.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text('create_index'.tr()),
          ),
        ],
      ),
    );
  }

  /// قائمة الطلبات المعلقة
  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return snapshot.error.toString().contains('index')
              ? _buildIndexErrorWidget()
              : Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final userId = data['userId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return _loadingCard();
                }

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return _requestCard(userData, data, request.id);
              },
            );
          },
        );
      },
    );
  }

  /// قائمة التراخيص
  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired =
                expiryDate != null && DateTime.now().isAfter(expiryDate);

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(data['userId']).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return _loadingCard();

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('devices')
                      .where('licenseId', isEqualTo: license.id)
                      .get(),
                  builder: (context, deviceSnap) {
                    final currentDevices = deviceSnap.data?.docs.length ?? 0;
                    return _licenseCard(
                        userData, data, currentDevices, expiryDate, isExpired);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// كارت طلب
  Widget _requestCard(Map<String, dynamic> userData,
      Map<String, dynamic> requestData, String requestId) {
    final userName = userData['displayName'] ?? 'N/A';
    final userId = userData['userId'];
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'userId'.tr()}: $userId'),
            Text('${'email'.tr()}: $userEmail'),
            Text('${'devices'.tr()}: ${requestData['maxDevices']}'),
            Text(
                '${'duration'.tr()}: ${requestData['durationMonths']} ${'months'.tr()}'),
          ],
        ),
        trailing: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : SizedBox(
                width: 160, // عدل العرض حسب النصوص اللي عندك
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _processRequest(requestId, false),
                      child: Text('reject'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: () => _processRequest(requestId, true),
                      child: Text('approve'.tr()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// كارت ترخيص
  Widget _licenseCard(
      Map<String, dynamic> userData,
      Map<String, dynamic> licenseData,
      int currentDevices,
      DateTime? expiryDate,
      bool isExpired) {
    final userName = userData['name'] ?? 'N/A';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];
    final isActiveUser = userData['isActive'] ?? false;
    final maxDevices = licenseData['maxDevices'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'email'.tr()}: $userEmail'),
            Text('${'license_key'.tr()}: ${licenseData['licenseKey']}'),
            Text('${'devices'.tr()}: $currentDevices / $maxDevices'),
            Text('${'expires'.tr()}: ${_formatDate(expiryDate)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            isActiveUser
                ? (isExpired ? 'expired'.tr() : 'active'.tr())
                : 'inactive'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isActiveUser
              ? (isExpired ? Colors.orange : Colors.green)
              : Colors.red,
        ),
      ),
    );
  }

  /// كارت تحميل
  Widget _loadingCard() {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(),
      ),
    );
  }

  /// عرض SnackBar
  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// عرض خطأ
  void _showError(String title, dynamic error) {
    final message = '$title\n${error.toString()}';
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  void dispose() {
    _pendingRequestsSub?.cancel();
    super.dispose();
  }

  /// عرض الصفحة
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_management'.tr()),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  // عرض الطلبات
                },
              ),
              if (_isAdmin && _hasPendingRequests)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _isAdmin
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.withAlpha(75),
                      padding: const EdgeInsets.all(8),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  TabBar(
                    tabs: [
                      Tab(text: 'pending_requests'.tr()),
                      Tab(text: 'licenses'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRequestsList(),
                        _buildLicensesList(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _buildAdminRestricted(),
    );
  }

  Widget _buildAdminRestricted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text('admin_access_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('only_admins_can_access'.tr()),
        ],
      ),
    );
  }
}
 */
/* 
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';


class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;

  bool _isProcessing = false;
  bool _isAdmin = false;
  bool _hasPendingRequests = false;
  String? _errorMessage;

  StreamSubscription? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
    _listenToPendingRequests();
  }

  /// إعادة تحميل البيانات
  Future<void> _refreshData() async {
    await _checkAdminStatus();
    setState(() {});
  }

Future<void> _submitRequest() async {
  setState(() => _isProcessing = true);
  try {
    // شغلك هنا
  } finally {
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }
}

  /// الاشتراك في الطلبات المعلقة
  void _listenToPendingRequests() {
    _pendingRequestsSub = _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  /// التحقق إذا كان المستخدم الحالي Admin
  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      _showError('admin_check_failed'.tr(), e);
    }
  }

  /// معالجة الطلبات
  Future<void> _processRequest(String requestId, bool approve) async {
    if (!_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('request_not_found'.tr());

      final data = requestDoc.data()!;
      final durationMonths = ((data['durationMonths'] ?? 1) as num).toInt();

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: data['userId'],
          durationMonths: durationMonths,
          maxDevices: data['maxDevices'],
        );

        await _firestore.collection('users').doc(data['userId']).update({
          'isActive': true,
          'license_expiry':
              DateTime.now().add(Duration(days: 30 * durationMonths)),
        });
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      _showSnack(approve ? 'request_approved'.tr() : 'request_rejected'.tr());
    } catch (e) {
      _showError('processing_error'.tr(), e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// واجهة خطأ إنشاء Index
  Widget _buildIndexErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('index_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('create_index_message'.tr()),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://console.firebase.google.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text('create_index'.tr()),
          ),
        ],
      ),
    );
  }

  /// قائمة الطلبات المعلقة
  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return snapshot.error.toString().contains('index')
              ? _buildIndexErrorWidget()
              : Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final userId = data['userId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return _loadingCard();
                }

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return _requestCard(userData, data, request.id);
              },
            );
          },
        );
      },
    );
  }

  /// قائمة التراخيص
  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired =
                expiryDate != null && DateTime.now().isAfter(expiryDate);

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(data['userId']).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return _loadingCard();

                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('devices')
                      .where('licenseId', isEqualTo: license.id)
                      .get(),
                  builder: (context, deviceSnap) {
                    final currentDevices = deviceSnap.data?.docs.length ?? 0;
                    return _licenseCard(
                        userData, data, currentDevices, expiryDate, isExpired);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// كارت طلب
  Widget _requestCard(Map<String, dynamic> userData,
      Map<String, dynamic> requestData, String requestId) {
    final userName = userData['displayName'] ?? 'N/A';
    final userId = userData['userId'] ?? '';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    userImage != null ? NetworkImage(userImage) : null,
                child: userImage == null ? const Icon(Icons.person) : null,
              ),
              title: Text(userName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${'userId'.tr()}: $userId'),
                  Text('${'email'.tr()}: $userEmail'),
                  Text('${'devices'.tr()}: ${requestData['maxDevices']}'),
                  Text(
                      '${'duration'.tr()}: ${requestData['durationMonths']} ${'months'.tr()}'),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _processRequest(requestId, false),
                  child: Text('reject'.tr()),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _processRequest(requestId, true),
                  child: Text('approve'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// كارت ترخيص
  Widget _licenseCard(
      Map<String, dynamic> userData,
      Map<String, dynamic> licenseData,
      int currentDevices,
      DateTime? expiryDate,
      bool isExpired) {
    final userName = userData['name'] ?? 'N/A';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];
    final isActiveUser = userData['isActive'] ?? false;
    final maxDevices = licenseData['maxDevices'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'email'.tr()}: $userEmail'),
            Text('${'license_key'.tr()}: ${licenseData['licenseKey']}'),
            Text('${'devices'.tr()}: $currentDevices / $maxDevices'),
            Text('${'expires'.tr()}: ${_formatDate(expiryDate)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            isActiveUser
                ? (isExpired ? 'expired'.tr() : 'active'.tr())
                : 'inactive'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isActiveUser
              ? (isExpired ? Colors.orange : Colors.green)
              : Colors.red,
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(),
      ),
    );
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showError(String title, dynamic error) {
    final message = '$title\n${error.toString()}';
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  void dispose() {
    _pendingRequestsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'license_management'.tr(),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                DefaultTabController.of(context).animateTo(0);
              },
            ),
            if (_isAdmin && _hasPendingRequests)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshData,
        ),
      ],
      body: _isAdmin
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.withAlpha(75),
                      padding: const EdgeInsets.all(8),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Pending Requests'),
                      Tab(text: 'Licenses'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRequestsList(),
                        _buildLicensesList(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _buildAdminRestricted(),
    );
  }

  Widget _buildAdminRestricted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text('admin_access_required'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('only_admins_can_access'.tr()),
        ],
      ),
    );
  }
}
 */
/* 
// lib/widgets/auth/admin_license_management.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This handler must be a top-level function
  // Do any background processing here if needed
  // (No UI code here)
  safeDebugPrint('Handling a background message: ${message.messageId}');
}

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState extends State<AdminLicenseManagementPage>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;

  bool _isProcessing = false;
  bool _isAdmin = false;
  bool _hasPendingRequests = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;
  StreamSubscription? _onMessageSub;
  StreamSubscription? _onMessageOpenedAppSub;

  int _refreshKey = 0; // for forcing StreamBuilders to rebuild

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _licenseService = LicenseService();
    _initNotifications();
    _checkAdminStatus();
    _listenToPendingRequests();
  }

  // init notifications (local + FCM)
  Future<void> _initNotifications() async {
    // initialize local notifications (Android + iOS)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // ensure icon exists

    final DarwinInitializationSettings initializationSettingsIOS =
        const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (payload) {
      // handle notification tapped when app is foreground/background
      // handle navigation if needed
    });

    // background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // request permission (iOS)
    final fcm = FirebaseMessaging.instance;
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.denied) {
      // save token to Firestore
      final token = await fcm.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }

      // listen for token refresh
      fcm.onTokenRefresh.listen((newToken) {
        _saveFcmToken(newToken);
      });
    }

    // foreground messages
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      safeDebugPrint('Received a message while in the foreground!');
      safeDebugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        safeDebugPrint(
            'Message also contained a notification: ${message.notification}');
      }
      _showLocalNotification(message);
      // optionally update UI (refresh pending requests count)
      _refreshPendingCount();
    });

    // when notification opened (app in background -> tapped)
    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      if (data['type'] == 'new_license_request') {
        // switch to pending requests tab (if using tabs)
        if (mounted) {
          DefaultTabController.of(context).animateTo(0);
        }
      }
    });

    // check if app opened from terminated state via notification
    RemoteMessage? initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null &&
        initialMessage.data['type'] == 'new_license_request') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DefaultTabController.of(context).animateTo(0);
      });
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    try {
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
    } catch (e) {
      safeDebugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    //final android = message.notification?.android;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'Notifications for license requests',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = const NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification?.title ?? 'New Notification',
      notification?.body ?? '',
      platformDetails,
      payload: message.data['requestId'] ?? '',
    );
  }

  // listen to pending requests stream to update badge immediately in-app
  void _listenToPendingRequests() {
    _pendingRequestsSub = _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _hasPendingRequests = snapshot.docs.isNotEmpty;
      });
    }, onError: (err) {
      safeDebugPrint('Pending requests stream error: $err');
    });
  }

  Future<void> _refreshData() async {
    // Forcing rebuilds: increment key then setState
    setState(() {
      _refreshKey++;
    });
    await _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isAdmin = userDoc.data()?['isAdmin'] ?? false;
      setState(() {
        _isAdmin = isAdmin;
      });

      if (_isAdmin) {
        await _licenseServiceInit();
      }
    } catch (e) {
      _showError('admin_check_failed'.tr(), e);
    }
  }

  Future<void> _licenseServiceInit() async {
    try {
      await _licenseServiceInitializeSafely();
    } catch (e) {
      safeDebugPrint('LicenseService init failed: $e');
    }
  }

  Future<void> _licenseServiceInitializeSafely() async {
    // license service init could be async; keep it safe
    try {
      await _licenseServiceInitialize();
    } catch (e) {
      safeDebugPrint(e as String?);
    }
  }

  Future<void> _licenseServiceInitialize() async {
    _licenseServiceTryCreate();
  }

  Future<void> _licenseServiceTryCreate() async {
    // ensure license service constructed; your actual license service may differ
    try {
      _licenseServiceConstruct();
    } catch (e) {
      safeDebugPrint(e.toString());
    }
  }

  void _licenseServiceConstruct() {
    // create instance (use your service)
    _licenseServiceInstance();
  }

  void _licenseServiceInstance() {
    // actual construction
    _licenseService = LicenseService();
  }

  // processing request (approve/reject)
  Future<void> _processRequest(String requestId, bool approve) async {
    if (!_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('request_not_found'.tr());

      final data = requestDoc.data()!;
      final durationMonths = ((data['durationMonths'] ?? 1) as num).toInt();
      final maxDevices = ((data['maxDevices'] ?? 1) as num).toInt();

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: data['userId'],
          durationMonths: durationMonths,
          maxDevices: maxDevices,
        );

        await _firestore.collection('users').doc(data['userId']).update({
          'isActive': true,
          'license_expiry':
              DateTime.now().add(Duration(days: 30 * durationMonths)),
        });
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      _showSnack(approve ? 'request_approved'.tr() : 'request_rejected'.tr());
      // بعد المعالجة حدث badge
      _refreshPendingCount();
    } catch (e) {
      _showError('processing_error'.tr(), e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // force refresh pending counter (re-query once)
  Future<void> _refreshPendingCount() async {
    try {
      final snap = await _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      if (!mounted) return;
      setState(() {
        _hasPendingRequests = snap.docs.isNotEmpty;
      });
    } catch (e) {
      safeDebugPrint('refreshPendingCount error: $e');
    }
  }

  // UI cards and lists
  Widget _loadingCard() {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> userData,
      Map<String, dynamic> requestData, String requestId) {
    final userName = userData['name'] ?? userData['displayName'] ?? 'N/A';
    final userId = userData['userId'] ?? requestData['userId'] ?? '';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];

    // Buttons sized, placed under details (not in trailing)
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    userImage != null ? NetworkImage(userImage) : null,
                child: userImage == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${'email'.tr()}: $userEmail',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${'userId'.tr()}: $userId',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                '${'devices'.tr()}: ${((requestData['maxDevices'] ?? 0) as num).toInt()}'),
            const SizedBox(height: 4),
            Text(
                '${'duration'.tr()}: ${((requestData['durationMonths'] ?? 0) as num).toInt()} ${'months'.tr()}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _processRequest(requestId, false),
                  child: Text('reject'.tr()),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _processRequest(requestId, true),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('approve'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _licenseCard(
      Map<String, dynamic> userData,
      Map<String, dynamic> licenseData,
      int currentDevices,
      DateTime? expiryDate,
      bool isExpired) {
    final userName = userData['name'] ?? 'N/A';
    final userEmail = userData['email'] ?? 'N/A';
    final userImage = userData['photoUrl'];
    final isActiveUser = userData['isActive'] ?? false;
    final maxDevices = ((licenseData['maxDevices'] ?? 0) as num).toInt();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userImage != null ? NetworkImage(userImage) : null,
          child: userImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'email'.tr()}: $userEmail'),
            Text('${'license_key'.tr()}: ${licenseData['licenseKey']}'),
            Text('${'devices'.tr()}: $currentDevices / $maxDevices'),
            Text('${'expires'.tr()}: ${_formatDate(expiryDate)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            isActiveUser
                ? (isExpired ? 'expired'.tr() : 'active'.tr())
                : 'inactive'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isActiveUser
              ? (isExpired ? Colors.orange : Colors.green)
              : Colors.red,
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('requests_$_refreshKey'),
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return snapshot.error.toString().contains('index')
              ? Center(child: Text('index_required'.tr()))
              : Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) return Center(child: Text('no_requests'.tr()));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final userId = data['userId'] as String? ?? '';
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return _loadingCard();
                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return _requestCard(userData, data, request.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('licenses_$_refreshKey'),
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${'error'.tr()}: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) return Center(child: Text('no_licenses'.tr()));
        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            final data = license.data() as Map<String, dynamic>;
            final expiryDate = data['expirationDate']?.toDate();
            final isExpired =
                expiryDate != null && DateTime.now().isAfter(expiryDate);
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(data['userId']).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return _loadingCard();
                final userData =
                    userSnap.data!.data() as Map<String, dynamic>? ?? {};
                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('devices')
                      .where('licenseId', isEqualTo: license.id)
                      .get(),
                  builder: (context, deviceSnap) {
                    final currentDevices = deviceSnap.data?.docs.length ?? 0;
                    return _licenseCard(
                        userData, data, currentDevices, expiryDate, isExpired);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showError(String title, dynamic error) {
    final message = '$title\n${error.toString()}';
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  void dispose() {
    _pendingRequestsSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'license_management'.tr(),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // show pending requests tab
                DefaultTabController.of(context).animateTo(0);
              },
            ),
            if (_isAdmin && _hasPendingRequests)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
      ],
      body: _isAdmin
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.withAlpha(75),
                      padding: const EdgeInsets.all(8),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  TabBar(tabs: [
                    Tab(text: 'pending_requests'.tr()),
                    Tab(text: 'licenses'.tr())
                  ]),
                  Expanded(
                      child: TabBarView(children: [
                    _buildRequestsList(),
                    _buildLicensesList()
                  ])),
                ],
              ),
            )
          : _buildAdminRestricted(),
    );
  }

  Widget _buildAdminRestricted() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.admin_panel_settings, size: 64),
        const SizedBox(height: 16),
        Text('admin_access_required'.tr(),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('only_admins_can_access'.tr()),
      ]),
    );
  }
}
 */


/*   Widget _buildActiveLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data!.docs;
        if (licenses.isEmpty) {
          return Center(child: Text('no_active_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            return _buildLicenseCard(license);
          },
        );
      },
    );
  }
 */

/*   Future<void> _processRequest(String requestId, bool approve) async {
    try {
      if (approve) {
        final requestDoc = await _firestore
            .collection('license_requests')
            .doc(requestId)
            .get();
        final requestData = requestDoc.data() as Map<String, dynamic>;

        await _licenseService.createLicense(
          userId: requestData['userId'],
          durationMonths: requestData['durationMonths'],
          maxDevices: requestData['maxDevices'],
          requestId: requestId,
        );
      } else {
        await _firestore.collection('license_requests').doc(requestId).update({
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      // افترض أن الترخيص مرتبط بالطلب، قم بتحديث الترخيص هنا:
      final licenseQuery = await _firestore
          .collection('licenses')
          .where('originalRequestId', isEqualTo: requestId)
          .get();

      for (var doc in licenseQuery.docs) {
        await doc.reference.update({
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
 */


/*         return Card(
          child: ExpansionTile(
            title: Text(data['licenseKey']),
            subtitle:
                Text('Expires: ${_formatDate(data['expiryDate']?.toDate())}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User: ${userData['displayName']}'),
                    Text('Email: ${userData['email']}'),
                    Text(
                        'Devices: ${(data['deviceIds'] as List).length}/${data['maxDevices']}'),
                    if (data['originalRequestId'] != null)
                      _buildRequestInfo(data['originalRequestId']),
                  ],
                ),
              ),
            ],
          ),
        ); */
    

 // إضافة دالة جديدة لعرض طلبات الأجهزة
/*   Widget _buildDeviceRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('device_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_pending_device_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildDeviceRequestCard(request);
          },
        );
      },
    );
  }
 */
  

/*   Widget _buildRequestCard(DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(data['userId']).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: CircularProgressIndicator());
        }

        final userDoc = userSnapshot.data;
        if (userDoc == null || userDoc.data() == null) {
          return const ListTile(title: Text('User data not found'));
        }
        final userData = userDoc.data() as Map<String, dynamic>;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: userData['photoUrl'] != null
                  ? NetworkImage(userData['photoUrl'])
                  : null,
              child: userData['photoUrl'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(userData['displayName'] ?? 'Unknown User'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'devices'.tr()}: ${data['maxDevices']}'),
                Text(
                    '${'duration'.tr()}: ${data['durationMonths']} ${'months'.tr()}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _processRequest(request.id, true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _processRequest(request.id, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 */

/* Widget _buildRequestCard(DocumentSnapshot request) {
  final data = request.data() as Map<String, dynamic>;
  
  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(data['userId']).get(),
    builder: (context, userSnapshot) {
      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return const ListTile(
          title: LinearProgressIndicator(),
        );
      }

      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
        return ListTile(
          title: Text('user_not_found'.tr()),
          subtitle: Text('User ID: ${data['userId']}'),
        );
      }

      final userData = userSnapshot.data!.data() as Map<String, dynamic>;

      return Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: userData['photoUrl'] != null
                ? NetworkImage(userData['photoUrl'])
                : null,
            child: userData['photoUrl'] == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(userData['displayName'] ?? 'unknown_user'.tr()),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'email'.tr()}: ${userData['email'] ?? 'N/A'}'),
              Text('${'devices'.tr()}: ${data['maxDevices']}'),
              Text('${'duration'.tr()}: ${data['durationMonths']} ${'months'.tr()}'),
              Text('${'request_date'.tr()}: ${_formatDate(data['createdAt']?.toDate())}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _processRequest(request.id, true),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _processRequest(request.id, false),
              ),
            ],
          ),
        ),
      );
    },
  );
}

 */

/* Widget _buildRequestCard(DocumentSnapshot request) {
  final data = request.data() as Map<String, dynamic>;
  
  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(data['userId']).get(),
    builder: (context, userSnapshot) {
      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          margin: EdgeInsets.all(8),
          child: ListTile(
            title: LinearProgressIndicator(),
          ),
        );
      }

      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('user_not_found'.tr()),
            subtitle: Text('User ID: ${data['userId']}'),
          ),
        );
      }

      final userData = userSnapshot.data!.data() as Map<String, dynamic>;

      // الحصول على معلومات الترخيص الحالي للمستخدم
      return FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('licenses')
            .where('userId', isEqualTo: data['userId'])
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(),
        builder: (context, licenseSnapshot) {
          if (licenseSnapshot.connectionState == ConnectionState.waiting) {
            return _buildUserCard(userData, data, null);
          }

          LicenseInfo? licenseInfo;
          if (licenseSnapshot.hasData && licenseSnapshot.data!.docs.isNotEmpty) {
            final licenseData = licenseSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            licenseInfo = LicenseInfo(
              maxDevices: licenseData['maxDevices'] ?? 1,
              usedDevices: (licenseData['devices'] as List?)?.length ?? 0,
              expiryDate: (licenseData['expiryDate'] as Timestamp?)?.toDate(),
              isActive: licenseData['isActive'] ?? false,
            );
          }

          return _buildUserCard(userData, data, licenseInfo);
        },
      );
    },
  );
}
 */

/* Widget _buildUserCard(Map<String, dynamic> userData, Map<String, dynamic> requestData, LicenseInfo? licenseInfo) {
  return Card(
    margin: const EdgeInsets.all(8),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات المستخدم
          Row(
            children: [
              CircleAvatar(
                backgroundImage: userData['photoUrl'] != null
                    ? NetworkImage(userData['photoUrl'])
                    : null,
                child: userData['photoUrl'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData['displayName'] ?? 'unknown_user'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      userData['email'] ?? 'N/A',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          const Divider(),
          
          // معلومات الطلب
          Text(
            'request_details'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('requested_devices'.tr(), '${requestData['maxDevices']}'),
          _buildInfoRow('duration'.tr(), '${requestData['durationMonths']} ${'months'.tr()}'),
          _buildInfoRow('request_date'.tr(), _formatDate(requestData['createdAt']?.toDate())),
          if (requestData['reason'] != null)
            _buildInfoRow('reason'.tr(), requestData['reason']),
          
          const SizedBox(height: 12),
          const Divider(),
          
          // معلومات الترخيص الحالي
          Text(
            'current_license'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          
          if (licenseInfo != null) ...[
            _buildInfoRow('status'.tr(), licenseInfo.isActive ? 'active'.tr() : 'inactive'.tr()),
            _buildInfoRow('devices_used'.tr(), '${licenseInfo.usedDevices}/${licenseInfo.maxDevices}'),
            if (licenseInfo.expiryDate != null)
              _buildInfoRow('expiry_date'.tr(), _formatDate(licenseInfo.expiryDate)),
          ] else {
            _buildInfoRow('status'.tr(), 'no_active_license'.tr()),
          },
          
          const SizedBox(height: 16),
          
          // أزرار التحكم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text('approve'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _processRequest(requestData.id, true),
              ),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: Text('reject'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _processRequest(requestData.id, false),
              ),
              
              if (licenseInfo != null && licenseInfo.isActive)
                ElevatedButton.icon(
                  icon: const Icon(Icons.block, size: 18),
                  label: Text('deactivate'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _deactivateUserLicense(licenseInfo, requestData['userId']),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
 */


/* Future<void> _deactivateUserLicense(LicenseInfo licenseInfo, String userId) async {
  try {
    final licenseQuery = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in licenseQuery.docs) {
      await doc.reference.update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_deactivated'.tr())),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deactivation_failed'.tr())),
      );
    }
    safeDebugPrint('Error deactivating license: $e');
  }
}
 */



import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import '../../services/license_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class LicenseInfo {
  final int maxDevices;
  final int usedDevices;
  final DateTime? expiryDate;
  final bool isActive;
  final String? licenseKey;

  LicenseInfo({
    required this.maxDevices,
    required this.usedDevices,
    this.expiryDate,
    required this.isActive,
    this.licenseKey,
  });

  // دالة مساعدة لإنشاء LicenseInfo من بيانات Firestore
  factory LicenseInfo.fromFirestore(Map<String, dynamic> data, String docId) {
    return LicenseInfo(
      maxDevices: data['maxDevices'] ?? 1,
      usedDevices: (data['devices'] as List?)?.length ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      licenseKey: docId,
    );
  }
}

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final LicenseService _licenseService;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    testQuery();
  }

// أضف هذا قبل تعريف class AdminLicenseManagementPage


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        title: 'license_management'.tr(),
        isDashboard: false, // لأن هذه صفحة فرعية وليست صفحة رئيسية
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'pending_requests'.tr()),
                Tab(text: 'active_licenses'.tr()),
                Tab(text: 'device_requests'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPendingRequestsList(),
                  _buildActiveLicensesList(),
                    _buildDeviceRequestsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDeviceRequestsList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('device_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text('error_loading_requests'.tr()));
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(child: Text('no_pending_device_requests'.tr()));
      }

      final requests = snapshot.data!.docs;
      return ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildDeviceRequestCard(request);
        },
      );
    },
  );
}

  // دالة لبناء بطاقة طلب الجهاز
  Widget _buildDeviceRequestCard(DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    
    return FutureBuilder(
      future: Future.wait([
        _firestore.collection('users').doc(data['userId']).get(),
        _firestore.collection('licenses').doc(data['licenseId']).get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: CircularProgressIndicator());
        }

        final results = snapshot.data as List<DocumentSnapshot>;
        final userDoc = results[0];
        final licenseDoc = results[1];

        if (!userDoc.exists || !licenseDoc.exists) {
          return const ListTile(title: Text('Data not found'));
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final licenseData = licenseDoc.data() as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(userData['displayName'] ?? 'Unknown User'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'license'.tr()}: ${licenseData['licenseKey']}'),
                Text('${'reason'.tr()}: ${data['reason']}'),
                Text('${'current_devices'.tr()}: ${(licenseData['devices'] as List).length}/${licenseData['maxDevices']}'),
                Text('${'request_date_args'.tr()}: ${_formatDate(data['createdAt']?.toDate())}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _processDeviceRequest(request.id, true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _processDeviceRequest(request.id, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // دالة معالجة طلب الجهاز
  Future<void> _processDeviceRequest(String requestId, bool approve) async {
    try {
      final requestDoc = await _firestore.collection('device_requests').doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>;
      
      if (approve) {
        // الموافقة على الطلب - زيادة عدد الأجهزة المسموحة
        final licenseId = requestData['licenseId'];
        final licenseDoc = await _firestore.collection('licenses').doc(licenseId).get();
        final licenseData = licenseDoc.data() as Map<String, dynamic>;
        
        final currentMaxDevices = licenseData['maxDevices'] ?? 1;
        
        await _firestore.collection('licenses').doc(licenseId).update({
          'maxDevices': currentMaxDevices + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // تحديث حالة الطلب
        await _firestore.collection('device_requests').doc(requestId).update({
          'status': 'approved',
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': 'admin', // يمكن استبدالها بـ user ID الأدمن
        });

        // إرسال إشعار للمستخدم
        await _sendNotificationToUser(
          requestData['userId'],
          'device_request_approved_title'.tr(),
          'device_request_approved_message'.tr(),
        );

      } else {
        // رفض الطلب
        await _firestore.collection('device_requests').doc(requestId).update({
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': 'admin',
          'rejectionReason': 'rejected_by_admin'.tr(),
        });

        // إرسال إشعار للمستخدم
        await _sendNotificationToUser(
          requestData['userId'],
          'device_request_rejected_title'.tr(),
          'device_request_rejected_message'.tr(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'request_approvedA'.tr() : 'request_rejected'.tr())),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('processing_failed'.tr())),
        );
      }
      safeDebugPrint('Error processing device request: $e');
    }
  }

  // دالة إرسال الإشعارات للمستخدم
  Future<void> _sendNotificationToUser(String userId, String title, String body) async {
    try {
      // هنا يمكنك إضافة كود إرسال الإشعارات عبر FCM
      // مثال:
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      
      safeDebugPrint('Notification sent to user: ${userData['email']}');
      safeDebugPrint('Title: $title, Body: $body');
      
    } catch (e) {
      safeDebugPrint('Error sending notification: $e');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }


  Widget _buildPendingRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('no_pending_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request);
          },
        );
      },
    );
  }

Widget _buildRequestCard(DocumentSnapshot request) {
  final data = request.data() as Map<String, dynamic>;
  final requestId = request.id;

  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(data['userId']).get(),
    builder: (context, userSnapshot) {
      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          margin: EdgeInsets.all(8),
          child: ListTile(
            title: LinearProgressIndicator(),
          ),
        );
      }

      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('user_not_found'.tr()),
            subtitle: Text('User ID: ${data['userId']}'),
          ),
        );
      }

      final userData = userSnapshot.data!.data() as Map<String, dynamic>;

      // الحصول على معلومات الترخيص الحالي للمستخدم
      return FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('licenses')
            .where('userId', isEqualTo: data['userId'])
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(),
        builder: (context, licenseSnapshot) {
          if (licenseSnapshot.connectionState == ConnectionState.waiting) {
            return _buildUserCard(userData, data, null, requestId);
          }

          LicenseInfo? licenseInfo;
          if (licenseSnapshot.hasData && licenseSnapshot.data!.docs.isNotEmpty) {
            final licenseDoc = licenseSnapshot.data!.docs.first;
            final licenseData = licenseDoc.data() as Map<String, dynamic>;
            licenseInfo = LicenseInfo.fromFirestore(licenseData, licenseDoc.id);
          }

           return _buildUserCard(userData, data, licenseInfo, requestId);
        },
      );
    },
  );
}

Widget _buildUserCard(Map<String, dynamic> userData, Map<String, dynamic> requestData, LicenseInfo? licenseInfo, String requestId) {
  return Card(
    margin: const EdgeInsets.all(8),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات المستخدم
          Row(
            children: [
              CircleAvatar(
                backgroundImage: userData['photoUrl'] != null
                    ? NetworkImage(userData['photoUrl'])
                    : null,
                child: userData['photoUrl'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData['displayName'] ?? 'unknown_user'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      userData['email'] ?? 'N/A',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          const Divider(),
          
          // معلومات الطلب
          Text(
            'request_details'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('requested_devices'.tr(), '${requestData['maxDevices']}'),
          _buildInfoRow('duration'.tr(), '${requestData['durationMonths']} ${'months'.tr()}'),
          _buildInfoRow('request_date'.tr(), _formatDate(requestData['createdAt']?.toDate())),
          if (requestData['reason'] != null)
            _buildInfoRow('reason'.tr(), requestData['reason']),
          
          const SizedBox(height: 12),
          const Divider(),
          
          // معلومات الترخيص الحالي
          Text(
            'current_license'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          
 if (licenseInfo != null) 
  Column(
    children: [
      _buildInfoRow('status'.tr(), licenseInfo.isActive ? 'active'.tr() : 'inactive'.tr()),
      _buildInfoRow('devices_used'.tr(), '${licenseInfo.usedDevices}/${licenseInfo.maxDevices}'),
      if (licenseInfo.expiryDate != null)
        _buildInfoRow('expiry_date'.tr(), _formatDate(licenseInfo.expiryDate)),
      if (licenseInfo.licenseKey != null)
        _buildInfoRow('license_key'.tr(), licenseInfo.licenseKey!),
    ],
  )
else 
  _buildInfoRow('status'.tr(), 'no_active_license'.tr()),
          
          const SizedBox(height: 16),
          
          // أزرار التحكم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text('approve'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _processRequest(requestId, true),
              ),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: Text('reject'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _processRequest(requestId, false),
              ),
              
              if (licenseInfo != null && licenseInfo.isActive)
                ElevatedButton.icon(
                  icon: const Icon(Icons.block, size: 18),
                  label: Text('deactivate'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _deactivateUserLicense(licenseInfo, requestData['userId']),
                ),
            ],
          ),
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
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    ),
  );
}

Future<void> _deactivateUserLicense(LicenseInfo licenseInfo, String userId) async {
  try {
    if (licenseInfo.licenseKey == null) return;
    
    await _firestore.collection('licenses').doc(licenseInfo.licenseKey).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
      'deactivatedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('license_deactivated'.tr())),
      );
      
      // إعادة تحميل البيانات لتحديث الواجهة
      setState(() {});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deactivation_failed'.tr())),
      );
    }
    safeDebugPrint('Error deactivating license: $e');
  }
}


  Future<void> _deactivateLicense(String licenseId, String userId) async {
    try {
      // 1. تحديث الترخيص إلى غير نشط
      await _firestore.collection('licenses').doc(licenseId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      // 2. مسح الجلسات / الأجهزة من قاعدة البيانات الخاصة بالمستخدم
      await _firestore.collection('users').doc(userId).update({
        'deviceIds': [],
        'isActive': false, // خطوة 3 مدموجة هنا
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License deactivated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }


  Future<void> _processRequest(String requestId, bool approve) async {
    try {
      if (approve) {
        final requestDoc = await _firestore
            .collection('license_requests')
            .doc(requestId)
            .get();
        final requestData = requestDoc.data() as Map<String, dynamic>;

        await _licenseService.createLicense(
          userId: requestData['userId'],
          durationSeconds: requestData['durationMonths'],
          maxDevices: requestData['maxDevices'],
          requestId: requestId,
        );
      } else {
        // ❌ فقط في حالة الرفض، نحدّث الطلب ونلغي الترخيص المرتبط
        await _firestore.collection('license_requests').doc(requestId).update({
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
        });

        // ❌ ابحث عن ترخيص مرتبط وقم بإلغائه إن وجد
        final licenseQuery = await _firestore
            .collection('licenses')
            .where('originalRequestId', isEqualTo: requestId)
            .get();

        for (var doc in licenseQuery.docs) {
          await doc.reference.update({
            'isActive': false,
            'deactivatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }


 /*  Widget _buildActiveLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          safeDebugPrint('Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('no_active_licenses'.tr()));
        }

        final licenses = snapshot.data!.docs;
        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            return _buildLicenseCard(license);
          },
        );
      },
    );
  }
 */

Widget _buildActiveLicensesList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('licenses')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text('error_loading_licenses'.tr()));
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(child: Text('no_active_licenses'.tr()));
      }

      final licenses = snapshot.data!.docs;
      return ListView.builder(
        itemCount: licenses.length,
        itemBuilder: (context, index) {
          final license = licenses[index];
          return _buildLicenseCard(license);
        },
      );
    },
  );
}

/*   Widget _buildLicenseCard(DocumentSnapshot license) {
    final data = license.data() as Map<String, dynamic>;
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(data['userId']).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: CircularProgressIndicator());
        }

        final userDoc = userSnapshot.data;
        if (userDoc == null || userDoc.data() == null) {
          return const ListTile(title: Text('User data not found'));
        }
        final userData = userDoc.data() as Map<String, dynamic>;
        return Card(
          child: ExpansionTile(
            title: Text(data['licenseKey']),
            subtitle:
                Text('Expires: ${_formatDate(data['expiryDate']?.toDate())}'),
            trailing: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Deactivate License',
              onPressed: () => _deactivateLicense(license.id, data['userId']),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User: ${userData['displayName']}'),
                    Text('Email: ${userData['email']}'),
                    Text(
                        'Devices: ${(data['deviceIds'] != null ? (data['deviceIds'] as List).length : 0)}/${data['maxDevices']}'),
                    if (data['originalRequestId'] != null)
                      _buildRequestInfo(data['originalRequestId']),
                  ],
                ),
              ),
            ],
          ),
        );
  },
    );
  }
 */

Widget _buildLicenseCard(DocumentSnapshot license) {
  final data = license.data() as Map<String, dynamic>;
  
  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(data['userId']).get(),
    builder: (context, userSnapshot) {
      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return const Card(child: LinearProgressIndicator());
      }

      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
        return Card(
          child: ListTile(
            title: Text('user_not_found'.tr()),
            subtitle: Text('User ID: ${data['userId']}'),
          ),
        );
      }

      final userData = userSnapshot.data!.data() as Map<String, dynamic>;

      return Card(
        margin: const EdgeInsets.all(8),
        child: ExpansionTile(
          title: Text(data['licenseKey'] ?? 'unknown_license'.tr()),
          subtitle: Text('${'expires'.tr()}: ${_formatDate(data['expiryDate']?.toDate())}'),
          trailing: IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'deactivate_license'.tr(),
            onPressed: () => _deactivateLicense(license.id, data['userId']),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${'user'.tr()}: ${userData['displayName']}'),
                  Text('${'email'.tr()}: ${userData['email']}'),
                  Text('${'devices'.tr()}: ${(data['devices'] as List?)?.length ?? 0}/${data['maxDevices']}'),
                  Text('${'created'.tr()}: ${_formatDate(data['createdAt']?.toDate())}'),
                  if (data['originalRequestId'] != null)
                    _buildRequestInfo(data['originalRequestId']),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildRequestInfo(String requestId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('license_requests').doc(requestId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final doc = snapshot.data;
        if (doc == null || doc.data() == null) {
          return const Text('Request data not found');
        }
        final requestData = doc.data() as Map<String, dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text('Original Request: $requestId'),
            Text(
                'Submitted: ${_formatDate(requestData['createdAt']?.toDate())}'),
          ],
        );
      },
    );
  }

/*   String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  } */
  // أضف هذا في initState أو في زر مؤقت للاختبار
void testQuery() {
  _firestore.collection('device_requests').get().then(
    (querySnapshot) {
      debugPrint("نجح الاستعلام، عدد المستندات: ${querySnapshot.docs.length}");
    },
  ).catchError((error) {
    debugPrint("فشل الاستعلام بالخطأ: $error"); // هذا هو الخطأ الحقيقي!
  });
}
}
