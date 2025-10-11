/* import 'dart:async';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/subscription_notifier.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

enum DashboardView { short, long }

class DashboardPageState extends State<DashboardPage> {
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _licenseStatusSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? subscriptionTimeLeft;
  Timer? _timer;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};
  Map<String, dynamic>? userData;
  bool isAdmin = false;

  bool isLoading = true;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  final DashboardStats _stats = DashboardStats.empty();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription? _notificationSubscription;

  String? userId;
  String? userName;
  List<String> userCompanyIds = [];

  @override
  void initState() {
    super.initState();
    safeDebugPrint('🔄 DashboardPage initState called');

    _initializeData();
    _checkSubscriptionStatus();
    _startListeningToUserChanges();
    _checkInitialNotification();
    _setupLicenseStatusListener();
    _testExpiryDate();
    _checkLicenseExpiryStatus();
    _saveExpiryDateToLocalStorage();
    _listenForNewDeviceRequests();
    _listenForNewLicenseRequests();
    _debugAdminStatus();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadSettings(); // تحميل الإعدادات أولاً
      await _debugAndFixSettings(); // ثم تصحيحها إذا لزم الأمر
      _checkAndFixSettings(); // فحص إضافي
    });
  }

  Future<void> _loadUserData() async {
    final data = await HiveService.getUserData();
    if (mounted) {
      setState(() {
        userData = data;
        isAdmin = data?['isAdmin'] == true;
      });
    }
  }

  void _listenForNewLicenseRequests() {
    _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();

        if (createdAt == null) return;

        final now = DateTime.now();
        final difference = now.difference(createdAt);

        if (difference.inSeconds < 10) {
          final userName = doc['displayName'];
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📝${'new_license_request'.tr()} $userName'),
              action: SnackBarAction(
                label: 'view'.tr(),
                onPressed: () {
                  DefaultTabController.of(context).animateTo(0);
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    });
  }

  void _listenForNewDeviceRequests() {
    _firestore
        .collection('device_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final createdAt = (doc['createdAt'] as Timestamp).toDate();

        final now = DateTime.now();
        final difference = now.difference(createdAt);

        if (difference.inSeconds < 10) {
          final userName = doc['displayName'];
          final licenseId = doc['licenseId'];
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '📱 ${'request_device_from'.tr()} $userName ${'licence_id'.tr()} $licenseId'),
              action: SnackBarAction(
                label: 'view'.tr(),
                onPressed: () {
                  DefaultTabController.of(context).animateTo(2);
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    });
  }

  Future<void> _saveExpiryDateToLocalStorage() async {
    try {
      final expiryDate = await _getExpiryDateFromFirebase();
      if (expiryDate != null) {
        await HiveService.cacheData(
            'expiry_date', expiryDate.toIso8601String());
        safeDebugPrint('💾 Expiry date saved to Hive: $expiryDate');
      }
    } catch (e) {
      safeDebugPrint('❌ Error saving expiry date to Hive: $e');
    }
  }

  Future<DateTime?> _getExpiryDateFromLocalStorage() async {
    try {
      safeDebugPrint('📦 Getting expiry date from Hive');
      final expiryString = await HiveService.getCachedData('expiry_date');

      if (expiryString != null) {
        safeDebugPrint('📦 Found expiry date in Hive: $expiryString');
        return DateTime.parse(expiryString);
      } else {
        safeDebugPrint('❌ No expiry date found in Hive');
      }
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from Hive: $e');
    }
    return null;
  }

  Widget _buildTimeLeftBar() {
    safeDebugPrint(
        '📊 Building time left bar. isExpiringSoon: $isSubscriptionExpiringSoon, timeLeft: $subscriptionTimeLeft');

    if (!isSubscriptionExpiringSoon ||
        subscriptionTimeLeft == null ||
        subscriptionTimeLeft!.isEmpty) {
      safeDebugPrint('📊 No need to show time left bar');
      return const SizedBox();
    }

    if (subscriptionTimeLeft!.contains('maximum number of devices')) {
      safeDebugPrint('📊 Device limit message, not showing time bar');
      return const SizedBox();
    }

    return FutureBuilder<DateTime?>(
      future: _getExpiryDateFromLocalStorage(),
      builder: (context, dateSnapshot) {
        safeDebugPrint(
            '📅 Date snapshot state: ${dateSnapshot.connectionState}, hasData: ${dateSnapshot.hasData}');

        if (dateSnapshot.connectionState != ConnectionState.done) {
          safeDebugPrint('⏳ Waiting for date snapshot...');
          return const CircularProgressIndicator();
        }

        if (!dateSnapshot.hasData) {
          safeDebugPrint('❌ No expiry date data available');
          return _buildSimpleTimeLeftBar();
        }

        final expiryDate = dateSnapshot.data!;
        final now = DateTime.now();
        final daysLeft = expiryDate.difference(now).inDays;

        Color progressColor;
        if (daysLeft > 7) {
          progressColor = Colors.green;
        } else if (daysLeft > 4) {
          progressColor = Colors.orange;
        } else {
          progressColor = Colors.red;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16, top: 8),
          decoration: BoxDecoration(
            color: progressColor.withAlpha(75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: progressColor.withAlpha(75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: progressColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('license_expiring_soon'),
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tr('license_expiring_message'),
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tr('time_left')}:',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subscriptionTimeLeft!,
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tr('expiry_date')}:',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleTimeLeftBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Text(
        '${tr('license_expiring_soon')}: $subscriptionTimeLeft',
        style: TextStyle(
          color: Colors.orange.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<DateTime?> _getExpiryDateFromFirebase() async {
    try {
      safeDebugPrint('🔥 Getting expiry date from Firebase');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final licenseDoc = snapshot.docs.first;
      final expiryTimestamp = licenseDoc.get('expiryDate') as Timestamp?;
      final expiryDate = expiryTimestamp?.toDate();

      if (expiryDate != null) {
        await HiveService.cacheData(
            'expiry_date', expiryDate.toIso8601String());
        safeDebugPrint('💾 Saved expiry date to Hive: $expiryDate');
      }

      return expiryDate;
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from Firebase: $e');
      return null;
    }
  }

  Future<void> _checkLicenseExpiryStatus() async {
    safeDebugPrint('🔍 Checking license expiry status');
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

    // 🟢 الحصول على بيانات المستخدم من Hive أولاً
    final userData = await HiveService.getUserData();
    final bool isAdmin = userData?['isAdmin'] == true;

    setState(() {
      isSubscriptionExpiringSoon = result.isExpiringSoon;
      isSubscriptionExpired = result.isExpired;
      subscriptionTimeLeft = result.timeLeftFormatted;
    });

    safeDebugPrint('📋 License Status:');
    safeDebugPrint('   isValid: ${result.isValid}');
    safeDebugPrint('   isExpiringSoon: $isSubscriptionExpiringSoon');
    safeDebugPrint('   isExpired: $isSubscriptionExpired');
    safeDebugPrint('   timeLeft: $subscriptionTimeLeft');
    safeDebugPrint('   expiryDate: ${result.expiryDate}');
    safeDebugPrint('   isAdmin: $isAdmin'); // ✅ تأكد من ظهور هذه القيمة

    if (!result.isValid &&
        subscriptionTimeLeft != null &&
        subscriptionTimeLeft!.contains('maximum number of devices')) {
      _showDeviceLimitWarning(subscriptionTimeLeft!);
    }

    if (result.expiryDate != null) {
      await HiveService.cacheData(
          'expiry_date', result.expiryDate!.toIso8601String());
      safeDebugPrint('💾 Saved expiry date from check: ${result.expiryDate}');
    }

    // 🟢 التحقق من أن isAdmin true قبل تجاهل التوجيه
    if (isSubscriptionExpired) {
      if (isAdmin) {
        safeDebugPrint(
            '✅ License expired but user is ADMIN → bypassing redirect');
        // لا يتم التوجيه للمسؤول
      } else {
        safeDebugPrint(
            '⏰ License expired and user is NOT admin → redirecting...');
        _redirectToExpiredPage();
      }
    }
  }

  /// Safe redirect to the license-request page (call from async callbacks / listeners)
  void _redirectToExpiredPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // using go_router's navigation (you already import go_router)
      context.go('/license/request');
    });
  }

  void _showDeviceLimitWarning(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  void _testExpiryDate() {
    safeDebugPrint('🧪 Testing expiry date calculation');
    final expiryTimestamp = Timestamp(1757504727, 573000000);
    final expiryDate = expiryTimestamp.toDate();
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    safeDebugPrint('=== LICENSE EXPIRY TEST ===');
    safeDebugPrint('Expiry Date: $expiryDate');
    safeDebugPrint('Current Date: $now');
    safeDebugPrint('Days Left: ${difference.inDays}');
    safeDebugPrint('Is Expiring Soon: ${difference.inDays <= 7}');
    safeDebugPrint('Is Expired: ${difference.isNegative}');
    safeDebugPrint('==========================');
  }

  @override
  void dispose() {
    safeDebugPrint('🗑️ DashboardPage disposed');
    _timer?.cancel();
    _userSubscription?.cancel();
    _refreshController.dispose();
    _notificationSubscription?.cancel();
    _licenseStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    safeDebugPrint('🔄 Initializing data');
    await _migrateFromSharedPreferences();
    await _syncUserData();
    await _reloadUserData();
    await loadSettings();
    await _loadInitialData();
    await _checkIfLicenseExpired();
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      final hasMigrated = await HiveService.getSetting<bool>('has_migrated',
          defaultValue: false);

      if (hasMigrated != true) {
        safeDebugPrint('🔄 Migrating data from SharedPreferences to Hive');

        final prefs = await SharedPreferences.getInstance();

        // هجرة إعدادات Dashboard
        final dashboardView = prefs.getString('prefDashboardView');
        final selectedCards = prefs.getStringList('prefSelectedCards');

        if (dashboardView != null) {
          // إصلاح: حفظ القيمة كما هي دون استخدام .name
          await HiveService.saveSetting('dashboard_view', dashboardView);
          safeDebugPrint('💾 Migrated dashboard_view: $dashboardView');
        }
        if (selectedCards != null) {
          await HiveService.saveSetting('selected_cards', selectedCards);
          safeDebugPrint('💾 Migrated selected_cards: $selectedCards');
        }

        // هجرة تاريخ الانتهاء
        final expiryDate = prefs.getString('expiry_date');
        if (expiryDate != null) {
          await HiveService.cacheData('expiry_date', expiryDate);
          safeDebugPrint('💾 Migrated expiry_date: $expiryDate');
        }

        await HiveService.saveSetting('has_migrated', true);
        safeDebugPrint('✅ Migration completed successfully');
      }
    } catch (e) {
      safeDebugPrint('❌ Error during migration: $e');
    }
  }

  Future<void> _checkIfLicenseExpired() async {
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    // 🟢 التحقق من صلاحية المسؤول هنا أيضاً
    final userData = await HiveService.getUserData();
    final bool isAdmin = userData?['isAdmin'] == true;

    if (result.isExpired && mounted && !isAdmin) {
      safeDebugPrint('⏰ License expired during initialization, redirecting...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/license/request');
        }
      });
    } else if (result.isExpired && isAdmin) {
      safeDebugPrint('✅ Admin user - skipping license expiration redirect');
    }
  }

  void _setupLicenseStatusListener() {
    safeDebugPrint('🔊 Setting up license status listener');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _licenseStatusSubscription = FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      safeDebugPrint('📄 License docs count: ${snapshot.docs.length}');

      final docs = snapshot.docs.where((doc) => doc.exists).toList();
      if (docs.isEmpty) {
        safeDebugPrint('❌ No license found');

        // 🟢 التحقق من صلاحية المسؤول قبل التوجيه
        final userData = await HiveService.getUserData();
        final bool isAdmin = userData?['isAdmin'] == true;

        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/license/request');
            }
          });
        } else {
          safeDebugPrint('✅ Admin user - skipping license check redirect');
        }
        return;
      }

      final now = DateTime.now();
      final activeLicense = docs.firstWhereOrNull((doc) {
        final isActive = doc.get('isActive') as bool? ?? false;
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        final isExpired = expiry != null && expiry.isBefore(now);
        return isActive && !isExpired;
      });

      if (activeLicense == null) {
        safeDebugPrint('❌ No active license found or license expired');

        // 🟢 التحقق من صلاحية المسؤول قبل التوجيه
        final userData = await HiveService.getUserData();
        final bool isAdmin = userData?['isAdmin'] == true;

        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/license/request');
            }
          });
        } else {
          safeDebugPrint('✅ Admin user - skipping expired license redirect');
        }
      }
    });
  }

  void _checkInitialNotification() async {
    safeDebugPrint('🔔 Checking for initial notification');
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        safeDebugPrint('🔔 Initial notification found: ${initialMessage.data}');
        _handleNotification(initialMessage);
      } else {
        safeDebugPrint('🔔 No initial notification found');
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking initial notification: $e');
    }
  }

  void _handleNotification(RemoteMessage message) {
    safeDebugPrint('📨 Handling notification: ${message.data}');
    if (!mounted) return;

    if (message.data['type'] == 'license_request') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('request_details'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('new_license_from'.tr(namedArgs: {
                'email': message.data['userEmail'] ?? 'unknown_user'.tr()
              })),
              const SizedBox(height: 8),
              Text('request_id'.tr(args: [message.data['requestId'] ?? ''])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToLicenseRequests();
              },
              child: Text('view_details'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message.notification?.title ?? 'new_notification'.tr()),
          content:
              Text(message.notification?.body ?? 'new_license_request'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToLicenseRequests() {
    safeDebugPrint('➡️ Navigating to license requests');
    Navigator.pushNamed(context, '/license-requests');
  }

  bool isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _startListeningToUserChanges() async {
    safeDebugPrint('👂 Starting to listen to user changes');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) async {
      safeDebugPrint('🔥 Firestore snapshot received.');

      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      try {
        final localUser = await HiveService.getUserData();
        bool needUpdate = false;

        final cloudCreatedAt = (data['createdAt'] as Timestamp?)?.toDate();
        final cloudDuration = data['subscriptionDurationInDays'] ?? 30;
        final cloudIsActive = data['isActive'] ?? true;

        final localCreatedAt = localUser?['createdAt'] as DateTime?;
        final localDuration = localUser?['subscriptionDurationInDays'];
        final localIsActive = localUser?['isActive'];

        safeDebugPrint('🔍 Comparing:');
        safeDebugPrint(
            '📦 cloud => createdAt=$cloudCreatedAt, duration=$cloudDuration, isActive=$cloudIsActive');
        safeDebugPrint(
            '📦 local => createdAt=$localCreatedAt, duration=$localDuration, isActive=$localIsActive');

        // إصلاح: التحقق من أن cloudCreatedAt ليس null قبل استخدامه
        if (localCreatedAt == null ||
            cloudCreatedAt == null ||
            !localCreatedAt.isAtSameMomentAs(cloudCreatedAt) ||
            localDuration != cloudDuration ||
            localIsActive != cloudIsActive) {
          needUpdate = true;
        }

        if (needUpdate && cloudCreatedAt != null) {
          final userData = {
            'userId': firebaseUser.uid,
            'email': firebaseUser.email ?? '',
            'displayName': firebaseUser.displayName,
            'companyIds': (data['companyIds'] as List?)?.cast<String>() ?? [],
            'factoryIds': (data['factoryIds'] as List?)?.cast<String>() ?? [],
            'supplierIds': (data['supplierIds'] as List?)?.cast<String>() ?? [],
            'createdAt': cloudCreatedAt,
            'subscriptionDurationInDays': cloudDuration,
            'isActive': cloudIsActive,
            'isAdmin': data['isAdmin'] ?? false,
          };

          await HiveService.saveUserData(userData);
          safeDebugPrint('✅ Hive user data updated from Firestore.');

          if (mounted) {
            setState(() {
              userName = firebaseUser.displayName;
              userId = firebaseUser.uid;
              userCompanyIds =
                  (data['companyIds'] as List?)?.cast<String>() ?? [];
            });
            _reloadUserData();
          }
        }
      } catch (e) {
        safeDebugPrint('❌ Error updating user data: $e');
      }
    });
  }

  Future<void> _reloadUserData() async {
    safeDebugPrint('🔄 Reloading user data from Hive');
    try {
      final user = await HiveService.getUserData();
      if (user == null || !mounted) return;

    
    final displayName = user['displayName'] ?? '';
    final email = user['email'] ?? '';
    
    safeDebugPrint('🔍 Hive user data:');
    safeDebugPrint('   - displayName: $displayName');
    safeDebugPrint('   - email: $email');
    safeDebugPrint('   - isAdmin: ${user['isAdmin']}');
    
      setState(() {
        userName =  displayName.isNotEmpty ? displayName : email;
        userId = user['userId'];
        userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
        _stats.totalCompanies = userCompanyIds.length;
        final createdAt = user['createdAt'] as DateTime?;
        final subscriptionDuration = user['subscriptionDurationInDays'] as int?;
        final isActive = user['isActive'] as bool?;
        final isAdmin = user['isAdmin'] as bool?; // 🟢 أضف هذا السطر

        safeDebugPrint(
            '🔁 Hive reload: createdAt=$createdAt, duration=$subscriptionDuration, isActive=$isActive, isAdmin=$isAdmin');
      });
    } catch (e) {
      safeDebugPrint('❌ Error reloading user data: $e');
    }
  }

  Future<void> loadSettings() async {
    safeDebugPrint('⚙️ Loading settings from Hive');

    try {
      // قراءة القيم من Hive
      final dashboardView = await HiveService.getDashboardView();
      final selectedCards = await HiveService.getSelectedCards();

      safeDebugPrint('🔍 Loaded from Hive:');
      safeDebugPrint('   - dashboard_view: $dashboardView');
      safeDebugPrint('   - selected_cards: $selectedCards');

      setState(() {
        _dashboardView = dashboardView;
        _selectedCards = (selectedCards.isNotEmpty)
            ? selectedCards
            : _getDefaultMetrics(); // استخدام دالة للحصول على الافتراضيات
      });

      safeDebugPrint('✅ Settings loaded successfully:');
      safeDebugPrint('   - View: $_dashboardView');
      safeDebugPrint('   - Cards: $_selectedCards');
    } catch (e) {
      safeDebugPrint('❌ Error loading settings: $e');

      // استخدام القيم الافتراضية في حالة الخطأ
      setState(() {
        _dashboardView = DashboardView.short;
        _selectedCards = _getDefaultMetrics();
      });

      safeDebugPrint('🔄 Using default settings:');
      safeDebugPrint('   - View: $_dashboardView');
      safeDebugPrint('   - Cards: $_selectedCards');
    }
  }

  // دالة مساعدة للحصول على البطاقات الافتراضية
  Set<String> _getDefaultMetrics() {
    final viewType = _dashboardView == DashboardView.long ? 'long' : 'short';
    return dashboardMetrics
        .where((metric) => metric.defaultMenuType == viewType)
        .map((metric) => metric.titleKey)
        .toSet();
  }

  Future<void> _debugAndFixSettings() async {
    safeDebugPrint('🔧 Debugging and fixing settings...');

    try {
      final currentView = await HiveService.getDashboardView();
      final currentCards = await HiveService.getSelectedCards();

      safeDebugPrint('   - Current view in Hive: $currentView');
      safeDebugPrint('   - Current cards in Hive: $currentCards');

      // إذا كانت البطاقات فارغة أو null، تعيين البطاقات الافتراضية
      if (currentCards.isEmpty) {
        safeDebugPrint('   - No cards found, setting defaults...');
        final defaultCards = _getDefaultMetrics();
        await HiveService.saveSelectedCards(defaultCards);
        safeDebugPrint('   - Default cards set: $defaultCards');

        if (mounted) {
          setState(() {
            _selectedCards = defaultCards;
          });
        }
      }

      // تأكد من أن العرض الحالي متوافق مع البطاقات
      if (currentView == DashboardView.long && currentCards.length < 4) {
        safeDebugPrint('   - Long view with few cards, adjusting...');
        final defaultCards = _getDefaultMetrics();
        await HiveService.saveSelectedCards(defaultCards);
        safeDebugPrint('   - Adjusted cards: $defaultCards');
      }
    } catch (e) {
      safeDebugPrint('❌ Error debugging settings: $e');
    }
  }

  Future<void> _checkAndFixSettings() async {
    try {
      // التحقق من وجود إعدادات صالحة
      if (_selectedCards.isEmpty) {
        safeDebugPrint(
            '🔍 No selected cards found, checking default metrics...');

        // الحصول على البطاقات الافتراضية للنوع الحالي
        final defaultViewType =
            _dashboardView == DashboardView.long ? 'long' : 'short';
        final defaultMetrics = dashboardMetrics
            .where((metric) => metric.defaultMenuType == defaultViewType)
            .map((metric) => metric.titleKey)
            .toSet();

        safeDebugPrint(
            '🔍 Default metrics for $defaultViewType: $defaultMetrics');

        // حفظ الإعدادات الافتراضية إذا لزم الأمر
        if (defaultMetrics.isNotEmpty) {
          await HiveService.saveSetting(
              'selected_cards', defaultMetrics.toList());
          setState(() {
            _selectedCards = defaultMetrics;
          });
          safeDebugPrint('✅ Saved default cards to Hive: $defaultMetrics');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking settings: $e');
    }
  }

  Future<void> _loadInitialData() async {
    safeDebugPrint('📊 Loading initial data');
    try {
      final user = await HiveService.getUserData();
      if (user == null || !mounted) return;

      setState(() {
        userName = user['displayName'];
        userId = user['userId'];
        userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
        _stats.totalCompanies = userCompanyIds.length;
      });

      await _loadCachedData();
      await fetchStats();
    } catch (e) {
      safeDebugPrint('❌ Error loading initial data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    safeDebugPrint('🔍 Checking subscription status');
    try {
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      setState(() {
        isSubscriptionExpiringSoon = result.isExpiringSoon;
        isSubscriptionExpired = result.isExpired;
        subscriptionTimeLeft = result.timeLeftFormatted;
        isLoading = false;
      });

      _debugSubscriptionStatus();

      _timer?.cancel();

      if (result.isExpiringSoon) {
        SubscriptionNotifier.showWarning(
          context,
          timeLeft: result.timeLeftFormatted ?? '',
        );
      }

      if (result.isExpired && result.expiryDate != null) {
        SubscriptionNotifier.showExpiredDialog(
          context,
          expiryDate: result.expiryDate!,
        );
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking subscription status: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _debugSubscriptionStatus() {
    safeDebugPrint('🔍 Subscription Status Debug:');
    safeDebugPrint(
        '   isSubscriptionExpiringSoon: $isSubscriptionExpiringSoon');
    safeDebugPrint('   isSubscriptionExpired: $isSubscriptionExpired');
    safeDebugPrint('   subscriptionTimeLeft: $subscriptionTimeLeft');
    safeDebugPrint('   userId: $userId');
  }

  Future<void> _loadCachedData() async {
    safeDebugPrint('💾 Loading cached data from Hive');
    try {
      final cached = await HiveService.getCachedData('dashboard_stats') ?? {};
      final extended = await HiveService.getCachedData('extended_stats') ?? {};

      if (!mounted) return;

      setState(() {
        _stats
          ..totalSuppliers = cached['totalSuppliers'] ?? 0
          ..totalOrders = cached['totalOrders'] ?? 0
          ..totalAmount = cached['totalAmount'] ?? 0.0
          ..totalItems = cached['totalItems'] ?? 0
          ..totalMovements = extended['totalStockMovements'] ?? 0
          ..totalManufacturingOrders = extended['totalManufacturingOrders'] ?? 0
          ..totalFinishedProducts = extended['totalFinishedProducts'] ?? 0
          ..totalFactories = extended['totalFactories'] ?? 0;
      });
    } catch (e) {
      safeDebugPrint('❌ Error loading cached data: $e');
    }
  }

  Future<void> fetchStats() async {
    safeDebugPrint('📈 Fetching stats');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => isLoading = true);

    try {
      final localUser = await HiveService.getUserData();
      if (localUser == null) {
        safeDebugPrint('❌ No local user data found');
        return;
      }

      final updatedCompanyIds =
          (localUser['companyIds'] as List?)?.cast<String>() ?? [];
      safeDebugPrint(
          'Using local user data with ${updatedCompanyIds.length} companies');

      final [itemsCount, suppliersCount, finishedProductCount] =
          await Future.wait([
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
        _fetchCollectionCount('finished_products'),
      ]);

      final poStats = await _fetchPoStats();

      int orderCount = 0;
      double amountSum = 0.0;
      int movementCount = 0;
      int manufacturingCount = 0;

      if (updatedCompanyIds.isNotEmpty) {
        final companyResults = await Future.wait(
          updatedCompanyIds.map((companyId) => _getCompanyStats(companyId)),
        );

        for (final result in companyResults) {
          orderCount = poStats['count'];
          amountSum = poStats['totalAmount'];
          movementCount += (result['movements'] as num).toInt();
          manufacturingCount += (result['manufacturing'] as num).toInt();
        }
      }

      final factoryIds =
          (localUser['factoryIds'] as List?)?.cast<String>() ?? [];
      final factoryCount = factoryIds.length;

      final newStats = DashboardStats(
        totalCompanies: updatedCompanyIds.length,
        totalItems: itemsCount,
        totalSuppliers: suppliersCount,
        totalOrders: orderCount,
        totalAmount: amountSum,
        totalMovements: movementCount,
        totalManufacturingOrders: manufacturingCount,
        totalFinishedProducts: finishedProductCount,
        totalFactories: factoryCount,
      );

      if (mounted) {
        setState(() {
          userCompanyIds = updatedCompanyIds;
          _stats.updateFrom(newStats);
        });
        await _saveToLocalStorage();
      }
    } catch (e) {
      safeDebugPrint('❌ Error in fetchStats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_fetching_data'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<bool> _checkCollectionPermission(String collection) async {
    try {
      final query = FirebaseFirestore.instance.collection(collection).limit(1);
      await query.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> _fetchCollectionCount(String collection) async {
    try {
      if (userId == null) return 0;
      safeDebugPrint('🔄 Attempting to fetch count for: $collection');
      final hasPermission = await _checkCollectionPermission(collection);
      safeDebugPrint('🔍 Permission check for $collection: $hasPermission');

      if (!hasPermission) {
        safeDebugPrint('❌ No permission to access $collection');
        return 0;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();

      safeDebugPrint(
          '✅ Successfully fetched $collection: ${snapshot.size} items');
      return snapshot.size;
    } catch (e) {
      safeDebugPrint('❌ Error fetching $collection: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _getCompanyStats(String companyId) async {
    try {
      safeDebugPrint('🔄 Getting stats for company: $companyId');
      final results = await Future.wait([
        _getSubCollectionCount('stock_movements', companyId),
        _getSubCollectionCount('manufacturing_orders', companyId),
      ]);

      safeDebugPrint('✅ Company stats successful');

      return {
        'movements': results[0]['count'],
        'manufacturing': results[1]['count'],
      };
    } catch (e) {
      safeDebugPrint('❌ Error getting stats for company $companyId: $e');
      return {
        'movements': 0,
        'manufacturing': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getSubCollectionCount(
      String collection, String companyId) async {
    try {
      if (userId == null) return {'count': 0, 'amount': 0.0};

      final path = 'companies/$companyId/$collection';
      safeDebugPrint('🔄 Fetching subcollection: $path');

      final snapshot = await FirebaseFirestore.instance
          .collection('companies/$companyId/$collection')
          .where('userId', isEqualTo: userId)
          .get();

      safeDebugPrint(
          '✅ Fetched $collection for $companyId: ${snapshot.size} items');

      double amount = 0.0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0.0, (total, doc) {
          final val = doc.data()['totalAmount'];
          return total + ((val is num) ? val.toDouble() : 0.0);
        });
      }

      return {'count': snapshot.size, 'amount': amount};
    } catch (e) {
      safeDebugPrint('❌ Error fetching $collection: $e');
      return {'count': 0, 'amount': 0.0};
    }
  }

  Future<Map<String, dynamic>> _fetchPoStats() async {
    try {
      safeDebugPrint('🔄 Fetching purchase orders stats...');
      if (userId == null) return {'count': 0, 'totalAmount': 0.0};

      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      safeDebugPrint('✅ Purchase orders fetched: ${querySnapshot.size}');

      double totalAmount = querySnapshot.docs.fold(0.0, (sTotal, doc) {
        final amount = doc.data()['totalAmountAfterTax'] ?? 0.0;
        return sTotal + (amount is num ? amount.toDouble() : 0.0);
      });
      safeDebugPrint('✅ Purchase orders fetched: ${querySnapshot.size} orders');
      return {
        'count': querySnapshot.size,
        'totalAmount': totalAmount,
      };
    } catch (e) {
      safeDebugPrint('❌ Error fetching PURCHASE_ORDERS: $e');
      return {'count': 0, 'totalAmount': 0.0};
    }
  }

  Future<void> _syncUserData() async {
    safeDebugPrint('🔄 Syncing user data with Hive');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;

      final Timestamp? createdAtTimestamp = data['createdAt'];
      final createdAt = createdAtTimestamp?.toDate();
      final subscriptionDurationInDays =
          data['subscriptionDurationInDays'] ?? 30;
      final isActive = data['isActive'] ?? true;
      final isAdmin = data['isAdmin'] ?? false; // 🟢 أضف هذا السطر

      // الحصول على displayName من Firebase Auth وليس من Firestore
      final displayName = firebaseUser.displayName ?? data['displayName'] ?? '';

      safeDebugPrint('🔥 Firestore user data:');
      safeDebugPrint('   - displayName from Firestore: ${data['displayName']}');
      safeDebugPrint(
          '   - displayName from Firebase Auth: ${firebaseUser.displayName}');
      safeDebugPrint('   - email: ${firebaseUser.email}');
      safeDebugPrint('   - isAdmin: $isAdmin');

      final localUser = await HiveService.getUserData();

      bool needUpdateLocal = false;

      if (localUser == null) {
        needUpdateLocal = true;
      } else {
        final localCreatedAt = localUser['createdAt'] as DateTime?;
        final localSubscriptionDuration =
            localUser['subscriptionDurationInDays'] ?? 30;
        final localIsActive = localUser['isActive'] ?? true;
        final localIsAdmin = localUser['isAdmin'] ?? false; // 🟢 أضف هذا السطر
        final localDisplayName = localUser['displayName'] ?? '';

        safeDebugPrint('🔍 Comparing local vs remote:');
        safeDebugPrint('   - local displayName: $localDisplayName');
        safeDebugPrint('   - remote displayName: $displayName');
        safeDebugPrint('   - local isAdmin: $localIsAdmin');
        safeDebugPrint('   - remote isAdmin: $isAdmin');

        // إصلاح: التحقق من أن createdAt ليس null قبل استخدامه
        if (localCreatedAt == null ||
            createdAt == null ||
            !isSameDate(localCreatedAt, createdAt) ||
            localSubscriptionDuration != subscriptionDurationInDays ||
            localIsActive != isActive ||
            localIsAdmin != isAdmin ||
            localDisplayName != displayName) {
          needUpdateLocal = true;
          safeDebugPrint('🔍 Differences detected, need to update local data');
        }
      }

      if (needUpdateLocal && createdAt != null) {
        final userData = {
          'userId': firebaseUser.uid,
          'email': firebaseUser.email ?? '',
          'displayName': displayName, //firebaseUser.displayName,
          'companyIds': (data['companyIds'] as List?)?.cast<String>() ?? [],
          'factoryIds': (data['factoryIds'] as List?)?.cast<String>() ?? [],
          'supplierIds': (data['supplierIds'] as List?)?.cast<String>() ?? [],
          'createdAt': createdAt,
          'subscriptionDurationInDays': subscriptionDurationInDays,
          'isActive': isActive,
          'isAdmin': data['isAdmin'] ?? false,
        };

        await HiveService.saveUserData(userData);
        safeDebugPrint(
            '💾 Hive user data updated from Firestore. isAdmin: $isAdmin');
        safeDebugPrint('   - displayName saved: $displayName');
        safeDebugPrint('   - isAdmin saved: $isAdmin');

        if (mounted) {
          setState(() {
            userName = displayName.isNotEmpty ? displayName : firebaseUser.email;
            userId = firebaseUser.uid;
            userCompanyIds =
                (data['companyIds'] as List?)?.cast<String>() ?? [];
          });
          safeDebugPrint('✅ UI updated with new user data');
        }  else {
      safeDebugPrint('✅ Local data is up to date, no need to update');
    }
      }
    } catch (e) {
      safeDebugPrint('❌ Error syncing user data: $e');
    }
  }

  Future<void> _saveToLocalStorage() async {
    safeDebugPrint('💾 Saving to Hive');
    try {
      await HiveService.cacheData('dashboard_stats', {
        'totalCompanies': _stats.totalCompanies,
        'totalSuppliers': _stats.totalSuppliers,
        'totalOrders': _stats.totalOrders,
        'totalAmount': _stats.totalAmount,
      });

      await HiveService.cacheData('extended_stats', {
        'totalFactories': _stats.totalFactories,
        'totalItems': _stats.totalItems,
        'totalStockMovements': _stats.totalMovements,
        'totalManufacturingOrders': _stats.totalManufacturingOrders,
        'totalFinishedProducts': _stats.totalFinishedProducts,
      });
    } catch (e) {
      safeDebugPrint('❌ Error saving to Hive: $e');
    }
  }

  void _debugAdminStatus() async {
    final userData = await HiveService.getUserData();
    final isAdmin = userData?['isAdmin'] == true;

    safeDebugPrint('👨‍💼 ADMIN STATUS DEBUG:');
    safeDebugPrint('   User ID: $userId');
    safeDebugPrint('   User Name: $userName');
    safeDebugPrint('   isAdmin from Hive: $isAdmin');
    safeDebugPrint('   User Data Keys: ${userData?.keys.toList()}');

    // تحقق من Firestore مباشرة
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final firestoreIsAdmin = doc.get('isAdmin') ?? false;
      safeDebugPrint('   isAdmin from Firestore: $firestoreIsAdmin');
    }
  }

  Future<void> _handleRefresh() async {
    safeDebugPrint('🔄 Handling refresh');
    try {
      await _syncUserData();
      await fetchStats();

      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      // 🟢 التحقق من صلاحية المسؤول قبل التوجيه
      final userData = await HiveService.getUserData();
      final bool isAdmin = userData?['isAdmin'] == true;

      if (result.isExpired && mounted && !isAdmin) {
        safeDebugPrint('⏰ License expired after refresh, redirecting...');
        context.go('/license/request');
        return;
      } else if (result.isExpired && isAdmin) {
        safeDebugPrint('✅ Admin user - skipping refresh redirect');
      }

      _refreshController.refreshCompleted();
    } catch (e) {
      safeDebugPrint('❌ Refresh failed: $e');
      _refreshController.refreshFailed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_fetching_data'))),
        );
      }
    }
  }

  Widget _buildStatsGrid() {
    safeDebugPrint('📊 Building stats grid');
    final statsMap = _stats.toMap();

    safeDebugPrint('🟢 Selected Cards from Hive: $_selectedCards');
    safeDebugPrint(
        '🟢 Available Metrics: ${dashboardMetrics.map((m) => m.titleKey).toList()}');
    safeDebugPrint('🟢 Dashboard View: $_dashboardView');

    List<DashboardMetric> filteredMetrics;

    if (_selectedCards.isEmpty) {
      // إذا لم يتم اختيار أي بطاقات، عرض البطاقات الافتراضية بناءً على نوع العرض
      final defaultViewType =
          _dashboardView == DashboardView.long ? 'long' : 'short';
      filteredMetrics = dashboardMetrics
          .where((metric) => metric.defaultMenuType == defaultViewType)
          .toList();

      safeDebugPrint('🔵 Using default $defaultViewType view metrics');
    } else {
      // إذا تم اختيار بطاقات، عرض البطاقات المحددة فقط
      filteredMetrics = dashboardMetrics
          .where((metric) => _selectedCards.contains(metric.titleKey))
          .toList();

      safeDebugPrint('🔵 Using custom selected metrics');
    }

    // إذا كانت القائمة仍然 فارغة، استخدم البطاقات الافتراضية كحل بديل
    if (filteredMetrics.isEmpty) {
      safeDebugPrint(
          '⚠️ No metrics found, using default short view as fallback');
      filteredMetrics = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .toList();
    }

    safeDebugPrint(
        '🟢 Metrics to display: ${filteredMetrics.map((m) => m.titleKey).toList()}');
    safeDebugPrint('🟢 Number of metrics: ${filteredMetrics.length}');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 135,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: filteredMetrics.length,
      itemBuilder: (context, index) {
        final metric = filteredMetrics[index];
        return DashboardTileWidget(
          metric: metric,
          data: statsMap,
          highlight: metric.titleKey == 'totalCompanies',
        );
      },
    );
  }

  Widget _buildLicenseExpiredWarning() {
    // التحقق من حالة الأدمن قبل البناء
    final isAdmin = userData?['isAdmin'] == true; // يتحول لـ false لو null
    if (isAdmin) {
      safeDebugPrint('✅ Admin user → skipping license expired warning');
      return const SizedBox.shrink(); // لا تبني أي شيء
    }

    safeDebugPrint('⚠️ Building license expired warning');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('license_expired'),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('license_expired_message'),
                  style: TextStyle(
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    safeDebugPrint('🏗️ Building DashboardPage with Hive');

    // لو لسه بنحمل بيانات المستخدم → اعرض Loader
    if (isLoading || userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: tr('dashboard'),
      userName: userName,
      isSubscriptionExpiringSoon: isSubscriptionExpiringSoon,
      isSubscriptionExpired: isSubscriptionExpired,
      isDashboard: true,
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _handleRefresh,
        enablePullDown: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('welcome_back', args: [userName ?? '']),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              if (isSubscriptionExpiringSoon) _buildTimeLeftBar(),

              // ✅ لا تعرض التحذير لو المستخدم Admin
              if (isSubscriptionExpired && !(userData?['isAdmin'] == true))
                _buildLicenseExpiredWarning(),

              const SizedBox(height: 16),

              _buildStatsGrid(),

              if (subscriptionTimeLeft != null &&
                  subscriptionTimeLeft!.contains('maximum number of devices'))
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: FloatingActionButton(
                    onPressed: () {
                      context.push('/device-request');
                    },
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.device_hub),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardStats {
  int totalCompanies;
  int totalSuppliers;
  int totalOrders;
  double totalAmount;
  int totalItems;
  int totalMovements;
  int totalManufacturingOrders;
  int totalFinishedProducts;
  int totalFactories;

  DashboardStats({
    required this.totalCompanies,
    required this.totalSuppliers,
    required this.totalOrders,
    required this.totalAmount,
    required this.totalItems,
    required this.totalMovements,
    required this.totalManufacturingOrders,
    required this.totalFinishedProducts,
    required this.totalFactories,
  });

  factory DashboardStats.empty() => DashboardStats(
        totalCompanies: 0,
        totalSuppliers: 0,
        totalOrders: 0,
        totalAmount: 0.0,
        totalItems: 0,
        totalMovements: 0,
        totalManufacturingOrders: 0,
        totalFinishedProducts: 0,
        totalFactories: 0,
      );

  void updateFrom(DashboardStats other) {
    totalCompanies = other.totalCompanies;
    totalSuppliers = other.totalSuppliers;
    totalOrders = other.totalOrders;
    totalAmount = other.totalAmount;
    totalItems = other.totalItems;
    totalMovements = other.totalMovements;
    totalManufacturingOrders = other.totalManufacturingOrders;
    totalFinishedProducts = other.totalFinishedProducts;
    totalFactories = other.totalFactories;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCompanies': totalCompanies,
      'totalSuppliers': totalSuppliers,
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'totalStockMovements': totalMovements,
      'totalManufacturingOrders': totalManufacturingOrders,
      'totalFinishedProducts': totalFinishedProducts,
      'totalFactories': totalFactories,
    };
  }
}
 */

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/notifications/notification_service.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/services/subscription_notifier.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

enum DashboardView { short, long }

class DashboardPageState extends State<DashboardPage> {
  // المتغيرات الأساسية
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _lastNotificationTime = {};
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _licenseStatusSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? subscriptionTimeLeft;
  Timer? _timer;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};
  Map<String, dynamic>? userData;
  bool isAdmin = false;

  bool isLoading = true;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  final DashboardStats _stats = DashboardStats.empty();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription? _notificationSubscription;

  String? userId;
  String? userName;
  List<String> userCompanyIds = [];
  bool _isInitialLoading = true;
  bool _isDataLoading = false;
  bool _isRefreshing = false;
/*   @override
  void initState() {
    super.initState();
    safeDebugPrint('🔄 DashboardPage initState called');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromHiveFirst().then((_) {
        // إعادة تحميل البيانات بعد اكتمال البناء الأولي
        if (mounted) {
          fetchStats();
          _checkSubscriptionStatus();
        }
      });
    });
  } */
  @override
  void initState() {
    super.initState();
    safeDebugPrint('🔄 DashboardPage initState called');
    _initializeFromHiveFirst();
  }

  Future<void> _initializeFromHiveFirst() async {
    safeDebugPrint('📦 Loading data from Hive first...');

    try {
      // تحميل البيانات الأساسية من Hive
      await _loadUserDataFromHive();
      await loadSettingsFromHive();
      await loadCachedDataFromHive();

      // إخفاء التحميل الأولي فوراً
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }

      // بدء تحميل البيانات الخلفية بعد عرض الصفحة
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startBackgroundUpdates();
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error in initial Hive load: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _loadUserDataFromHive() async {
    try {
      final data = await HiveService.getUserData();
      if (data != null && mounted) {
        setState(() {
          userData = data;
          isAdmin = data['isAdmin'] == true;
          userName = data['displayName'] ?? data['email'] ?? '';
          userId = data['userId'];
          userCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
          _stats.totalCompanies = userCompanyIds.length;
        });
        safeDebugPrint('✅ User data loaded from Hive');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading user data from Hive: $e');
    }
  }

  Future<void> loadSettingsFromHive() async {
    try {
      final dashboardView = await HiveService.getDashboardView();
      final selectedCards = await HiveService.getSelectedCards();

      if (mounted) {
        setState(() {
          _dashboardView = dashboardView;
          _selectedCards =
              selectedCards.isNotEmpty ? selectedCards : _getDefaultMetrics();
        });
      }
      safeDebugPrint('✅ Settings loaded from Hive');
    } catch (e) {
      safeDebugPrint('❌ Error loading settings from Hive: $e');
      if (mounted) {
        setState(() {
          _dashboardView = DashboardView.short;
          _selectedCards = _getDefaultMetrics();
        });
      }
    }
  }

  Future<void> loadCachedDataFromHive() async {
    try {
      final cached = await HiveService.getCachedData('dashboard_stats') ?? {};
      final extended = await HiveService.getCachedData('extended_stats') ?? {};

      if (mounted) {
        setState(() {
          _stats
            ..totalSuppliers = cached['totalSuppliers'] ?? 0
            ..totalOrders = cached['totalOrders'] ?? 0
            ..totalAmount = cached['totalAmount'] ?? 0.0
            ..totalItems = cached['totalItems'] ?? 0
            ..totalMovements = extended['totalStockMovements'] ?? 0
            ..totalManufacturingOrders =
                extended['totalManufacturingOrders'] ?? 0
            ..totalFinishedProducts = extended['totalFinishedProducts'] ?? 0
            ..totalFactories = extended['totalFactories'] ?? 0;
        });
      }
      safeDebugPrint('✅ Cached data loaded from Hive');
    } catch (e) {
      safeDebugPrint('❌ Error loading cached data from Hive: $e');
    }
  }

/*   void _startBackgroundUpdates() {
    safeDebugPrint('🔄 Starting background updates from Firestore...');

    Future.wait([
      _syncUserDataWithFirestore(),
      _checkSubscriptionStatus(),
      fetchStats(),
      _checkLicenseExpiryStatus(),
      _saveExpiryDateToLocalStorage(),
    ]).then((_) {
     if (mounted) { // ✅ التحقق قبل التحديث
      safeDebugPrint('✅ All background updates completed');
    }
    }).catchError((error) {
      if (mounted) { // ✅ التحقق قبل التحديث
      safeDebugPrint('❌ Error in background updates: $error');
    }
    });
  }
 */

  void _startBackgroundUpdates() {
    if (mounted) {
      setState(() => _isDataLoading = true);
    }

    safeDebugPrint('🔄 Starting background updates from Firestore...');

    // المهام الأساسية فقط
    final essentialTasks = [
      _syncUserDataWithFirestore(),
      _checkSubscriptionStatus(),
      _loadEssentialStats(),
      _checkLicenseExpiryStatus(), // إضافة هنا
      _saveExpiryDateToLocalStorage(), // إضافة هنا
    ];

    Future.wait(essentialTasks).then((_) {
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
      safeDebugPrint('✅ Essential background updates completed');

      // تحميل البيانات الثانوية لاحقاً
      _loadSecondaryData();
    }).catchError((error) {
      safeDebugPrint('❌ Error in background updates: $error');
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
    });

    _setupListenersAndNotifications();
  }

  Future<void> _loadEssentialStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final criticalResults = await Future.wait([
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
        _fetchPoStats(),
      ], eagerError: false);

      if (mounted) {
        setState(() {
          _stats.totalItems = criticalResults[0] as int;
          _stats.totalSuppliers = criticalResults[1] as int;
          _stats.totalOrders = (criticalResults[2] as Map)['count'] as int;
          _stats.totalAmount =
              (criticalResults[2] as Map)['totalAmount'] as double;
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error in essential stats: $e');
    }
  }

  Future<void> _loadSecondaryStats() async {
    // هذه البيانات أقل أهمية ويمكن أن تأتي لاحقاً
    try {
      await Future.wait([
        _fetchCollectionCount('finished_products'),
        _fetchManufacturingOrdersCount(),
        _loadMovementStats(),
      ], eagerError: false);
    } catch (e) {
      safeDebugPrint('❌ Error in secondary stats: $e');
    }
  }
/* Future<void> _loadEssentialStats() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final criticalResults = await Future.wait([
      _fetchCollectionCount('items'),
      _fetchCollectionCount('vendors'),
      _fetchPoStats(),
    ], eagerError: false);

    if (mounted) {
      setState(() {
        _stats.totalItems = criticalResults[0] as int;
        _stats.totalSuppliers = criticalResults[1] as int;
        _stats.totalOrders = (criticalResults[2] as Map)['count'] as int;
        _stats.totalAmount = (criticalResults[2] as Map)['totalAmount'] as double;
      });
    }
  } catch (e) {
    safeDebugPrint('❌ Error in essential stats: $e');
  }
}

Future<void> _loadSecondaryStats() async {
  // هذه البيانات أقل أهمية ويمكن أن تأتي لاحقاً
  try {
    await Future.wait([
      _fetchCollectionCount('finished_products'),
      _fetchManufacturingOrdersCount(),
      _loadMovementStats(),
    ], eagerError: false);
  } catch (e) {
    safeDebugPrint('❌ Error in secondary stats: $e');
  }
}
 */

  void _setupListenersAndNotifications() {
    _startListeningToUserChanges();
    _setupLicenseStatusListener();
    _listenForNewDeviceRequests();
    _listenForNewLicenseRequests();
    _checkInitialNotification();
    _setupFCM();
  }

  Future<void> _syncUserDataWithFirestore() async {
    safeDebugPrint('🔄 Syncing user data with Firestore (background)...');

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;

      final Timestamp? createdAtTimestamp = data['createdAt'];
      final createdAt = createdAtTimestamp?.toDate();
      final subscriptionDurationInDays =
          data['subscriptionDurationInDays'] ?? 30;
      final isActive = data['isActive'] ?? true;
      final remoteIsAdmin = data['isAdmin'] ?? false;
      final displayName = firebaseUser.displayName ?? data['displayName'] ?? '';

      final localUser = await HiveService.getUserData();
      bool needUpdate = false;

      if (localUser == null) {
        needUpdate = true;
      } else {
        final localCreatedAt = localUser['createdAt'] as DateTime?;
        final localSubscriptionDuration =
            localUser['subscriptionDurationInDays'] ?? 30;
        final localIsActive = localUser['isActive'] ?? true;
        final localIsAdmin = localUser['isAdmin'] ?? false;
        final localDisplayName = localUser['displayName'] ?? '';

        if (localCreatedAt == null ||
            createdAt == null ||
            !localCreatedAt.isAtSameMomentAs(createdAt) ||
            localSubscriptionDuration != subscriptionDurationInDays ||
            localIsActive != isActive ||
            localIsAdmin != remoteIsAdmin ||
            localDisplayName != displayName) {
          needUpdate = true;
        }
      }

      if (needUpdate && createdAt != null) {
        final newUserData = {
          'userId': firebaseUser.uid,
          'email': firebaseUser.email ?? '',
          'displayName': displayName,
          'companyIds': (data['companyIds'] as List?)?.cast<String>() ?? [],
          'factoryIds': (data['factoryIds'] as List?)?.cast<String>() ?? [],
          'supplierIds': (data['supplierIds'] as List?)?.cast<String>() ?? [],
          'createdAt': createdAt,
          'subscriptionDurationInDays': subscriptionDurationInDays,
          'isActive': isActive,
          'isAdmin': remoteIsAdmin,
        };

        await HiveService.saveUserData(newUserData);
        safeDebugPrint('💾 User data updated from Firestore (background)');

        if (mounted) {
          setState(() {
            userData = newUserData;
            isAdmin = remoteIsAdmin;
            userName =
                displayName.isNotEmpty ? displayName : firebaseUser.email;
            userId = firebaseUser.uid;
            userCompanyIds =
                (data['companyIds'] as List?)?.cast<String>() ?? [];
          });
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error syncing user data with Firestore: $e');
    }
  }

  void _listenForNewLicenseRequests() async {
    final userData = await HiveService.getUserData();
    final bool isAdmin = userData?['isAdmin'] == true;

    if (!isAdmin) return;

    _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty || !mounted) return;

      for (final doc in snapshot.docs) {
        final String requestId = doc.id;
        final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();

        if (createdAt == null) continue;

        final now = DateTime.now();
        final difference = now.difference(createdAt);

        if (difference.inSeconds < 30 &&
            _lastNotificationTime.containsKey(requestId)) {
          final lastTime = _lastNotificationTime[requestId]!;
          if (now.difference(lastTime).inSeconds < 30) {
            continue;
          }
        }

        if (difference.inSeconds < 10) {
          _debounceTimers[requestId]?.cancel();

          _debounceTimers[requestId] = Timer(const Duration(seconds: 2), () {
            _showLicenseRequestNotification(doc);
            _lastNotificationTime[requestId] = DateTime.now();
          });
        }
      }
    });
  }

  void _showLicenseRequestNotification(DocumentSnapshot doc) async {
    final userName = doc['displayName'];

    await NotificationService.showNotification(
      title: '📝 ${tr('new_license_request')}',
      body: '${tr('from')} $userName',
      playSound: true,
      vibrate: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📝${'new_license_request'.tr()} $userName'),
          action: SnackBarAction(
            label: 'view'.tr(),
            onPressed: () {
              DefaultTabController.of(context).animateTo(0);
            },
          ),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _listenForNewDeviceRequests() async {
    final userData = await HiveService.getUserData();
    final bool isAdmin = userData?['isAdmin'] == true;

    if (!isAdmin) return;

    _firestore
        .collection('device_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final createdAt = (doc['createdAt'] as Timestamp).toDate();

        final now = DateTime.now();
        final difference = now.difference(createdAt);

        if (difference.inSeconds < 10) {
          final userName = doc['displayName'];
          final licenseId = doc['licenseId'];
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '📱 ${'request_device_from'.tr()} $userName ${'licence_id'.tr()} $licenseId'),
              action: SnackBarAction(
                label: 'view'.tr(),
                onPressed: () {
                  DefaultTabController.of(context).animateTo(2);
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    });
  }

  // باقي الدوال الأساسية...
  Future<void> _saveExpiryDateToLocalStorage() async {
    try {
      final expiryDate = await _getExpiryDateFromFirebase();
      if (expiryDate != null) {
        await HiveService.cacheData(
            'expiry_date', expiryDate.toIso8601String());
        safeDebugPrint('💾 Expiry date saved to Hive: $expiryDate');
      }
    } catch (e) {
      safeDebugPrint('❌ Error saving expiry date to Hive: $e');
    }
  }

  Future<DateTime?> _getExpiryDateFromLocalStorage() async {
    try {
      final expiryString = await HiveService.getCachedData('expiry_date');
      if (expiryString != null) {
        return DateTime.parse(expiryString);
      }
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from Hive: $e');
    }
    return null;
  }

  Widget _buildTimeLeftBar() {
    if (!isSubscriptionExpiringSoon ||
        subscriptionTimeLeft == null ||
        subscriptionTimeLeft!.isEmpty) {
      return const SizedBox();
    }

    if (subscriptionTimeLeft!.contains('maximum number of devices')) {
      return const SizedBox();
    }

    return FutureBuilder<DateTime?>(
      future: _getExpiryDateFromLocalStorage(),
      builder: (context, dateSnapshot) {
        if (dateSnapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }

        if (!dateSnapshot.hasData) {
          return _buildSimpleTimeLeftBar();
        }

        final expiryDate = dateSnapshot.data!;
        final now = DateTime.now();
        final daysLeft = expiryDate.difference(now).inDays;

        Color progressColor;
        if (daysLeft > 7) {
          progressColor = Colors.green;
        } else if (daysLeft > 4) {
          progressColor = Colors.orange;
        } else {
          progressColor = Colors.red;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16, top: 8),
          decoration: BoxDecoration(
            color: progressColor.withAlpha(75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: progressColor.withAlpha(75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: progressColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    tr('license_expiring_soon'),
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tr('license_expiring_message'),
                style: TextStyle(color: progressColor, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${tr('time_left')}:',
                      style: TextStyle(
                          color: progressColor, fontWeight: FontWeight.w500)),
                  Text(subscriptionTimeLeft!,
                      style: TextStyle(
                          color: progressColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${tr('expiry_date')}:',
                      style: TextStyle(
                          color: progressColor, fontWeight: FontWeight.w500)),
                  Text(
                    '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        color: progressColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleTimeLeftBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Text(
        '${tr('license_expiring_soon')}: $subscriptionTimeLeft',
        style: TextStyle(
            color: Colors.orange.shade800, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<DateTime?> _getExpiryDateFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final licenseDoc = snapshot.docs.first;
      final expiryTimestamp = licenseDoc.get('expiryDate') as Timestamp?;
      return expiryTimestamp?.toDate();
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from Firebase: $e');
      return null;
    }
  }

  Future<void> _checkLicenseExpiryStatus() async {
    try {
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      setState(() {
        isSubscriptionExpiringSoon = result.isExpiringSoon;
        isSubscriptionExpired = result.isExpired;
        subscriptionTimeLeft = result.timeLeftFormatted;
      });

      if (!result.isValid &&
          subscriptionTimeLeft != null &&
          subscriptionTimeLeft!.contains('maximum number of devices')) {
        _showDeviceLimitWarning(subscriptionTimeLeft!);
      }

      if (result.isExpired && !isAdmin) {
        _redirectToExpiredPage();
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking license expiry status: $e');
    }
  }

  void _redirectToExpiredPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/license/request');
    });
  }

  void _showDeviceLimitWarning(String message) async {
    if (!isAdmin) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.showNotification(
        title: '⚠️ ${tr('device_limit_warning')}',
        body: message,
        playSound: true,
        vibrate: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _debounceTimers.forEach((key, timer) => timer.cancel());
    _debounceTimers.clear();

    _timer?.cancel();
    _userSubscription?.cancel();
    _refreshController.dispose();
    _notificationSubscription?.cancel();
    _licenseStatusSubscription?.cancel();

    super.dispose();
  }

  void _setupLicenseStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _licenseStatusSubscription = _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      final docs = snapshot.docs.where((doc) => doc.exists).toList();
      if (docs.isEmpty) {
        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/license/request');
          });
        }
        return;
      }

      final now = DateTime.now();
      final activeLicense = docs.firstWhereOrNull((doc) {
        final isActive = doc.get('isActive') as bool? ?? false;
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        final isExpired = expiry != null && expiry.isBefore(now);
        return isActive && !isExpired;
      });

      if (activeLicense == null && !isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/license/request');
        });
      }
    });
  }

  void _checkInitialNotification() async {
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotification(initialMessage);
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking initial notification: $e');
    }
  }

  void _handleNotification(RemoteMessage message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? 'new_notification'.tr()),
        content: Text(message.notification?.body ?? 'new_license_request'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  void _startListeningToUserChanges() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    _userSubscription = _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      await _syncUserDataWithFirestore();
    });
  }

  Set<String> _getDefaultMetrics() {
    final viewType = _dashboardView == DashboardView.long ? 'long' : 'short';
    return dashboardMetrics
        .where((metric) => metric.defaultMenuType == viewType)
        .map((metric) => metric.titleKey)
        .toSet();
  }

/*   Future<void> fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    try {
      final localUser = await HiveService.getUserData();
      if (localUser == null) return;

      final updatedCompanyIds =
          (localUser['companyIds'] as List?)?.cast<String>() ?? [];

      // تحديث عدد الشركات أولاً
      if (mounted) {
        setState(() {
          userCompanyIds = updatedCompanyIds;
          _stats.totalCompanies = updatedCompanyIds.length;
        });
      }

      // جلب البيانات الأخرى بشكل متوازي مع معالجة الأخطاء
      final results = await Future.wait([
        _fetchCollectionCount('items').catchError((e) {
          safeDebugPrint('❌ Error fetching items: $e');
          return 0;
        }),
        _fetchCollectionCount('vendors').catchError((e) {
          safeDebugPrint('❌ Error fetching vendors: $e');
          return 0;
        }),
        _fetchCollectionCount('finished_products').catchError((e) {
          safeDebugPrint('❌ Error fetching finished_products: $e');
          return 0;
        }),
        _fetchPoStats().catchError((e) {
          safeDebugPrint('❌ Error fetching PO stats: $e');
          return {'count': 0, 'totalAmount': 0.0};
        }),
        _fetchManufacturingOrdersCount().catchError((e) {
          safeDebugPrint('❌ Error fetching manufacturing orders: $e');
          return 0;
        }),
      ], eagerError: false);

      int movementCount = 0;
      //  int manufacturingCount = 0;

      if (updatedCompanyIds.isNotEmpty) {
        try {
          final companyResults = await Future.wait(
            updatedCompanyIds
                .map((companyId) => _getCompanyStats(companyId).catchError((e) {
                      safeDebugPrint(
                          '❌ Error getting stats for company $companyId: $e');
                      return {'movements': 0, 'manufacturing': 0};
                    })),
          );

          for (final result in companyResults) {
            movementCount += (result['movements'] as num).toInt();
            //  manufacturingCount += results[4] as int, //await _fetchManufacturingOrdersCount();
          }
        } catch (e) {
          safeDebugPrint('❌ Error in company stats: $e');
        }
      }

      final factoryIds =
          (localUser['factoryIds'] as List?)?.cast<String>() ?? [];
      final factoryCount = factoryIds.length;

      final newStats = DashboardStats(
        totalCompanies: updatedCompanyIds.length,
        totalItems: results[0] as int,
        totalSuppliers: results[1] as int,
        totalOrders: (results[3] as Map)['count'] as int,
        totalAmount: (results[3] as Map)['totalAmount'] as double,
        totalMovements: movementCount,
        totalManufacturingOrders: results[4] as int, // manufacturingCount,
        totalFinishedProducts: results[2] as int,
        totalFactories: factoryCount,
      );

      if (mounted) {
        setState(() {
          _stats.updateFrom(newStats);
        });
        await _saveToLocalStorage();
      }
    } catch (e) {
      if (mounted) {
      safeDebugPrint('❌ Error in fetchStats: $e');
    }
    }
  }
 */

  Future<void> fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    try {
      final localUser = await HiveService.getUserData();
      if (localUser == null) return;

      final updatedCompanyIds =
          (localUser['companyIds'] as List?)?.cast<String>() ?? [];

      // تحديث عدد الشركات أولاً (فوري)
      if (mounted) {
        setState(() {
          userCompanyIds = updatedCompanyIds;
          _stats.totalCompanies = updatedCompanyIds.length;
        });
      }

      // جلب البيانات الأكثر أهمية أولاً
      final criticalResults = await Future.wait([
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
        _fetchPoStats(),
      ], eagerError: false);

      // تحديث الواجهة بالبيانات الحرجة أولاً
      if (mounted) {
        setState(() {
          _stats.totalItems = criticalResults[0] as int;
          _stats.totalSuppliers = criticalResults[1] as int;
          _stats.totalOrders = (criticalResults[2] as Map)['count'] as int;
          _stats.totalAmount =
              (criticalResults[2] as Map)['totalAmount'] as double;
        });
      }

      // البيانات الأقل أهمية تأتي لاحقاً
      _loadSecondaryStats();
    } catch (e) {
      safeDebugPrint('❌ Error in fetchStats: $e');
    }
  }

/*   Future<void> _loadSecondaryStats(List<String> companyIds) async {
    try {
      final secondaryResults = await Future.wait([
        _fetchCollectionCount('finished_products'),
        _fetchManufacturingOrdersCount(),
      ], eagerError: false);

      int movementCount = 0;
      if (companyIds.isNotEmpty) {
        try {
          final companyResults = await Future.wait(
            companyIds.map((companyId) => _getCompanyStats(companyId)),
          );

          for (final result in companyResults) {
            movementCount += (result['movements'] as num).toInt();
          }
        } catch (e) {
          safeDebugPrint('❌ Error in company stats: $e');
        }
      }

      final factoryIds =
          (userData?['factoryIds'] as List?)?.cast<String>() ?? [];
      final factoryCount = factoryIds.length;

      if (mounted) {
        setState(() {
          _stats.totalMovements = movementCount;
          _stats.totalManufacturingOrders = secondaryResults[1];
          _stats.totalFinishedProducts = secondaryResults[0];
          _stats.totalFactories = factoryCount;
        });

        await _saveToLocalStorage();
      }
    } catch (e) {
      safeDebugPrint('❌ Error in secondary stats: $e');
    }
  }
 */
  
  Future<bool> _checkCollectionPermission(String collection) async {
    try {
      final query = _firestore.collection(collection).limit(1);
      await query.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> _fetchCollectionCount(String collection) async {
    try {
      if (userId == null) return 0;
      final hasPermission = await _checkCollectionPermission(collection);
      if (!hasPermission) return 0;

      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.size;
    } catch (e) {
      safeDebugPrint('❌ Error fetching $collection: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _getCompanyStats(String companyId) async {
    try {
      final results = await Future.wait([
        _getSubCollectionCount('stock_movements', companyId).catchError((e) {
          safeDebugPrint('❌ Error fetching stock_movements for $companyId: $e');
          return {'count': 0, 'amount': 0.0};
        }),
        // _getSubCollectionCount('manufacturing_orders', companyId)
        //   .catchError((e) {
        //     safeDebugPrint('❌ Error fetching manufacturing_orders for $companyId: $e');
        //     return {'count': 0, 'amount': 0.0};
        //   }),
      ]);

      return {
        'movements': (results[0] as Map)['count'] as int,
        // 'manufacturing': (results[1] as Map)['count'] as int,
      };
    } catch (e) {
      safeDebugPrint('❌ Error getting stats for company $companyId: $e');
      return {'movements': 0, 'manufacturing': 0};
    }
  }

  Future<Map<String, dynamic>> _getSubCollectionCount(
      String collection, String companyId) async {
    try {
      if (userId == null) return {'count': 0, 'amount': 0.0};

      final snapshot = await _firestore
          .collection('companies/$companyId/$collection')
          .where('userId', isEqualTo: userId)
          .get();

      double amount = 0.0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0.0, (total, doc) {
          final val = doc.data()['totalAmount'];
          return total + ((val is num) ? val.toDouble() : 0.0);
        });
      }

      return {'count': snapshot.size, 'amount': amount};
    } catch (e) {
      safeDebugPrint('❌ Error fetching $collection: $e');
      return {'count': 0, 'amount': 0.0};
    }
  }

  Future<Map<String, dynamic>> _fetchPoStats() async {
    try {
      if (userId == null) return {'count': 0, 'totalAmount': 0.0};

      final querySnapshot = await _firestore
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      double totalAmount = querySnapshot.docs.fold(0.0, (sTotal, doc) {
        final amount = doc.data()['totalAmountAfterTax'] ?? 0.0;
        return sTotal + (amount is num ? amount.toDouble() : 0.0);
      });

      return {
        'count': querySnapshot.size,
        'totalAmount': totalAmount,
      };
    } catch (e) {
      safeDebugPrint('❌ Error fetching PURCHASE_ORDERS: $e');
      return {'count': 0, 'totalAmount': 0.0};
    }
  }

  int fetchCount = 0;
  Future<int> _fetchManufacturingOrdersCount() async {
    fetchCount++;
    safeDebugPrint('Fetching manufacturing orders count call #$fetchCount');
    try {
      if (userId == null) return 0;

      final querySnapshot = await _firestore
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      safeDebugPrint(
          '✅ Fetched MANUFACTURING_ORDERS count: ${querySnapshot.size}');
      return querySnapshot.size;
    } catch (e) {
      safeDebugPrint('❌ Error fetching MANUFACTURING_ORDERS count: $e');
      return 0;
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      await HiveService.cacheData('dashboard_stats', {
        'totalCompanies': _stats.totalCompanies,
        'totalSuppliers': _stats.totalSuppliers,
        'totalOrders': _stats.totalOrders,
        'totalAmount': _stats.totalAmount,
      });

      await HiveService.cacheData('extended_stats', {
        'totalFactories': _stats.totalFactories,
        'totalItems': _stats.totalItems,
        'totalStockMovements': _stats.totalMovements,
        'totalManufacturingOrders': _stats.totalManufacturingOrders,
        'totalFinishedProducts': _stats.totalFinishedProducts,
      });
    } catch (e) {
      safeDebugPrint('❌ Error saving to Hive: $e');
    }
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      await _syncUserDataWithFirestore();
      await _loadEssentialStats();
      await _checkSubscriptionStatus();

      _refreshController.refreshCompleted();
    } catch (e) {
      safeDebugPrint('❌ Refresh failed: $e');
      _refreshController.refreshFailed();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

// أضف هذه الدوال قبل نهاية الـ class
  Future<void> _loadMovementStats() async {
    try {
      int movementCount = 0;
      if (userCompanyIds.isNotEmpty) {
        final companyResults = await Future.wait(
          userCompanyIds.map((companyId) => _getCompanyStats(companyId)),
        );

        for (final result in companyResults) {
          movementCount += (result['movements'] as num).toInt();
        }
      }

      if (mounted) {
        setState(() {
          _stats.totalMovements = movementCount;
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading movement stats: $e');
    }
  }

// استبدل الدالة المكررة
  Future<void> _loadSecondaryData() async {
    try {
      await Future.wait([
        _fetchCollectionCount('finished_products'),
        _fetchManufacturingOrdersCount(),
        _loadMovementStats(),
      ], eagerError: false);

      final factoryIds =
          (userData?['factoryIds'] as List?)?.cast<String>() ?? [];
      final factoryCount = factoryIds.length;

      if (mounted) {
        setState(() {
          _stats.totalFactories = factoryCount;
        });
        await _saveToLocalStorage();
      }
    } catch (e) {
      safeDebugPrint('❌ Error in secondary data: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    safeDebugPrint('🔍 Checking subscription status');
    try {
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      setState(() {
        isSubscriptionExpiringSoon = result.isExpiringSoon;
        isSubscriptionExpired = result.isExpired;
        subscriptionTimeLeft = result.timeLeftFormatted;
        isLoading = false;
      });

      _debugSubscriptionStatus();

      _timer?.cancel();

      if (result.isExpiringSoon) {
        SubscriptionNotifier.showWarning(
          context,
          timeLeft: result.timeLeftFormatted ?? '',
        );
      }

      if (result.isExpired && result.expiryDate != null) {
        SubscriptionNotifier.showExpiredDialog(
          context,
          expiryDate: result.expiryDate!,
        );
      }
    } catch (e) {
      safeDebugPrint('❌ Error checking subscription status: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _debugSubscriptionStatus() {
    safeDebugPrint('🔍 Subscription Status Debug:');
    safeDebugPrint(
        '   isSubscriptionExpiringSoon: $isSubscriptionExpiringSoon');
    safeDebugPrint('   isSubscriptionExpired: $isSubscriptionExpired');
    safeDebugPrint('   subscriptionTimeLeft: $subscriptionTimeLeft');
    safeDebugPrint('   userId: $userId');
  }

/*   Widget _buildStatsGrid() {
    final statsMap = _stats.toMap();
    List<DashboardMetric> filteredMetrics;

    if (_selectedCards.isEmpty) {
      final defaultViewType =
          _dashboardView == DashboardView.long ? 'long' : 'short';
      filteredMetrics = dashboardMetrics
          .where((metric) => metric.defaultMenuType == defaultViewType)
          .toList();
    } else {
      filteredMetrics = dashboardMetrics
          .where((metric) => _selectedCards.contains(metric.titleKey))
          .toList();
    }

    if (filteredMetrics.isEmpty) {
      filteredMetrics = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .toList();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 135,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: filteredMetrics.length,
      itemBuilder: (context, index) {
        final metric = filteredMetrics[index];
        return DashboardTileWidget(
          metric: metric,
          data: statsMap,
          highlight: metric.titleKey == 'totalCompanies',
        );
      },
    );
  }
 */

  Widget _buildStatsGrid() {
    final statsMap = _stats.toMap();
    final filteredMetrics = _getFilteredMetrics();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 135,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: filteredMetrics.length,
      itemBuilder: (context, index) {
        final metric = filteredMetrics[index];
        // final value = statsMap[metric.titleKey];
        // final bool showLoading = _isDataLoading && value == null;

        return DashboardTileWidget(
          metric: metric,
          data: statsMap,
          highlight: metric.titleKey == 'totalCompanies',
          //isLoading: showLoading,
        );
      },
    );
  }

  List<DashboardMetric> _getFilteredMetrics() {
    if (_selectedCards.isEmpty) {
      final defaultViewType =
          _dashboardView == DashboardView.long ? 'long' : 'short';
      return dashboardMetrics
          .where((metric) => metric.defaultMenuType == defaultViewType)
          .toList();
    } else {
      return dashboardMetrics
          .where((metric) => _selectedCards.contains(metric.titleKey))
          .toList();
    }
  }

  Widget _buildLicenseExpiredWarning() {
    if (isAdmin) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('license_expired'),
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(tr('license_expired_message'),
                    style: TextStyle(color: Colors.red.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setupFCM() async {
    try {
      await _fcm.requestPermission();
      _notificationSubscription = FirebaseMessaging.onMessage.listen((message) {
        _showNotification(message);
      });
    } catch (e) {
      safeDebugPrint('❌ Error setting up FCM: $e');
    }
  }

  void _showNotification(RemoteMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? 'New Notification'),
        content: Text(message.notification?.body ?? 'New license request'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  @override
/*   Widget build(BuildContext context) {
    if (isLoading || userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AppScaffold(
      title: tr('dashboard'),
      userName: userName,
      isSubscriptionExpiringSoon: isSubscriptionExpiringSoon,
      isSubscriptionExpired: isSubscriptionExpired,
      isDashboard: true,
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _handleRefresh,
        enablePullDown: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('welcome_back', args: [userName ?? '']),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (isSubscriptionExpiringSoon) _buildTimeLeftBar(),
              if (isSubscriptionExpired && !isAdmin)
                _buildLicenseExpiredWarning(),
              const SizedBox(height: 16),
              _buildStatsGrid(),
              if (subscriptionTimeLeft != null &&
                  subscriptionTimeLeft!.contains('maximum number of devices'))
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: FloatingActionButton(
                    onPressed: () => context.push('/device-request'),
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.device_hub),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} */

  @override
  Widget build(BuildContext context) {
    // التحميل الأولي - يظهر فقط عند فتح الصفحة أول مرة
    if (_isInitialLoading) {
      return _buildInitialLoadingScreen();
    }

    return AppScaffold(
      title: tr('dashboard'),
      userName: userName,
      isSubscriptionExpiringSoon: isSubscriptionExpiringSoon,
      isSubscriptionExpired: isSubscriptionExpired,
      isDashboard: true,
      body: Stack(
        children: [
          SmartRefresher(
            controller: _refreshController,
            onRefresh: _handleRefresh,
            enablePullDown: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رسالة ترحيب
                  _buildWelcomeSection(),

                  // تحذيرات الاشتراك
                  if (isSubscriptionExpiringSoon) _buildTimeLeftBar(),
                  if (isSubscriptionExpired && !isAdmin)
                    _buildLicenseExpiredWarning(),

                  const SizedBox(height: 16),

                  // شبكة الإحصائيات
                  _buildStatsGrid(),

                  // زر طلب جهاز إضافي
                  if (subscriptionTimeLeft != null &&
                      subscriptionTimeLeft!
                          .contains('maximum number of devices'))
                    _buildDeviceRequestButton(),
                ],
              ),
            ),
          ),

          // مؤشر تحميل للبيانات الخلفية
          if (_isDataLoading && !_isRefreshing) _buildDataLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildInitialLoadingScreen() {
    return  Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(tr('loading_app'), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('welcome_back', args: [userName ?? '']),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (_isDataLoading) ...[
          const SizedBox(height: 8),
          Text(
             tr('updating_data'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildDataLoadingOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.blue.withAlpha(25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
               tr('updating_data'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceRequestButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: FloatingActionButton(
        onPressed: () => context.push('/device-request'),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.device_hub),
      ),
    );
  }
}

class DashboardStats {
  int totalCompanies;
  int totalSuppliers;
  int totalOrders;
  double totalAmount;
  int totalItems;
  int totalMovements;
  int totalManufacturingOrders;
  int totalFinishedProducts;
  int totalFactories;

  DashboardStats({
    required this.totalCompanies,
    required this.totalSuppliers,
    required this.totalOrders,
    required this.totalAmount,
    required this.totalItems,
    required this.totalMovements,
    required this.totalManufacturingOrders,
    required this.totalFinishedProducts,
    required this.totalFactories,
  });

  factory DashboardStats.empty() => DashboardStats(
        totalCompanies: 0,
        totalSuppliers: 0,
        totalOrders: 0,
        totalAmount: 0.0,
        totalItems: 0,
        totalMovements: 0,
        totalManufacturingOrders: 0,
        totalFinishedProducts: 0,
        totalFactories: 0,
      );

  void updateFrom(DashboardStats other) {
    totalCompanies = other.totalCompanies;
    totalSuppliers = other.totalSuppliers;
    totalOrders = other.totalOrders;
    totalAmount = other.totalAmount;
    totalItems = other.totalItems;
    totalMovements = other.totalMovements;
    totalManufacturingOrders = other.totalManufacturingOrders;
    totalFinishedProducts = other.totalFinishedProducts;
    totalFactories = other.totalFactories;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCompanies': totalCompanies,
      'totalSuppliers': totalSuppliers,
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'totalStockMovements': totalMovements,
      'totalManufacturingOrders': totalManufacturingOrders,
      'totalFinishedProducts': totalFinishedProducts,
      'totalFactories': totalFactories,
    };
  }
}
