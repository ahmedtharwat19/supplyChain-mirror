/* /* // widgets/app_scaffold.dart - النسخة المتوافقة مع أحدث إصدار من Flutter

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;
  final VoidCallback? onSettingsPressed;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
    this.isSubscriptionExpired = false,
    this.onSettingsPressed,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false;
  bool _isAdmin = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
    _loadUserNameFromHive();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserNameFromHive();
  }

  Future<void> _loadUserNameFromHive() async {
    try {
      final userData = await HiveService.getUserData();
      
      String? userName;

      if (userData != null) {
        userName = userData['displayName'] ?? 
                   userData['name'] ?? 
                   userData['email']?.split('@').first;
      }

      userName ??= 'User';

      if (mounted && _userName != userName) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadUserNameFromHive: $e');
      if (mounted && _userName != 'User') {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;

      if (isAdmin) {
        final licenseService = LicenseService();
        final hasPending = await licenseService.hasPendingLicenseRequests();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _hasPendingRequests = hasPending;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking admin notifications: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }

  /// ✅ دالة معالجة الرجوع للخلف باستخدام onPopInvokedWithResult (أحدث إصدار)
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    
    final currentPath = GoRouterState.of(context).uri.path;
    
    // ✅ إذا كنا في Dashboard، نطلب تأكيد الخروج
    if (currentPath == '/dashboard') {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('exit_title')),
          content: Text(tr('exit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('exit')),
            ),
          ],
        ),
      );
      
      if (shouldExit == true && mounted) {
        // إغلاق التطبيق
        Navigator.of(context).pop();
      }
      return;
    }
    
    // ✅ في الصفحات الأخرى، نرجع للصفحة السابقة
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  /// ✅ دالة معالجة زر الرجوع في الـ AppBar
  void _handleBackNavigation() {
    final currentPath = GoRouterState.of(context).uri.path;
    
    // ✅ في Dashboard، لا نفعل شيئاً
    if (currentPath == '/dashboard') {
      return;
    }
    
    // ✅ في الصفحات الأخرى، نرجع للصفحة السابقة
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = currentPath != '/dashboard';

    // ✅ استخدام PopScope مع onPopInvokedWithResult (أحدث إصدار)
    return PopScope(
      canPop: false, // منع الخروج التلقائي
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.isSubscriptionExpiringSoon
              ? Colors.red
              : const Color.fromARGB(255, 69, 200, 218),
          title: Text(widget.title ?? tr('dashboard_title')),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBackNavigation,
                )
              : null,
          actions: [
            ..._buildAppBarActions(context),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: _buildDrawer(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (_userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${tr('hello')}, $_userName',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              if (_isAdmin && _hasPendingRequests)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
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
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: Locale('en'),
            child: Text('English'),
          ),
          const PopupMenuItem(
            value: Locale('ar'),
            child: Text('العربية'),
          ),
        ],
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: tr('dashboard_title'),
            onTap: () => context.go('/dashboard'),
          ),
          _buildDrawerItem(
            icon: Icons.business,
            title: tr('manage_companies'),
            onTap: () => context.go('/companies'),
          ),
          _buildDrawerItem(
            icon: Icons.group,
            title: tr('manage_suppliers'),
            onTap: () => context.go('/suppliers'),
          ),
          _buildDrawerItem(
            icon: Icons.category,
            title: tr('manage_items'),
            onTap: () => context.go('/items'),
          ),
          _buildDrawerItem(
            icon: Icons.shopping_cart,
            title: tr('view_purchase_orders'),
            onTap: () => context.go('/purchase-orders'),
          ),
          if (_isAdmin)
            _buildDrawerItem(
              icon: Icons.security,
              title: tr('manage_licenses'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/licenses');
              },
            ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.storage,
            title: tr('hive_settings'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/hive-settings');
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop();
              final result = await context.push<bool>(
                '/settings',
                extra: dashboardMetrics.map((e) => e.titleKey).toList(),
              );
              if (!mounted) return;
              if (result == true) {
                if (!context.mounted) return;
                final dashboardState = context.findAncestorStateOfType<DashboardPageState>();
                if (dashboardState != null) {
                  await dashboardState.loadSettingsFromHive();
                }
              }
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            title: tr('logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final currentDate = DateTime.now();
    final formattedDate = 
        '${currentDate.day}/${currentDate.month}/${currentDate.year}';

    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 69, 200, 218),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? tr('guest_user'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName != null 
                            ? tr('welcome_message') 
                            : tr('login_to_start'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSubscriptionExpiringSoon || 
              (widget.isSubscriptionExpired && !_isAdmin))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isSubscriptionExpired ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isSubscriptionExpired 
                    ? tr('subscription_expired') 
                    : tr('subscription_expiring_soon'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
} */



/* 
// widgets/app_scaffold.dart - بدون Hive
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;
  final VoidCallback? onSettingsPressed;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
    this.isSubscriptionExpired = false,
    this.onSettingsPressed,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false;
  bool _isAdmin = false;
  String? _userName;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين
  static const String _keyUserData = 'user_data';
  static const String _keyUserName = 'user_name';

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
    _loadUserNameFromStorage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserNameFromStorage();
  }

  Future<void> _loadUserNameFromStorage() async {
    try {
      // ✅ أولاً: محاولة جلب اسم المستخدم من SharedPreferences (سريع)
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString(_keyUserName);
      
      // ✅ إذا لم يكن موجوداً، جربه من SecureStorage
      if (userName == null || userName.isEmpty || userName == 'User') {
        final userDataJson = await _secureStorage.read(key: _keyUserData);
        if (userDataJson != null) {
          final userData = json.decode(userDataJson) as Map<String, dynamic>;
          userName = userData['displayName']?.toString() ?? 
                     userData['name']?.toString() ?? 
                     userData['email']?.toString().split('@').first;
        }
      }

      userName ??= 'User';

      if (mounted && _userName != userName) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadUserNameFromStorage: $e');
      if (mounted && _userName != 'User') {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;

      if (isAdmin) {
        final licenseService = LicenseService();
        final hasPending = await licenseService.hasPendingLicenseRequests();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _hasPendingRequests = hasPending;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking admin notifications: $e');
    }
  }

  Future<void> _logout() async {
    try {
      // ✅ مسح جميع البيانات المخزنة
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _secureStorage.deleteAll();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }

  /// ✅ دالة معالجة الرجوع للخلف
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    
    final currentPath = GoRouterState.of(context).uri.path;
    
    if (currentPath == '/dashboard') {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('exit_title')),
          content: Text(tr('exit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('exit')),
            ),
          ],
        ),
      );
      
      if (shouldExit == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _handleBackNavigation() {
    final currentPath = GoRouterState.of(context).uri.path;
    
    if (currentPath == '/dashboard') {
      return;
    }
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = currentPath != '/dashboard';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.isSubscriptionExpiringSoon
              ? Colors.red
              : const Color.fromARGB(255, 69, 200, 218),
          title: Text(widget.title ?? tr('dashboard_title')),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBackNavigation,
                )
              : null,
          actions: [
            ..._buildAppBarActions(context),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: _buildDrawer(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (_userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${tr('hello')}, $_userName',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              if (_isAdmin && _hasPendingRequests)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
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
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: Locale('en'),
            child: Text('English'),
          ),
          const PopupMenuItem(
            value: Locale('ar'),
            child: Text('العربية'),
          ),
        ],
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: tr('dashboard_title'),
            onTap: () => context.go('/dashboard'),
          ),
          _buildDrawerItem(
            icon: Icons.business,
            title: tr('manage_companies'),
            onTap: () => context.go('/companies'),
          ),
          _buildDrawerItem(
            icon: Icons.group,
            title: tr('manage_suppliers'),
            onTap: () => context.go('/suppliers'),
          ),
          _buildDrawerItem(
            icon: Icons.category,
            title: tr('manage_items'),
            onTap: () => context.go('/items'),
          ),
          _buildDrawerItem(
            icon: Icons.shopping_cart,
            title: tr('view_purchase_orders'),
            onTap: () => context.go('/purchase-orders'),
          ),
          if (_isAdmin)
            _buildDrawerItem(
              icon: Icons.security,
              title: tr('manage_licenses'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/licenses');
              },
            ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop();
              final result = await context.push<bool>(
                '/settings',
                extra: dashboardMetrics.map((e) => e.titleKey).toList(),
              );
              if (!mounted) return;
              if (result == true) {
                if (!context.mounted) return;
                final dashboardState = context.findAncestorStateOfType<DashboardPageState>();
                if (dashboardState != null) {
                  await dashboardState.loadSettingsFromStorage();
                }
              }
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            title: tr('logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final currentDate = DateTime.now();
    final formattedDate = 
        '${currentDate.day}/${currentDate.month}/${currentDate.year}';

    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 69, 200, 218),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? tr('guest_user'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName != null 
                            ? tr('welcome_message') 
                            : tr('login_to_start'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSubscriptionExpiringSoon || 
              (widget.isSubscriptionExpired && !_isAdmin))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isSubscriptionExpired ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isSubscriptionExpired 
                    ? tr('subscription_expired') 
                    : tr('subscription_expiring_soon'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
} */

// widgets/app_scaffold.dart - النسخة المصححة
/* 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;
  final VoidCallback? onSettingsPressed;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
    this.isSubscriptionExpired = false,
    this.onSettingsPressed,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false;
  bool _isAdmin = false;
  String? _userName;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين
  static const String _keyUserData = 'user_data';
  static const String _keyUserName = 'user_name';

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
    _loadUserNameFromStorage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserNameFromStorage();
  }

  Future<void> _loadUserNameFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString(_keyUserName);
      
      if (userName == null || userName.isEmpty || userName == 'User') {
        final userDataJson = await _secureStorage.read(key: _keyUserData);
        if (userDataJson != null) {
          final userData = json.decode(userDataJson) as Map<String, dynamic>;
          userName = userData['displayName']?.toString() ?? 
                     userData['name']?.toString() ?? 
                     userData['email']?.toString().split('@').first;
        }
      }

      userName ??= 'User';

      if (mounted && _userName != userName) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadUserNameFromStorage: $e');
      if (mounted && _userName != 'User') {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;

      if (isAdmin) {
        final licenseService = LicenseService();
        final hasPending = await licenseService.hasPendingLicenseRequests();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _hasPendingRequests = hasPending;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking admin notifications: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _secureStorage.deleteAll();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }

  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    
    final currentPath = GoRouterState.of(context).uri.path;
    
    if (currentPath == '/dashboard') {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('exit_title')),
          content: Text(tr('exit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('exit')),
            ),
          ],
        ),
      );
      
      if (shouldExit == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _handleBackNavigation() {
    final currentPath = GoRouterState.of(context).uri.path;
    
    if (currentPath == '/dashboard') {
      return;
    }
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = currentPath != '/dashboard';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.isSubscriptionExpiringSoon
              ? Colors.red
              : const Color.fromARGB(255, 69, 200, 218),
          title: Text(widget.title ?? tr('dashboard_title')),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBackNavigation,
                )
              : null,
          actions: [
            ..._buildAppBarActions(context),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: _buildDrawer(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (_userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${tr('hello')}, $_userName',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              if (_isAdmin && _hasPendingRequests)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
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
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: Locale('en'),
            child: Text('English'),
          ),
          const PopupMenuItem(
            value: Locale('ar'),
            child: Text('العربية'),
          ),
        ],
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: tr('dashboard_title'),
            onTap: () => context.go('/dashboard'),
          ),
          _buildDrawerItem(
            icon: Icons.business,
            title: tr('manage_companies'),
            onTap: () => context.go('/companies'),
          ),
          _buildDrawerItem(
            icon: Icons.group,
            title: tr('manage_suppliers'),
            onTap: () => context.go('/suppliers'),
          ),
          _buildDrawerItem(
            icon: Icons.category,
            title: tr('manage_items'),
            onTap: () => context.go('/items'),
          ),
          _buildDrawerItem(
            icon: Icons.shopping_cart,
            title: tr('view_purchase_orders'),
            onTap: () => context.go('/purchase-orders'),
          ),
          if (_isAdmin)
            _buildDrawerItem(
              icon: Icons.security,
              title: tr('manage_licenses'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/licenses');
              },
            ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop();
              final result = await context.push<bool>(
                '/settings',
                extra: dashboardMetrics.map((e) => e.titleKey).toList(),
              );
              if (mounted && result == true) {
                // ✅ إعادة تحميل الإعدادات باستخدام Notification بدلاً من الـ State
                // إرسال إشعار لتحديث Dashboard
                // أو ببساطة إعادة تحميل الصفحة
                 

                if (context.mounted) {
                  // إعادة تحميل Dashboard
                  
                  context.go('/dashboard');
                }
              }
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            title: tr('logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final currentDate = DateTime.now();
    final formattedDate = 
        '${currentDate.day}/${currentDate.month}/${currentDate.year}';

    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 69, 200, 218),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? tr('guest_user'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName != null 
                            ? tr('welcome_message') 
                            : tr('login_to_start'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSubscriptionExpiringSoon || 
              (widget.isSubscriptionExpired && !_isAdmin))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isSubscriptionExpired ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isSubscriptionExpired 
                    ? tr('subscription_expired') 
                    : tr('subscription_expiring_soon'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
} */



/* 
// widgets/app_scaffold.dart - النسخة النهائية المحسنة

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;
  final VoidCallback? onSettingsPressed;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
    this.isSubscriptionExpired = false,
    this.onSettingsPressed,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false;
  bool _isAdmin = false;
  String? _userName;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyUserData = 'user_data';
  static const String _keyUserName = 'user_name';

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
    _loadUserNameFromStorage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserNameFromStorage();
  }

  Future<void> _loadUserNameFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString(_keyUserName);
      
      if (userName == null || userName.isEmpty || userName == 'User') {
        final userDataJson = await _secureStorage.read(key: _keyUserData);
        if (userDataJson != null) {
          final userData = json.decode(userDataJson) as Map<String, dynamic>;
          userName = userData['displayName']?.toString() ?? 
                     userData['name']?.toString() ?? 
                     userData['email']?.toString().split('@').first;
          if (userName != null && userName != 'User') {
            await prefs.setString(_keyUserName, userName);
          }
        }
      }

      userName ??= 'User';

      if (mounted && _userName != userName) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
      if (mounted && _userName != 'User') {
        setState(() => _userName = 'User');
      }
    }
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;

      if (isAdmin) {
        final licenseService = LicenseService();
        final hasPending = await licenseService.hasPendingLicenseRequests();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _hasPendingRequests = hasPending;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking admin: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _secureStorage.deleteAll();
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', locale.languageCode);
    if (mounted) setState(() {});
  }

  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    
    final currentPath = GoRouterState.of(context).uri.path;
    
    if (currentPath == '/dashboard') {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('exit_title')),
          content: Text(tr('exit_message')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('exit'))),
          ],
        ),
      );
      
      if (shouldExit == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _handleBackNavigation() {
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == '/dashboard') return;
    
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = currentPath != '/dashboard';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.isSubscriptionExpiringSoon
              ? Colors.red
              : const Color.fromARGB(255, 69, 200, 218),
          title: Text(widget.title ?? tr('dashboard_title')),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBackNavigation,
                )
              : null,
          actions: [
            ..._buildAppBarActions(context),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: _buildDrawer(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (_userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('${tr('hello')}, $_userName', style: const TextStyle(fontSize: 16, color: Colors.white)),
              if (_isAdmin && _hasPendingRequests)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          const PopupMenuItem(value: Locale('en'), child: Row(children: [Text('🇬🇧'), SizedBox(width: 8), Text('English')])),
          const PopupMenuItem(value: Locale('ar'), child: Row(children: [Text('🇸🇦'), SizedBox(width: 8), Text('العربية')])),
          const PopupMenuItem(value: Locale('fr'), child: Row(children: [Text('🇫🇷'), SizedBox(width: 8), Text('Français')])),
          const PopupMenuItem(value: Locale('es'), child: Row(children: [Text('🇪🇸'), SizedBox(width: 8), Text('Español')])),
          const PopupMenuItem(value: Locale('de'), child: Row(children: [Text('🇩🇪'), SizedBox(width: 8), Text('Deutsch')])),
          const PopupMenuItem(value: Locale('tr'), child: Row(children: [Text('🇹🇷'), SizedBox(width: 8), Text('Türkçe')])),
        ],
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(icon: Icons.dashboard, title: tr('dashboard_title'), onTap: () => context.go('/dashboard')),
          _buildDrawerItem(icon: Icons.business, title: tr('manage_companies'), onTap: () => context.go('/companies')),
          _buildDrawerItem(icon: Icons.group, title: tr('manage_suppliers'), onTap: () => context.go('/suppliers')),
          _buildDrawerItem(icon: Icons.category, title: tr('manage_items'), onTap: () => context.go('/items')),
          _buildDrawerItem(icon: Icons.shopping_cart, title: tr('view_purchase_orders'), onTap: () => context.go('/purchase-orders')),
          if (_isAdmin) _buildDrawerItem(icon: Icons.security, title: tr('manage_licenses'), onTap: () { Navigator.of(context).pop(); context.go('/admin/licenses'); }),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop();
              final result = await context.push<bool>(
                '/settings',
                extra: dashboardMetrics.map((e) => e.titleKey).toList(),
              );
              if (mounted && result == true && context.mounted) {
                context.go('/dashboard');
              }
            },
          ),
          const Divider(),
          _buildDrawerItem(icon: Icons.logout, title: tr('logout'), onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218), borderRadius: BorderRadius.only(bottomRight: Radius.circular(25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.person, size: 30, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName ?? tr('guest_user'), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_userName != null ? tr('welcome_message') : tr('login_to_start'), style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSubscriptionExpiringSoon || (widget.isSubscriptionExpired && !_isAdmin))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: widget.isSubscriptionExpired ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(12)),
              child: Text(widget.isSubscriptionExpired ? tr('subscription_expired') : tr('subscription_expiring_soon'), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
} */

// widgets/app_scaffold.dart - استخدام universal_html بدلاً من dart:html

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:universal_html/html.dart' as html;  // ✅ استخدام universal_html

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;
  final VoidCallback? onSettingsPressed;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
    this.isSubscriptionExpired = false,
    this.onSettingsPressed,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false;
  bool _isAdmin = false;
  String? _userName;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyUserData = 'user_data';
  static const String _keyUserName = 'user_name';

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
    _loadUserNameFromStorage();
    
    // ✅ للويب: منع أزرار الرجوع/التقدم في المتصفح
    if (kIsWeb) {
      _disableWebNavigation();
    }
  }

  void _disableWebNavigation() {
    // استخدام universal_html بدلاً من dart:html
    html.window.onPopState.listen((event) {
      // إضافة حالة جديدة لمنع الرجوع
      html.window.history.pushState(null, '', html.window.location.href);
    });
    // إضافة حالة أولية
    html.window.history.pushState(null, '', html.window.location.href);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserNameFromStorage();
  }

  Future<void> _loadUserNameFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString(_keyUserName);
      
      if (userName == null || userName.isEmpty || userName == 'User') {
        final userDataJson = await _secureStorage.read(key: _keyUserData);
        if (userDataJson != null) {
          final userData = json.decode(userDataJson) as Map<String, dynamic>;
          userName = userData['displayName']?.toString() ?? 
                     userData['name']?.toString() ?? 
                     userData['email']?.toString().split('@').first;
        }
      }

      userName ??= 'User';

      if (mounted && _userName != userName) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.data()?['isAdmin'] == true;

      if (isAdmin) {
        final licenseService = LicenseService();
        final hasPending = await licenseService.hasPendingLicenseRequests();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _hasPendingRequests = hasPending;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking admin: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _secureStorage.deleteAll();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', locale.languageCode);
    if (mounted) setState(() {});
  }

  /// ✅ دالة الرجوع للخلف
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    
    final currentPath = GoRouterState.of(context).uri.path;
    
    // ✅ قائمة الصفحات الرئيسية (التي لا نسمح بالرجوع منها)
    final List<String> mainPages = [
      '/dashboard',
      '/companies',
      '/suppliers',
      '/items',
      '/purchase-orders',
      '/factories',
      '/reports',
    ];
    
    // ✅ إذا كنا في صفحة رئيسية
    if (mainPages.contains(currentPath)) {
      // نطلب تأكيد الخروج من التطبيق
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('exit_title')),
          content: Text(tr('exit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('exit')),
            ),
          ],
        ),
      );
      
      if (shouldExit == true && mounted) {
        // ✅ إغلاق التطبيق
        if (kIsWeb) {
          html.window.close();
        } else {
          Navigator.of(context).pop();
        }
      }
      return;
    }
    
    // ✅ إذا كنا في صفحة فرعية، نرجع للصفحة السابقة
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _handleBackNavigation() {
    final currentPath = GoRouterState.of(context).uri.path;
    
    // قائمة الصفحات الرئيسية
    final List<String> mainPages = [
      '/dashboard',
      '/companies', 
      '/suppliers',
      '/items',
      '/purchase-orders',
      '/factories',
      '/reports',
    ];
    
    // ✅ إذا كانت صفحة رئيسية، لا تفعل شيئاً
    if (mainPages.contains(currentPath)) {
      return;
    }
    
    // ✅ إذا كانت صفحة فرعية، ارجع للخلف
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    
    // ✅ قائمة الصفحات الرئيسية
    final List<String> mainPages = [
      '/dashboard',
      '/companies',
      '/suppliers', 
      '/items',
      '/purchase-orders',
      '/factories',
      '/reports',
    ];
    
    // ✅ إظهار زر الرجوع فقط إذا كنا في صفحة فرعية
    final canGoBack = !mainPages.contains(currentPath);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.isSubscriptionExpiringSoon
              ? Colors.red
              : const Color.fromARGB(255, 69, 200, 218),
          title: Text(widget.title ?? tr('dashboard_title')),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBackNavigation,
                )
              : null,
          actions: [
            ..._buildAppBarActions(context),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: _buildDrawer(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (_userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${tr('hello')}, $_userName',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              if (_isAdmin && _hasPendingRequests)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
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
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          const PopupMenuItem(value: Locale('en'), child: Row(children: [Text('🇬🇧'), SizedBox(width: 8), Text('English')])),
          const PopupMenuItem(value: Locale('ar'), child: Row(children: [Text('🇸🇦'), SizedBox(width: 8), Text('العربية')])),
          const PopupMenuItem(value: Locale('fr'), child: Row(children: [Text('🇫🇷'), SizedBox(width: 8), Text('Français')])),
          const PopupMenuItem(value: Locale('es'), child: Row(children: [Text('🇪🇸'), SizedBox(width: 8), Text('Español')])),
          const PopupMenuItem(value: Locale('de'), child: Row(children: [Text('🇩🇪'), SizedBox(width: 8), Text('Deutsch')])),
          const PopupMenuItem(value: Locale('tr'), child: Row(children: [Text('🇹🇷'), SizedBox(width: 8), Text('Türkçe')])),
        ],
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(icon: Icons.dashboard, title: tr('dashboard_title'), onTap: () => context.go('/dashboard')),
          _buildDrawerItem(icon: Icons.business, title: tr('manage_companies'), onTap: () => context.go('/companies')),
          _buildDrawerItem(icon: Icons.group, title: tr('manage_suppliers'), onTap: () => context.go('/suppliers')),
          _buildDrawerItem(icon: Icons.category, title: tr('manage_items'), onTap: () => context.go('/items')),
          _buildDrawerItem(icon: Icons.shopping_cart, title: tr('view_purchase_orders'), onTap: () => context.go('/purchase-orders')),
          if (_isAdmin) _buildDrawerItem(icon: Icons.security, title: tr('manage_licenses'), onTap: () { Navigator.of(context).pop(); context.go('/admin/licenses'); }),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop();
              final result = await context.push<bool>(
                '/settings',
                extra: dashboardMetrics.map((e) => e.titleKey).toList(),
              );
              if (mounted && result == true && context.mounted) {
                context.go('/dashboard');
              }
            },
          ),
          const Divider(),
          _buildDrawerItem(icon: Icons.logout, title: tr('logout'), onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218), borderRadius: BorderRadius.only(bottomRight: Radius.circular(25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.person, size: 30, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName ?? tr('guest_user'), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_userName != null ? tr('welcome_message') : tr('login_to_start'), style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSubscriptionExpiringSoon || (widget.isSubscriptionExpired && !_isAdmin))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: widget.isSubscriptionExpired ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(12)),
              child: Text(widget.isSubscriptionExpired ? tr('subscription_expired') : tr('subscription_expiring_soon'), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
} */