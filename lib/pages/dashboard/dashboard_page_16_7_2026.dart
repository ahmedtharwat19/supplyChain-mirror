/* import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/pages/settings/settings_page.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:puresip_purchasing/providers/dashboard_settings_provider.dart';
import 'package:puresip_purchasing/services/stats_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DashboardView { short, long }

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final RefreshController _refreshController = RefreshController();
  final StatsService _statsService = StatsService();

  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};
  bool isLoading = true;
  bool isAdmin = false;

  final DashboardStats _stats = DashboardStats();
  String? userName;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  String? subscriptionTimeLeft;

  final List<String> _allCardKeys =
      dashboardMetrics.map((m) => m.titleKey).toList();

  Timer? _periodicUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    _periodicUpdateTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _updateStatsInBackground();
    });
  }

/*   Future<void> _loadData() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    await Future.wait([
      _loadUserData(user.uid),
      _loadStats(user.uid),
      _loadSettings(),
    ]);

    setState(() => isLoading = false);
  }
 */

  Future<void> _loadData() async {
    // ── 1. اقرأ الكاش فوراً بدون loading ──
    await _loadFromCache();
    await _loadSettings();
    if (mounted) setState(() => isLoading = false);

    // ── 2. حدّث من Firestore في الخلفية ──
    _refreshInBackground();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // اسم المستخدم
      final cachedName = prefs.getString('cached_user_name');
      if (cachedName != null) userName = cachedName;

      // الإحصائيات
      final cached = prefs.getString('cached_stats');
      if (cached != null) {
        final data = json.decode(cached) as Map<String, dynamic>;
        _stats.totalCompanies = data['totalCompanies'] ?? 0;
        _stats.totalSuppliers = data['totalSuppliers'] ?? 0;
        _stats.totalOrders = data['totalOrders'] ?? 0;
        _stats.totalItems = data['totalItems'] ?? 0;
        _stats.totalManufacturingOrders = data['totalManufacturingOrders'] ?? 0;
        _stats.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
        _stats.totalFactories = data['totalFactories'] ?? 0;
        _stats.totalFinishedProducts = data['totalFinishedProducts'] ?? 0;
        _stats.totalStockMovements = data['totalStockMovements'] ?? 0;
      }
    } catch (e) {
      safeDebugPrint('Cache read error: $e');
    }
  }

/* Future<void> _refreshInBackground() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // جلب بيانات المستخدم
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();

  //  if (!userDoc.exists) return;
  if (!userDoc.exists) {
  safeDebugPrint('⚠️ User document not found in Firestore — signing out');
  await FirebaseAuth.instance.signOut();
  if (mounted) context.go('/login');
  return;
}
    final data = userDoc.data()!;
    isAdmin = data['isAdmin'] == true;

    final companyIds = List<String>.from(data['companyIds'] ?? []);

    // اسم المستخدم
    final displayName = data['displayName'] ?? data['name'] ?? '';
    final newName = displayName.isNotEmpty
        ? displayName
        : user.email?.split('@').first ?? 'User';

    // تحديث الإحصائيات
    await _statsService.updateUserStats(user.uid);
    final stats = await _statsService.getUserStats(user.uid);

    // حفظ في الكاش
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_name', newName);
    await prefs.setString('cached_stats', json.encode({
      ...stats,
      'totalCompanies': companyIds.length,
    }));

    if (mounted) {
      setState(() {
        userName = newName;
        _stats.totalCompanies           = companyIds.length;
        _stats.totalSuppliers           = stats['totalSuppliers'] ?? 0;
        _stats.totalOrders              = stats['totalOrders'] ?? 0;
        _stats.totalItems               = stats['totalItems'] ?? 0;
        _stats.totalManufacturingOrders = stats['totalManufacturingOrders'] ?? 0;
        _stats.totalAmount              = (stats['totalAmount'] ?? 0.0).toDouble();
        _stats.totalFactories           = stats['totalFactories'] ?? 0;
        _stats.totalFinishedProducts    = stats['totalFinishedProducts'] ?? 0;
        _stats.totalStockMovements      = stats['totalStockMovements'] ?? 0;
      });
    }
  } catch (e) {
    safeDebugPrint('Background refresh error: $e');
  }
}
  */

  Future<void> _refreshInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // جلب بيانات المستخدم
      DocumentSnapshot userDoc;
      try {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          safeDebugPrint('⛔ Permission denied reading user doc — signing out');
          await FirebaseAuth.instance.signOut();
          if (mounted) context.go('/login');
        } else {
          safeDebugPrint('Firestore error fetching user doc: $e');
        }
        return;
      }

      if (!userDoc.exists) {
        safeDebugPrint('⚠️ User document not found in Firestore — signing out');
        await FirebaseAuth.instance.signOut();
        if (mounted) context.go('/login');
        return;
      }
      final data = userDoc.data()! as Map<String, dynamic>;
      isAdmin = data['isAdmin'] == true;

      final companyIds = List<String>.from(data['companyIds'] ?? []);

      // اسم المستخدم
      final displayName = data['displayName'] ?? data['name'] ?? '';
      final newName = displayName.isNotEmpty
          ? displayName
          : user.email?.split('@').first ?? 'User';

      // تحديث الإحصائيات
      Map<String, dynamic> stats;
      try {
        await _statsService.updateUserStats(user.uid);
        stats = await _statsService.getUserStats(user.uid);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          safeDebugPrint('⛔ Permission denied on stats — signing out');
          await FirebaseAuth.instance.signOut();
          if (mounted) context.go('/login');
          return;
        }
        safeDebugPrint('Stats Firestore error: $e');
        return;
      }

      // حفظ في الكاش
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_name', newName);
      await prefs.setString(
          'cached_stats',
          json.encode({
            ...stats,
            'totalCompanies': companyIds.length,
          }));

      if (mounted) {
        setState(() {
          userName = newName;
          _stats.totalCompanies = companyIds.length;
          _stats.totalSuppliers = stats['totalSuppliers'] ?? 0;
          _stats.totalOrders = stats['totalOrders'] ?? 0;
          _stats.totalItems = stats['totalItems'] ?? 0;
          _stats.totalManufacturingOrders =
              stats['totalManufacturingOrders'] ?? 0;
          _stats.totalAmount = (stats['totalAmount'] ?? 0.0).toDouble();
          _stats.totalFactories = stats['totalFactories'] ?? 0;
          _stats.totalFinishedProducts = stats['totalFinishedProducts'] ?? 0;
          _stats.totalStockMovements = stats['totalStockMovements'] ?? 0;
        });
      }
    } catch (e) {
      safeDebugPrint('Background refresh error: $e');
    }
  }

  Future<void> _loadSettings() async {
    final settingsProvider =
        Provider.of<DashboardSettingsProvider>(context, listen: false);
    _dashboardView = settingsProvider.dashboardView == 'long'
        ? DashboardView.long
        : DashboardView.short;
    _selectedCards = settingsProvider.selectedCards.isNotEmpty
        ? settingsProvider.selectedCards
        : _getDefaultCards();
  }

  /*  Future<void> _loadUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        isAdmin = data['isAdmin'] == true;

        final companyIds = List<String>.from(data['companyIds'] ?? []);
        _stats.totalCompanies = companyIds.length;

        String displayName = data['displayName'] ?? '';
        String name = data['name'] ?? '';
        String email = data['email'] ?? '';

        if (displayName.isNotEmpty) {
          userName = displayName;
        } else if (name.isNotEmpty && name != 'User') {
          userName = name;
        } else if (email.isNotEmpty) {
          userName = email.split('@').first;
        } else {
          userName = 'User';
        }
      }
    } catch (e) {
      safeDebugPrint('Error loading user: $e');
    }
  }
 */

  Future<void> _loadStats(String userId) async {
    try {
      // ✅ استعلام واحد فقط من Firestore! 🚀
      final stats = await _statsService.getUserStats(userId);

      setState(() {
        _stats.totalSuppliers = stats['totalSuppliers'];
        _stats.totalOrders = stats['totalOrders'];
        _stats.totalItems = stats['totalItems'];
        _stats.totalManufacturingOrders = stats['totalManufacturingOrders'];
        _stats.totalAmount = stats['totalAmount'];
        _stats.totalFactories = stats['totalFactories'];
        _stats.totalFinishedProducts = stats['totalFinishedProducts'];
        _stats.totalStockMovements = stats['totalStockMovements'];
      });

      safeDebugPrint('✅ Stats loaded from user document!');
    } catch (e) {
      safeDebugPrint('Error loading stats: $e');
      // محاولة تحميل من الكاش
      await _loadStatsFromCache();
    }
  }

  Future<void> _loadStatsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_stats');
      if (cached != null) {
        final data = json.decode(cached) as Map<String, dynamic>;
        _stats.totalSuppliers = data['totalSuppliers'] ?? 0;
        _stats.totalOrders = data['totalOrders'] ?? 0;
        _stats.totalItems = data['totalItems'] ?? 0;
        _stats.totalManufacturingOrders = data['totalManufacturingOrders'] ?? 0;
        _stats.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
        _stats.totalFactories = data['totalFactories'] ?? 0;
        _stats.totalFinishedProducts = data['totalFinishedProducts'] ?? 0;
        _stats.totalStockMovements = data['totalStockMovements'] ?? 0;
      }
    } catch (e) {
      safeDebugPrint('Cache error: $e');
    }
  }

  Future<void> _updateStatsInBackground() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _statsService.updateUserStats(user.uid);
      if (mounted) {
        await _loadStats(user.uid);
      }
    }
  }

  Set<String> _getDefaultCards() {
    if (_dashboardView == DashboardView.long) {
      return dashboardMetrics.map((m) => m.titleKey).toSet();
    }
    return dashboardMetrics
        .where((m) => m.defaultMenuType == 'short')
        .map((m) => m.titleKey)
        .toSet();
  }

  Future<void> _refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _statsService.updateUserStats(user.uid);
      await _loadData();
    }
    _refreshController.refreshCompleted();
  }

  void _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(allCards: _allCardKeys)),
    );
    if (result == true && mounted) {
      await _loadSettings();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<DashboardSettingsProvider>(
      builder: (context, settingsProvider, child) {
        _dashboardView = settingsProvider.dashboardView == 'long'
            ? DashboardView.long
            : DashboardView.short;
        _selectedCards = settingsProvider.selectedCards.isNotEmpty
            ? settingsProvider.selectedCards
            : _getDefaultCards();

        if (isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return AppScaffold(
          title: tr('dashboard'),
          userName: userName,
          isSubscriptionExpiringSoon: isSubscriptionExpiringSoon,
          isSubscriptionExpired: isSubscriptionExpired,
          isDashboard: true,
          onSettingsPressed: _openSettings,
/*           actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _statsService.updateUserStats(user.uid);
                  await _loadStats(user.uid);
                  setState(() {});
     
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stats updated!')),
                    );

                }
              },
            ),
          ], */
          body: SmartRefresher(
            controller: _refreshController,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildWelcome(),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('welcome_back', args: [userName ?? '']),
            style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final statsMap = _stats.toMap();
    final filtered = dashboardMetrics
        .where((m) => _selectedCards.contains(m.titleKey))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(tr('no_cards_selected')),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: Text(tr('customize_dashboard')),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 135,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => DashboardTileWidget(
        metric: filtered[index],
        data: statsMap,
        highlight: filtered[index].titleKey == 'totalCompanies',
      ),
    );
  }

  @override
  void dispose() {
    _periodicUpdateTimer?.cancel();
    _refreshController.dispose();
    super.dispose();
  }
}

// في dashboard_page.dart - داخل DashboardStats

// في dashboard_page.dart

class DashboardStats {
  int totalCompanies = 0;
  int totalSuppliers = 0;
  int totalOrders = 0;
  int totalItems = 0;
  int totalStockMovements = 0;
  int totalManufacturingOrders = 0;
  int totalFinishedProducts = 0;
  int totalFactories = 0;
  double totalAmount = 0.0;

  // ✅ عدد التقارير من الدالة المساعدة
  int get totalReports => getTotalReportsCount();

  Map<String, dynamic> toMap() => {
        'totalCompanies': totalCompanies,
        'totalSuppliers': totalSuppliers,
        'totalOrders': totalOrders,
        'totalAmount': totalAmount,
        'totalItems': totalItems,
        'totalStockMovements': totalStockMovements,
        'totalManufacturingOrders': totalManufacturingOrders,
        'totalFinishedProducts': totalFinishedProducts,
        'totalFactories': totalFactories,
        'totalReports': totalReports,
      };
}
/* class DashboardStats {
  int totalCompanies = 0;
  int totalSuppliers = 0;
  int totalOrders = 0;
  int totalItems = 0;
  int totalStockMovements = 0;
  int totalManufacturingOrders = 0;
  int totalFinishedProducts = 0;
  int totalFactories = 0;
  int totalReports = 7;
  double totalAmount = 0.0;

  Map<String, dynamic> toMap() => {
        'totalCompanies': totalCompanies,
        'totalSuppliers': totalSuppliers,
        'totalOrders': totalOrders,
        'totalAmount': totalAmount,
        'totalItems': totalItems,
        'totalStockMovements': totalStockMovements,
        'totalManufacturingOrders': totalManufacturingOrders,
        'totalFinishedProducts': totalFinishedProducts,
        'totalFactories': totalFactories,
        'totalReports': totalReports,
      };
}
 */
 */