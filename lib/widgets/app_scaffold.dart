/* import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
    this.actions,
    this.isSubscriptionExpiringSoon = false,
     this.isSubscriptionExpired= false,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    // Safe to use context after mounted check
    context.go('/login');
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    // Capture context before async operation
    final currentContext = context;
    await currentContext.setLocale(locale);

    if (mounted) {
      setState(() {});
    }
  }

  void _handleBackNavigation(BuildContext context) {
    final router = GoRouter.of(context);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (router.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath =
        GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final canGoBack = currentPath != '/dashboard';

    return Scaffold(
      appBar: AppBar(
        backgroundColor:widget.isSubscriptionExpiringSoon
            ? Colors.red
            : const Color.fromARGB(255, 69, 200, 218), // const Color.fromARGB(255, 69, 200, 218),
        title: Text(widget.title ?? tr('dashboard_title')),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _handleBackNavigation(context),
              )
            : null,
        actions: [
          ..._buildAppBarActions(context),
          if (widget.actions != null) ...widget.actions!,
        ],
//_buildAppBarActions(context),
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(child: widget.body),
      floatingActionButton: widget.floatingActionButton,
    );
  }

/*   List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      if (widget.userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              '${tr('hello')}, ${widget.userName}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: const Locale('en'),
            child:
                Text('English', style: Theme.of(context).textTheme.bodyMedium),
          ),
          PopupMenuItem(
            value: const Locale('ar'),
            child:
                Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    ];
  }
 */

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (widget.userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              '${tr('hello')}, ${widget.userName}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: const Locale('en'),
            child:
                Text('English', style: Theme.of(context).textTheme.bodyMedium),
          ),
          PopupMenuItem(
            value: const Locale('ar'),
            child:
                Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
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
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop(); // إغلاق Drawer

              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    allCards: dashboardMetrics.map((e) => e.titleKey).toList(),
                  ),
                ),
              );

              if (!context.mounted) return;

              if (result == true) {
                final dashboardState =
                    context.findAncestorStateOfType<DashboardPageState>();
                dashboardState?.loadSettings();
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
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            widget.userName != null
                ? '${tr('hello')}, ${widget.userName}'
                : tr('welcome'),
            style: const TextStyle(fontSize: 18, color: Colors.white),
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
}
 */
/* 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;

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
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }

  void _handleBackNavigation(BuildContext context) {
    final router = GoRouter.of(context);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (router.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final canGoBack = currentPath != '/dashboard';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.isSubscriptionExpiringSoon
            ? Colors.red
            : const Color.fromARGB(255, 69, 200, 218),
        title: Text(widget.title ?? tr('dashboard_title')),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _handleBackNavigation(context),
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
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (widget.userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              '${tr('hello')}, ${widget.userName}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      PopupMenuButton<Locale>(
        icon: const Icon(Icons.language, color: Colors.white),
        tooltip: tr('change_language'),
        onSelected: _handleLanguageChange,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: const Locale('en'),
            child: Text('English', style: Theme.of(context).textTheme.bodyMedium),
          ),
          PopupMenuItem(
            value: const Locale('ar'),
            child: Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
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
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: tr('settings.title'),
            onTap: () async {
              Navigator.of(context).pop(); // إغلاق Drawer
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    allCards: dashboardMetrics.map((e) => e.titleKey).toList(),
                  ),
                ),
              );
              if (!context.mounted) return;
              if (result == true) {
                final dashboardState = context.findAncestorStateOfType<DashboardPageState>();
                dashboardState?.loadSettings();
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
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            widget.userName != null ? '${tr('hello')}, ${widget.userName}' : tr('welcome'),
            style: const TextStyle(fontSize: 18, color: Colors.white),
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
}
 */

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';
//import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/license_service.dart';

// نفترض وجود خدمة للتراخيص مع دالة للتحقق من وجود طلبات ترخيص معلقة
/* class LicenseService {
  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.isNotEmpty;
  }
} */


//  late final LicenseService _licenseService;

class AppScaffold extends StatefulWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool isSubscriptionExpiringSoon;
  final bool isSubscriptionExpired;

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
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _hasPendingRequests = false; // هل هناك طلبات ترخيص معلقة؟
  bool _isAdmin = false; // هل المستخدم إدمن؟

  @override
  void initState() {
    super.initState();
    _checkAdminNotifications();
  }

  Future<void> _checkAdminNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _handleLanguageChange(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }

void _handleBackNavigation(BuildContext context) {
  if (context.canPop()) {
    context.pop(); // رجوع من خلال go_router stack
  } else {
    context.go('/dashboard'); // fallback عند الوصول للجذر
  }
}


  @override
  Widget build(BuildContext context) {
    // final currentPath =
    //     GoRouter.of(context).routeInformationProvider.value.uri.toString();

    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = currentPath != '/dashboard';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.isSubscriptionExpiringSoon
            ? Colors.red
            : const Color.fromARGB(255, 69, 200, 218),
        title: Text(widget.title ?? tr('dashboard_title')),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _handleBackNavigation(context),
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
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (!widget.isDashboard) return [];

    return [
      if (widget.userName != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${tr('hello')}, ${widget.userName}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              // هنا نضيف الدائرة الحمراء إذا المستخدم إدمن وهناك طلبات معلقة
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
          PopupMenuItem(
            value: const Locale('en'),
            child:
                Text('English', style: Theme.of(context).textTheme.bodyMedium),
          ),
          PopupMenuItem(
            value: const Locale('ar'),
            child:
                Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
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

          // إضافة عنصر خاص بالإدمن في Drawer إذا كان المستخدم إدمن
/*           if (_isAdmin)
            _buildDrawerItem(
              icon: Icons.security,
              title: tr('manage_licenses'),
              onTap: () => context.go('/admin/licenses'),
            ), */
          if (_isAdmin)
            _buildDrawerItem(
              icon: Icons.security,
              title: tr('manage_licenses'),
              onTap: () {
                Navigator.of(context).pop(); // إغلاق الـ Drawer
                context.go('/admin/licenses'); // توجيه
              },
            ),

          const Divider(),
          _buildDrawerItem(
             icon: Icons.settings,
            title: tr('settings.title'),
         /*   onTap: () async {
              Navigator.of(context).pop(); // إغلاق Drawer
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    allCards: dashboardMetrics.map((e) => e.titleKey).toList(),
                  ),
                ),
              );
              if (!context.mounted) return;
              if (result == true) {
                final dashboardState =
                    context.findAncestorStateOfType<DashboardPageState>();
                dashboardState?.loadSettings();
              }
            }, */
            onTap: () async {
  Navigator.of(context).pop(); // إغلاق Drawer

  final result = await context.push<bool>(
    '/settings',
    extra: dashboardMetrics.map((e) => e.titleKey).toList(),
  );

  if (!context.mounted) return;
  if (result == true) {
    final dashboardState = context.findAncestorStateOfType<DashboardPageState>();
    dashboardState?.loadSettings();
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
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            widget.userName != null
                ? '${tr('hello')}, ${widget.userName}'
                : tr('welcome'),
            style: const TextStyle(fontSize: 18, color: Colors.white),
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
}
