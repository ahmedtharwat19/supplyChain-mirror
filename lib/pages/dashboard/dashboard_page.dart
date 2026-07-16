// pages/dashboard/dashboard_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};
  bool isLoading = true;

  final DashboardStats _stats = DashboardStats();
  String? userName;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  String? subscriptionTimeLeft;

  Uint8List? _logoBytes;

  final List<String> _allCardKeys =
      dashboardMetrics.map((m) => m.titleKey).toList();

  Timer? _periodicUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadProviderSettings(); // ✅ تحميل الإعدادات من SharedPreferences عبر Provider
    _loadData();
    _startPeriodicUpdate();
    _loadLogo();
  }

  // ✅ تحميل الإعدادات من Provider (يقرأ من SharedPreferences)
  Future<void> _loadProviderSettings() async {
    try {
      final settingsProvider = Provider.of<DashboardSettingsProvider>(context, listen: false);
      await settingsProvider.loadSettings(); // هذا السطر هو المفتاح
      safeDebugPrint('✅ Settings loaded from provider');
    } catch (e) {
      safeDebugPrint('❌ Error loading provider settings: $e');
    }
  }

  Future<void> _loadLogo() async {
    try {
      String? logo;

      final possibleKeys = ['logoBase64', 'company_logo', 'logo', 'companyLogo'];
      for (final key in possibleKeys) {
        logo = await _secureStorage.read(key: key);
        if (logo != null && logo.isNotEmpty) break;
      }

      if (logo == null || logo.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        logo = prefs.getString('company_logo') ?? prefs.getString('logo');
      }

      if (logo != null && logo.isNotEmpty) {
        String base64String = logo;
        if (logo.contains(',')) {
          base64String = logo.split(',').last;
        }
        final bytes = base64Decode(base64String);
        if (mounted) {
          setState(() {
            _logoBytes = bytes;
          });
        }
      } else {
        safeDebugPrint('⚠️ No logo found in any storage');
      }
    } catch (e) {
      safeDebugPrint('Error loading logo: $e');
    }
  }

  void _startPeriodicUpdate() {
    _periodicUpdateTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _updateStatsInBackground();
    });
  }

  Future<void> _loadData() async {
    await _loadFromCache();
    await _loadSettings(); // الآن يقرأ من Provider المحمّل
    if (mounted) setState(() => isLoading = false);
    _refreshInBackground();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedName = prefs.getString('cached_user_name');
      if (cachedName != null) userName = cachedName;

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

  Future<void> _refreshInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc;
      try {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          safeDebugPrint('⛔ Permission denied — signing out');
          await FirebaseAuth.instance.signOut();
          if (mounted) context.go('/login');
        }
        return;
      }

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) context.go('/login');
        return;
      }
      final data = userDoc.data()! as Map<String, dynamic>;
      final companyIds = List<String>.from(data['companyIds'] ?? []);
      final displayName = data['displayName'] ?? data['name'] ?? '';
      final newName = displayName.isNotEmpty
          ? displayName
          : user.email?.split('@').first ?? 'User';

      Map<String, dynamic> stats;
      try {
        await _statsService.updateUserStats(user.uid);
        stats = await _statsService.getUserStats(user.uid);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          await FirebaseAuth.instance.signOut();
          if (mounted) context.go('/login');
        }
        return;
      }

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
    safeDebugPrint('📐 Settings loaded: view=$_dashboardView, cards=${_selectedCards.length}, mode=${settingsProvider.displayMode}');
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
        _stats.totalManufacturingOrders =
            data['totalManufacturingOrders'] ?? 0;
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
        await _loadStatsFromCache();
        setState(() {});
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
      // بعد العودة من الإعدادات، أعد تحميل الإعدادات من Provider
      await _loadProviderSettings();
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
          body: SmartRefresher(
            controller: _refreshController,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildWelcome(),
                  const SizedBox(height: 16),
                  _buildStatsGrid(settingsProvider),
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

  Widget _buildStatsGrid(DashboardSettingsProvider settingsProvider) {
    final displayMode = settingsProvider.displayMode;

    if (displayMode == 'logo') {
      return _buildLogoOnly();
    }

    final statsMap = _stats.toMap();
    final filtered = dashboardMetrics
        .where((m) => _selectedCards.contains(m.titleKey))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              tr('no_cards_selected'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 12),
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

  Widget _buildLogoOnly() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_logoBytes != null)
            Image.memory(
              _logoBytes!,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business, size: 200, color: Colors.grey),
            )
          else
            Image.asset(
              'assets/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business, size: 200, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          Text(
            tr('dashboard_logo_mode_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tr('dashboard_logo_mode_subtitle'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            label: Text(tr('customize_dashboard')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
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

// ─── نموذج الإحصائيات ──────────────────────────────────────────
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