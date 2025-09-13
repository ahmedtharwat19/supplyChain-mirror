import 'dart:async';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
//import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/services/subscription_notifier.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';
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
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _licenseStatusSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//  final FirebaseAuth _auth = FirebaseAuth.instance;
//  late final LicenseService _licenseService;
  String? subscriptionTimeLeft;
  Timer? _timer;

  // Controllers and State
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};

  // Loading state
  bool isLoading = true;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  // Dashboard metrics
  final DashboardStats _stats = DashboardStats.empty();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription? _notificationSubscription;

  // User data
  String? userId;
  String? userName;
  List<String> userCompanyIds = [];

  @override
  void initState() {
    super.initState();
   //  _licenseService = LicenseService();
    safeDebugPrint('🔄 DashboardPage initState called');
    _initializeData();
    _checkSubscriptionStatus();
    _startListeningToUserChanges();
    _setupFCM();
    _checkInitialNotification();
    _setupLicenseStatusListener();
    _testExpiryDate();
    _checkLicenseExpiryStatus();
    _saveExpiryDateToLocalStorage();
        _listenForNewDeviceRequests();
    _listenForNewLicenseRequests();
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

        // فقط إشعار إذا الطلب جديد (أقل من 10 ثواني)
        if (difference.inSeconds < 10) {
          final userName = doc['displayName'];
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📝${'new_license_request'.tr()} $userName'),
              action: SnackBarAction(
                label: 'view'.tr(),
                onPressed: () {
                  DefaultTabController.of(context)
                      .animateTo(0); // الانتقال إلى تبويب التراخيص
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

        // فقط أظهر الإشعار إذا تم إنشاء الطلب في آخر 10 ثواني (حديث)
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
                  DefaultTabController.of(context)
                      .animateTo(2); // التوجه إلى تبويب الأجهزة
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
        safeDebugPrint('💾 Expiry date saved to local storage: $expiryDate');
      }
    } catch (e) {
      safeDebugPrint('❌ Error saving expiry date to local storage: $e');
    }
  }

  Future<DateTime?> _getExpiryDateFromLocalStorage() async {
    try {
      safeDebugPrint('📦 Getting expiry date from local storage');
      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString('expiry_date');

      if (expiryString != null) {
        safeDebugPrint('📦 Found expiry date in local storage: $expiryString');
        return DateTime.parse(expiryString);
      } else {
        safeDebugPrint('❌ No expiry date found in local storage');
      }
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from local storage: $e');
    }
    return null;
  }

  Widget _buildTimeLeftBar() {
    safeDebugPrint(
        '📊 Building time left bar. isExpiringSoon: $isSubscriptionExpiringSoon, timeLeft: $subscriptionTimeLeft');

    // إذا لم يكن الاشتراك على وشك الانتهاء أو لا يوجد وقت متبقي، لا تعرض أي شيء
    if (!isSubscriptionExpiringSoon ||
        subscriptionTimeLeft == null ||
        subscriptionTimeLeft!.isEmpty) {
      safeDebugPrint('📊 No need to show time left bar');
      return const SizedBox();
    }

    // إذا كانت الرسالة تتعلق بحدود الأجهزة، لا تعرض الشريط
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

        // تحديد اللون حسب الأيام المتبقية
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
              // العنوان
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

              // الرسالة التحذيرية
              Text(
                tr('license_expiring_message'),
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // الوقت المتبقي
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

              // تاريخ الانتهاء
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
        // احفظ التاريخ في التخزين المحلي للاستخدام المستقبلي
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('expiry_date', expiryDate.toIso8601String());
        safeDebugPrint('💾 Saved expiry date to local storage: $expiryDate');
      }

      return expiryDate;
    } catch (e) {
      safeDebugPrint('❌ Error getting expiry date from Firebase: $e');
      return null;
    }
  }

  void _checkLicenseExpiryStatus() async {
    safeDebugPrint('🔍 Checking license expiry status');
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

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

    // إذا كان الترخيص غير صالح بسبب حدود الأجهزة، لا تعتبره منتهياً
    // ولكن أظهر رسالة المستخدم
    if (!result.isValid &&
        subscriptionTimeLeft != null &&
        subscriptionTimeLeft!.contains('maximum number of devices')) {
      // أظهر رسالة للمستخدم حول حدود الأجهزة
      _showDeviceLimitWarning(subscriptionTimeLeft!);
    }

    // تأكد من حفظ تاريخ الانتهاء في التخزين المحلي
    if (result.expiryDate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'expiry_date', result.expiryDate!.toIso8601String());
      safeDebugPrint('💾 Saved expiry date from check: ${result.expiryDate}');
    }
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
    // إصلاح: استخدام Timestamp مباشرة بدلاً من seconds و nanoseconds
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
    await _syncUserData();
    await _reloadUserData();
    await loadSettings();
    await _loadInitialData();

    // تحقق من انتهاء الصلاحية بعد تحميل البيانات
    await _checkIfLicenseExpired();
  }

  Future<void> _checkIfLicenseExpired() async {
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (result.isExpired && mounted) {
      safeDebugPrint('⏰ License expired during initialization, redirecting...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/license/request');
        }
      });
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/license/request');
          }
        });
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/license/request');
          }
        });
      }
    });
  }

  Future<void> _setupFCM() async {
    safeDebugPrint('📱 Setting up FCM');
    await _fcm.requestPermission();
    _notificationSubscription = FirebaseMessaging.onMessage.listen((message) {
      _showNotification(message);
    });
    safeDebugPrint(
        '✅ FCM onMessage listener initialized: $_notificationSubscription');
  }

  void _checkInitialNotification() async {
    safeDebugPrint('🔔 Checking for initial notification');
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      safeDebugPrint('🔔 Initial notification found: ${initialMessage.data}');
      _handleNotification(initialMessage);
    } else {
      safeDebugPrint('🔔 No initial notification found');
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

  void _showNotification(RemoteMessage message) {
    safeDebugPrint('📲 Showing notification: ${message.notification?.title}');
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

      final localUser = await UserLocalStorage.getUser();
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

      if (localCreatedAt == null ||
          !localCreatedAt.isAtSameMomentAs(cloudCreatedAt!) ||
          localDuration != cloudDuration ||
          localIsActive != cloudIsActive) {
        needUpdate = true;
      }
      if (localCreatedAt != null && cloudCreatedAt != null) {
        safeDebugPrint(
            '📏 Time diff: ${localCreatedAt.difference(cloudCreatedAt).inMilliseconds} ms');
      }

      if (needUpdate) {
        await UserLocalStorage.saveUser(
          userId: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName,
          companyIds: (data['companyIds'] is List)
              ? (data['companyIds'] as List).cast<String>()
              : [],
          factoryIds: (data['factoryIds'] is List)
              ? (data['factoryIds'] as List).cast<String>()
              : [],
          supplierIds: (data['supplierIds'] is List)
              ? (data['supplierIds'] as List).cast<String>()
              : [],
          createdAt: cloudCreatedAt!,
          subscriptionDurationInDays: cloudDuration,
          isActive: cloudIsActive,
        );

        safeDebugPrint('✅ Local user data updated from Firestore.');

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
    });
  }

  Future<void> _reloadUserData() async {
    safeDebugPrint('🔄 Reloading user data');
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
      userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      _stats.totalCompanies = userCompanyIds.length;
      final createdAt = user['createdAt'] as DateTime?;
      final subscriptionDuration = user['subscriptionDurationInDays'] as int?;
      final isActive = user['isActive'] as bool?;

      safeDebugPrint(
          '🔁 Local reload: createdAt=$createdAt, duration=$subscriptionDuration, isActive=$isActive');
    });
  }

  Future<void> loadSettings() async {
    safeDebugPrint('⚙️ Loading settings');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dashboardView = prefs.getString(prefDashboardView) == 'long'
          ? DashboardView.long
          : DashboardView.short;
      _selectedCards = (prefs.getStringList(prefSelectedCards) ?? []).toSet();
    });
  }

  Future<void> _loadInitialData() async {
    safeDebugPrint('📊 Loading initial data');
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
      userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      _stats.totalCompanies = userCompanyIds.length;
    });

    await _loadCachedData();
    await fetchStats();
  }

  Future<void> _checkSubscriptionStatus() async {
    safeDebugPrint('🔍 Checking subscription status');
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

    setState(() {
      isSubscriptionExpiringSoon = result.isExpiringSoon;
      isSubscriptionExpired = result.isExpired;
      subscriptionTimeLeft = result.timeLeftFormatted;
      isLoading = false;
    });

    _debugSubscriptionStatus(); // إضافة لعرض حالة الاشتراك

    _timer?.cancel();
    // if (!result.isExpired && result.expiryDate != null) {
    //   _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
    //     final updated = await subscriptionService.checkUserSubscription();
    //     if (mounted) {
    //       setState(() => subscriptionTimeLeft = updated.timeLeftFormatted);
    //     }
    //   });
    // }

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
    safeDebugPrint('💾 Loading cached data');
    final cached = await UserLocalStorage.getDashboardData();
    final extended = await UserLocalStorage.getExtendedStats();

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
  }

  Future<void> fetchStats() async {
    safeDebugPrint('📈 Fetching stats');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => isLoading = true);

    try {
      final localUser = await UserLocalStorage.getUser();
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
    safeDebugPrint('🔄 Syncing user data');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!userDoc.exists) return;

    final data = userDoc.data();
    if (data == null) return;

    final Timestamp? createdAtTimestamp = data['createdAt'];
    final createdAt = createdAtTimestamp?.toDate();
    final subscriptionDurationInDays = data['subscriptionDurationInDays'] ?? 30;
    final isActive = data['isActive'] ?? true;

    final localUser = await UserLocalStorage.getUser();

    bool needUpdateLocal = false;

    if (localUser == null) {
      needUpdateLocal = true;
    } else {
      final localCreatedAt = localUser['createdAt'] as DateTime?;
      final localSubscriptionDuration =
          localUser['subscriptionDurationInDays'] ?? 30;
      final localIsActive = localUser['isActive'] ?? true;

      if (localCreatedAt == null ||
          !isSameDate(localCreatedAt, createdAt) ||
          localSubscriptionDuration != subscriptionDurationInDays ||
          localIsActive != isActive) {
        needUpdateLocal = true;
      }
    }

    if (needUpdateLocal) {
      await UserLocalStorage.saveUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        companyIds: (data['companyIds'] as List?)?.cast<String>() ?? [],
        factoryIds: (data['factoryIds'] as List?)?.cast<String>() ?? [],
        supplierIds: (data['supplierIds'] as List?)?.cast<String>() ?? [],
        createdAt: createdAt,
        subscriptionDurationInDays: subscriptionDurationInDays,
        isActive: isActive,
      );

      if (mounted) {
        setState(() {
          userName = firebaseUser.displayName;
          userId = firebaseUser.uid;
          userCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
        });
      }
    }
  }

  Future<void> _saveToLocalStorage() async {
    safeDebugPrint('💾 Saving to local storage');
    await UserLocalStorage.saveDashboardData(
      totalCompanies: _stats.totalCompanies,
      totalSuppliers: _stats.totalSuppliers,
      totalOrders: _stats.totalOrders,
      totalAmount: _stats.totalAmount,
    );

    await UserLocalStorage.saveExtendedStats(
      totalFactories: _stats.totalFactories,
      totalItems: _stats.totalItems,
      totalStockMovements: _stats.totalMovements,
      totalManufacturingOrders: _stats.totalManufacturingOrders,
      totalFinishedProducts: _stats.totalFinishedProducts,
    );
  }

  Future<void> _handleRefresh() async {
    safeDebugPrint('🔄 Handling refresh');
    try {
      await _syncUserData();
      await fetchStats();

      // تحقق من حالة الاشتراك بعد التحديث
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (result.isExpired && mounted) {
        safeDebugPrint('⏰ License expired after refresh, redirecting...');
        context.go('/license/request');
        return;
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

    final filteredMetrics = _selectedCards.isEmpty
        ? dashboardMetrics.where((metric) =>
            metric.defaultMenuType ==
            (_dashboardView == DashboardView.long ? 'long' : 'short'))
        : dashboardMetrics
            .where((metric) => _selectedCards.contains(metric.titleKey));

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
        final metric = filteredMetrics.elementAt(index);
        return DashboardTileWidget(
          metric: metric,
          data: statsMap,
          highlight: metric.titleKey == 'totalCompanies',
        );
      },
    );
  }

  Widget _buildLicenseExpiredWarning() {
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
    safeDebugPrint('🏗️ Building DashboardPage');
    return AppScaffold(
      title: tr('dashboard'),
      userName: userName,
      isSubscriptionExpiringSoon: isSubscriptionExpiringSoon,
      isSubscriptionExpired: isSubscriptionExpired,
      isDashboard: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SmartRefresher(
              controller: _refreshController,
              onRefresh: _handleRefresh,
              enablePullDown: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // رسالة الترحيب
                    Text(
                      tr('welcome_back', args: [userName ?? '']),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // عرض شريط الوقت المتبقي فقط إذا كان الاشتراك على وشك الانتهاء
                    if (isSubscriptionExpiringSoon) _buildTimeLeftBar(),

                    // عرض تحذير انتهاء الترخيص فقط (تم إزالة التحذير المكرر)
                    if (isSubscriptionExpired) _buildLicenseExpiredWarning(),

                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    // في AppScaffold أو مكان مناسب
                    if (subscriptionTimeLeft != null &&
                        subscriptionTimeLeft!
                            .contains('maximum number of devices'))
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: FloatingActionButton(
                          onPressed: () {
                            // انتقل إلى صفحة إدارة الأجهزة
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



/*   Widget _buildTimeLeftBarWithFallbackDate() {
    // حاول الحصول على تاريخ الانتهاء من Firebase مباشرة
    return FutureBuilder<DateTime?>(
      future: _getExpiryDateFromFirebase(),
      builder: (context, firebaseSnapshot) {
        if (firebaseSnapshot.connectionState != ConnectionState.done ||
            !firebaseSnapshot.hasData) {
          return const SizedBox();
        }

        final expiryDate = firebaseSnapshot.data!;
        return _buildTimeLeftBarContent(expiryDate, subscriptionTimeLeft!);
      },
    );
  }
 */


/*   Widget _buildTimeLeftBar() {
    safeDebugPrint(
        '📊 Building time left bar. isExpiringSoon: $isSubscriptionExpiringSoon, timeLeft: $subscriptionTimeLeft');

    // إذا لم يكن الاشتراك على وشك الانتهاء، لا تعرض أي شيء
    if (!isSubscriptionExpiringSoon) {
      safeDebugPrint('📊 License is not expiring soon, hiding time left bar');
      return const SizedBox();
    }

    // إذا لم يكن هناك وقت متبقي، لا تعرض أي شيء
    if (subscriptionTimeLeft == null || subscriptionTimeLeft!.isEmpty) {
      safeDebugPrint('❌ No time left data available');
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

        // تحديد اللون حسب الأيام المتبقية
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
              // العنوان
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

              // الرسالة التحذيرية
              Text(
                tr('license_expiring_message'),
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // الوقت المتبقي
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

              // تاريخ الانتهاء
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
 */


/*   Widget _buildTimeLeftBarContent(DateTime expiryDate, String timeLeft) {
    final now = DateTime.now();
    final totalDays = 30;
    final daysLeft = expiryDate.difference(now).inDays;
    final progress = (daysLeft / totalDays).clamp(0.0, 1.0);

    safeDebugPrint(
        '📅 Expiry date: $expiryDate, Now: $now, Days left: $daysLeft, Progress: $progress');

    // تحديد اللون حسب الأيام المتبقية
    Color progressColor;
    if (daysLeft > 7) {
      progressColor = Colors.green;
    } else if (daysLeft > 4) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    safeDebugPrint('🎨 Progress color: $progressColor');

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
          // العنوان
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: progressColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                tr('license'),
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // شريط التقدم
          LinearProgressIndicator(
            value: progress,
            backgroundColor: progressColor.withAlpha(80),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),

          // الوقت المتبقي
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
                timeLeft,
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // تاريخ الانتهاء
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

          // رسالة تحذير إذا كان الوقت قليل
          if (daysLeft <= 7)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                tr('renew_license_warning'),
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
 */

/*   void _checkLicenseExpiryStatus() async {
    safeDebugPrint('🔍 Checking license expiry status');
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

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

    // تأكد من حفظ تاريخ الانتهاء في التخزين المحلي
    if (result.expiryDate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'expiry_date', result.expiryDate!.toIso8601String());
      safeDebugPrint('💾 Saved expiry date from check: ${result.expiryDate}');
    }
  }
 */
/*   String _formatTimeLeft(Duration difference) {
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return tr('time_left_days', namedArgs: {
        'days': days.toString(),
        'hours': hours.toString(),
      });
    } else if (hours > 0) {
      return tr('time_left_hours', namedArgs: {
        'hours': hours.toString(),
        'minutes': minutes.toString(),
      });
    } else {
      return tr('time_left_minutes', namedArgs: {
        'minutes': minutes.toString(),
      });
    }
  }
 */
 
 /*   Widget _buildLicenseExpiringWarning() {
    safeDebugPrint('⚠️ Building license expiring warning');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('license_expiring_soon'),
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('license_expiring_message',
                      args: [subscriptionTimeLeft ?? '']),
                  style: TextStyle(
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                if (subscriptionTimeLeft != null)
                  Text(
                    '⏰ ${tr('time_left')}: $subscriptionTimeLeft',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 */
