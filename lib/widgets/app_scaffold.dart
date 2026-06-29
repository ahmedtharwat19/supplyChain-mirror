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
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:universal_html/html.dart' as html;

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
  static const String _keyUserName = 'cached_user_name';
  static const List<String> _mainPages = [
    '/dashboard',
    '/companies',
    '/suppliers',
    '/items',
    '/purchase-orders',
    '/factories',
    '/reports',
    '/stock_movements',
    '/manufacturing_orders',
    '/finished_products',
  ];

  late final String _todayDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayDate = '${now.day}/${now.month}/${now.year}';
    _checkAdminNotifications();
    _loadUserNameFromStorage();

    if (kIsWeb) {
      _disableWebNavigation();
    }
  }

  bool _webNavDisabled = false;

  void _disableWebNavigation() {
    if (_webNavDisabled) return;
    _webNavDisabled = true;
    html.window.onPopState.listen((_) {
      html.window.history.pushState(null, '', html.window.location.href);
    });
    html.window.history.pushState(null, '', html.window.location.href);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void refreshUserName() {
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
    final isAdminStr = await _secureStorage.read(key: 'isAdmin');
    if (isAdminStr != 'true') return;

    final licenseService = LicenseService();
    final hasPending = await licenseService.hasPendingLicenseRequests();
    if (mounted) {
      setState(() {
        _isAdmin = true;
        _hasPendingRequests = hasPending;
      });
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

    if (_mainPages.contains(currentPath)) {
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(tr('exit')),
              ),
            ],
          ),
        );

        if (shouldExit == true && mounted) {
          if (kIsWeb) {
            try {
              html.window.close();
            } catch (e) {
              debugPrint('Error closing window: $e');
            }
          } else {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (mounted) {
          context.go('/dashboard');
        }
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

    if (_mainPages.contains(currentPath)) {
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  // ✅ دالة عرض نافذة "اتصل بنا" مع ترجمة كاملة
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('about_contact_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // نبذة تعريفية
                Text(
                  tr('about_description'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(tr('about_app_description')),
                const Divider(height: 24),

                // معلومات الاتصال
                Text(
                  tr('contact_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                    Icons.email, tr('contact_email'), 'ahmed.tharwat19@gmail.com'),
                _buildContactRow(
                    Icons.phone, tr('contact_phone'), '+201061007999'),
                _buildContactRow(
                    Icons.payment, tr('contact_vodafone_cash'), '01061007999'),
                _buildContactRow(
                    Icons.account_balance, tr('contact_bank_account'), tr('contact_bank_details')),
                const Divider(height: 24),

                // خطة الأسعار
                Text(
                  tr('pricing_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildPricingRow(tr('pricing_1_month'), '300 ${tr('egp')}', tr('pricing_for_1_device')),
                _buildPricingRow(tr('pricing_3_months'), '750 ${tr('egp')}', tr('pricing_for_1_device')),
                _buildPricingRow(tr('pricing_6_months'), '1,650 ${tr('egp')}', tr('pricing_for_1_device')),
                _buildPricingRow(tr('pricing_12_months'), '3,200 ${tr('egp')}', tr('pricing_for_1_device')),
                const SizedBox(height: 8),
                Text(
                  '⚠️ ${tr('pricing_extra_device_note')}',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                ),
                const Divider(height: 24),

                // البرامج المستقبلية
                Text(
                  tr('future_plans_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(tr('future_plans_description')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Flexible(child: Text('$label: $value')),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String duration, String price, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            flex: 2,
            child: Text(duration, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 1,
            child: Text(price, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(note, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = !_mainPages.contains(currentPath);

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
              child: Row(children: [
                Text('🇬🇧'),
                SizedBox(width: 8),
                Text('English')
              ])),
          const PopupMenuItem(
              value: Locale('ar'),
              child: Row(children: [
                Text('🇸🇦'),
                SizedBox(width: 8),
                Text('العربية')
              ])),
          const PopupMenuItem(
              value: Locale('fr'),
              child: Row(children: [
                Text('🇫🇷'),
                SizedBox(width: 8),
                Text('Français')
              ])),
          const PopupMenuItem(
              value: Locale('es'),
              child: Row(children: [
                Text('🇪🇸'),
                SizedBox(width: 8),
                Text('Español')
              ])),
          const PopupMenuItem(
              value: Locale('de'),
              child: Row(children: [
                Text('🇩🇪'),
                SizedBox(width: 8),
                Text('Deutsch')
              ])),
          const PopupMenuItem(
              value: Locale('tr'),
              child: Row(children: [
                Text('🇹🇷'),
                SizedBox(width: 8),
                Text('Türkçe')
              ])),
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
              onTap: () => context.go('/dashboard')),
          _buildDrawerItem(
              icon: Icons.business,
              title: tr('manage_companies'),
              onTap: () => context.go('/companies')),
          _buildDrawerItem(
              icon: Icons.group,
              title: tr('manage_suppliers'),
              onTap: () => context.go('/suppliers')),
          _buildDrawerItem(
              icon: Icons.category,
              title: tr('manage_items'),
              onTap: () => context.go('/items')),
          _buildDrawerItem(
              icon: Icons.shopping_cart,
              title: tr('view_purchase_orders'),
              onTap: () => context.go('/purchase-orders')),
          if (_isAdmin) ...[
            _buildDrawerItem(
                icon: Icons.security,
                title: tr('manage_licenses'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/admin/licenses');
                }),
            _buildDrawerItem(
                icon: Icons.manage_accounts,
                title: tr('manage_users'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/admin/users');
                }),
          ],
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
          // ✅ زر "اتصل بنا" مع ترجمة
          _buildDrawerItem(
            icon: Icons.contact_support,
            title: tr('about_contact'),
            onTap: () {
              Navigator.of(context).pop();
              _showAboutDialog(context);
            },
          ),
          const Divider(),
          _buildDrawerItem(
              icon: Icons.logout, title: tr('logout'), onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
          color: Color.fromARGB(255, 69, 200, 218),
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_todayDate,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                        color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.person,
                        size: 30, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName ?? tr('guest_user'),
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          _userName != null
                              ? tr('welcome_message')
                              : tr('login_to_start'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
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
                  color:
                      widget.isSubscriptionExpired ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  widget.isSubscriptionExpired
                      ? tr('subscription_expired')
                      : tr('subscription_expiring_soon'),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}