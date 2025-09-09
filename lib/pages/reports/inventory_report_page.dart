// lib/pages/inventory_analysis/inventory_analysis_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class InventoryAnalysisPage extends StatefulWidget {
  const InventoryAnalysisPage({super.key});

  @override
  State<InventoryAnalysisPage> createState() => _InventoryAnalysisPageState();
}

class _InventoryAnalysisPageState extends State<InventoryAnalysisPage> {
  String? selectedCompanyId;
  String? selectedFactoryId;
  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> factories = [];
  bool isLoading = true;
  bool get _isArabic => context.locale.languageCode == 'ar';

  // بيانات التقرير
  int totalStock = 0;
  int totalItems = 0;
  int totalMovements = 0;
  double turnoverRatio = 0;
  Map<String, int> categoryCounts = {};
  Map<String, int> movementTypes = {};

  @override
  void dispose() {
    // cancel subscriptions if any
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadUserCompanyIds();
    await _loadCompaniesWithInventory();
    if (!mounted) return;

    setState(() => isLoading = false);
  }

  Future<void> _loadUserCompanyIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        userCompanyIds = [];
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        userCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('userCompanyIds', userCompanyIds);
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load userCompanyIds: $e');
      userCompanyIds = [];
    }
  }

  Future<void> _loadCompaniesWithInventory() async {
    if (userCompanyIds.isEmpty) return;

    try {
      final companiesWithInventory = <Map<String, dynamic>>[];

      for (final companyId in userCompanyIds) {
        final inventorySnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('stock_movements')
            .limit(1)
            .get();

        if (inventorySnapshot.docs.isNotEmpty) {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            final companyData = companyDoc.data()!;
            companiesWithInventory.add({
              'id': companyId,
              'nameAr': companyData['nameAr'] ?? companyId,
              'nameEn': companyData['nameEn'] ?? companyId,
            });
          }
        }
      }
      if (!mounted) return;

      setState(() {
        companies = companiesWithInventory;
        selectedCompanyId = companies.isNotEmpty ? companies[0]['id'] : null;
      });

      if (selectedCompanyId != null) {
        await _loadFactoriesWithInventory();
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load companies with inventory: $e');
    }
  }

  Future<void> _loadFactoriesWithInventory() async {
    if (selectedCompanyId == null) return;

    try {
      final factoriesWithInventory = <Map<String, dynamic>>[];

      final facSnaps = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: selectedCompanyId)
          .get();
      safeDebugPrint('Found factories count: ${facSnaps.docs.length}');

      for (final factoryDoc in facSnaps.docs) {
        final factoryId = factoryDoc.id;

        final inventorySnapshot = await FirebaseFirestore.instance
            .collection('factories')
            .doc(factoryId)
            .collection('inventory')
            .limit(1)
            .get();

        safeDebugPrint(
            'Factory $factoryId inventory docs: ${inventorySnapshot.docs.length}');

/*         if (inventorySnapshot.docs.isNotEmpty) {
          final factoryData = factoryDoc.data();
          factoriesWithInventory.add({
            'id': factoryId,
            'nameAr': factoryData['nameAr'] ?? factoryId,
            'nameEn': factoryData['nameEn'] ?? factoryId,
          });
        } */
        final factoryData = factoryDoc.data();
        factoriesWithInventory.add({
          'id': factoryId,
          'nameAr': factoryData['nameAr'] ?? factoryId,
          'nameEn': factoryData['nameEn'] ?? factoryId,
        });
      }
      if (!mounted) return;

      setState(() {
        factories = factoriesWithInventory;
        selectedFactoryId = factories.isNotEmpty ? factories[0]['id'] : null;
      });

      if (selectedFactoryId != null) {
        await _loadInventoryAnalysis();
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load factories with inventory: $e');
    }
  }

  Future<void> _loadInventoryAnalysis() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // 1. تحميل المخزون الحالي
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .doc(selectedFactoryId!)
          .collection('inventory')
          .get();

      int stockTotal = 0;
      int itemsCount = 0;
      final Map<String, int> categories = {};

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final int quantity = (data['quantity'] ?? 0).toInt();
        stockTotal += quantity;
        itemsCount++;

        // جلب التصنيف من جدول items باستخدام itemId
        final itemId = data['itemId'] ?? doc.id;
        String category = 'unknown';
        if (itemId == null) {
          safeDebugPrint('itemId is missing in inventory document ${doc.id}');
          continue; // تخطى هذا المستند لأنه لا يحتوي itemId
        }
        if (itemId != null) {
          try {
            final itemDoc = await FirebaseFirestore.instance
                .collection('items')
                .doc(itemId)
                .get();
            if (itemDoc.exists) {
              category = itemDoc.data()?['category']?.toString() ?? 'unknown';
            }
          } catch (e) {
            safeDebugPrint('[ERROR] Failed to fetch item $itemId: $e');
          }
        }

        categories[category] = (categories[category] ?? 0) + 1;
      }

      // 2. تحميل الحركات لحساب معدل الدوران
      final movementsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(selectedCompanyId!)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: selectedFactoryId)
          .get();

      int movementsCount = movementsSnapshot.docs.length;
      final Map<String, int> movementTypesCount = {};

      // حساب أنواع الحركات
      for (var doc in movementsSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString() ?? 'unknown';
        movementTypesCount[type] = (movementTypesCount[type] ?? 0) + 1;
      }

      // 3. حساب معدل دوران المخزون
      // معدل الدوران = إجمالي الحركات / متوسط المخزون (مبسط)
      final double turnover = movementsCount > 0 && stockTotal > 0
          ? movementsCount / stockTotal
          : 0;
      if (!mounted) return;

      setState(() {
        totalStock = stockTotal;
        totalItems = itemsCount;
        totalMovements = movementsCount;
        turnoverRatio = double.parse(turnover.toStringAsFixed(2));
        categoryCounts = categories;
        movementTypes = movementTypesCount;
        isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load inventory analysis: $e');
      if (!mounted) return;

      setState(() => isLoading = false);
    }
  }

  Widget _buildAnalysisCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    if (categoryCounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('no_category_data_available'.tr()),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'category_distribution'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...categoryCounts.entries.map((entry) {
              final percentage = totalItems > 0
                  ? (entry.value / totalItems * 100).toStringAsFixed(1)
                  : '0';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${entry.key.tr()}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: totalItems > 0 ? entry.value / totalItems : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$percentage%',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementTypes() {
    if (movementTypes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No movement data available'),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'movement_types'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...movementTypes.entries.map((entry) {
              return ListTile(
                leading: const Icon(Icons.compare_arrows),
                title: Text(entry.key.tr()),
                trailing: Text(entry.value.toString()),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userCompanyIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('inventory_analysis'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('no_companies_assigned'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('contact_admin_for_companies'.tr(),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'inventory_analysis'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // فلترات الشركة والمصنع
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedCompanyId,
                    decoration: InputDecoration(
                      labelText: 'select_company'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      ...companies.map((company) {
                        return DropdownMenuItem<String>(
                          value: company['id'],
                          child: Text(_isArabic
                              ? company['nameAr']
                              : company['nameEn']),
                        );
                      }),
                    ],
                    onChanged: (val) async {
                      if (!mounted) return;

                      setState(() => selectedCompanyId = val);
                      if (val != null) await _loadFactoriesWithInventory();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedFactoryId,
                    decoration: InputDecoration(
                      labelText: 'select_factory'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      ...factories.map((factory) {
                        return DropdownMenuItem<String>(
                          value: factory['id'],
                          child: Text(_isArabic
                              ? factory['nameAr']
                              : factory['nameEn']),
                        );
                      }),
                    ],
                    onChanged: (val) async {
                      if (!mounted) return;

                      setState(() => selectedFactoryId = val);
                      if (val != null) await _loadInventoryAnalysis();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // بطاقات التحليل
            Expanded(
              child: ListView(
                children: [
                  // بطاقات الإحصائيات
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    children: [
                      _buildAnalysisCard(
                        'total_stock'.tr(),
                        totalStock.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      _buildAnalysisCard(
                        'total_items'.tr(),
                        totalItems.toString(),
                        Icons.category,
                        Colors.green,
                      ),
                      _buildAnalysisCard(
                        'total_movements'.tr(),
                        totalMovements.toString(),
                        Icons.compare_arrows,
                        Colors.orange,
                      ),
                      _buildAnalysisCard(
                        'turnover_ratio'.tr(),
                        turnoverRatio.toString(),
                        Icons.autorenew,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // توزيع التصنيفات
                  _buildCategoryDistribution(),
                  const SizedBox(height: 16),

                  // أنواع الحركات
                  _buildMovementTypes(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
