// lib/pages/reports/inventory_onhand_report_page.dart
// تقرير المخزون الكامل — كل شركة → كل مصنع → كل منتج
// ✅ نسخة سريعة باستخدام استعلامات موحدة و Batch Reading

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

// ─────────────────────────────────────────────
// نماذج البيانات
// ─────────────────────────────────────────────

class InventoryItem {
  final String itemId;
  final String nameAr;
  final String nameEn;
  final String category;
  final double quantity;
  final String unit;

  InventoryItem({
    required this.itemId,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.quantity,
    required this.unit,
  });

  String name(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return isArabic ? nameAr : nameEn;
  }
}

class FactoryInventory {
  final String factoryId;
  final String nameAr;
  final String nameEn;
  final List<InventoryItem> items;

  FactoryInventory({
    required this.factoryId,
    required this.nameAr,
    required this.nameEn,
    required this.items,
  });

  String name(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return isArabic ? nameAr : nameEn;
  }

  int get totalItems => items.length;
  int get lowStockCount => items.where((i) => i.quantity <= 10 && i.quantity > 0).length;
  int get outOfStockCount => items.where((i) => i.quantity <= 0).length;
}

class CompanyInventory {
  final String companyId;
  final String nameAr;
  final String nameEn;
  final List<FactoryInventory> factories;

  CompanyInventory({
    required this.companyId,
    required this.nameAr,
    required this.nameEn,
    required this.factories,
  });

  String name(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return isArabic ? nameAr : nameEn;
  }

  int get totalItems => factories.fold(0, (total, f) => total + f.totalItems);
  int get totalLowStock => factories.fold(0, (total, f) => total + f.lowStockCount);
  int get totalOutOfStock => factories.fold(0, (total, f) => total + f.outOfStockCount);
}

// ─────────────────────────────────────────────
// الصفحة الرئيسية
// ─────────────────────────────────────────────

class InventoryOnHandPage extends StatefulWidget {
  const InventoryOnHandPage({super.key});

  @override
  State<InventoryOnHandPage> createState() => _InventoryOnHandPageState();
}

class _InventoryOnHandPageState extends State<InventoryOnHandPage> {
  List<CompanyInventory> _data = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _filterCategory = 'all';
  String _sortBy = 'name';

  static const String _cacheKey = 'inventory_report_cache_v2';
  static const String _cacheTimeKey = 'inventory_report_cache_time_v2';
  static const Duration _cacheDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ─────────────────────────────────────────────
  // تحميل البيانات - نسخة محسنة 🚀
  // ─────────────────────────────────────────────

  Future<void> _loadReport() async {
    await _loadFromCache();
    _fetchFromFirestoreOptimized(background: _data.isNotEmpty);
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (age > _cacheDuration.inMilliseconds) return;

      final cached = prefs.getString(_cacheKey);
      if (cached == null) return;

      final List decoded = json.decode(cached);
      final data = decoded.map((c) => _parseCompany(c)).toList();

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
      safeDebugPrint('✅ Inventory report loaded from cache');
    } catch (e) {
      safeDebugPrint('Cache load error: $e');
    }
  }

  /// ✅ النسخة المحسنة - استعلامات موحدة
  Future<void> _fetchFromFirestoreOptimized({required bool background}) async {
    if (!background && mounted) setState(() => _isLoading = true);
    if (background && mounted) setState(() => _isRefreshing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ── 1. جلب companyIds من المستخدم ──
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      final companyIds = List<String>.from(userData?['companyIds'] ?? []);
      
      if (companyIds.isEmpty) {
        if (mounted) {
          setState(() {
            _data = [];
            _isLoading = false;
            _isRefreshing = false;
          });
        }
        return;
      }

      // ── 2. جلب جميع الشركات بطلب واحد ──
      final companiesSnap = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      // ── 3. جلب جميع الأصناف بطلب واحد ──
      final itemsSnap = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      final Map<String, Map<String, dynamic>> itemsMap = {
        for (final doc in itemsSnap.docs) doc.id: doc.data()
      };

      // ── 4. جلب جميع المصانع للشركات بطلب واحد ──
      final List<QueryDocumentSnapshot> allFactories = [];
      for (final companyDoc in companiesSnap.docs) {
        final factoriesSnap = await FirebaseFirestore.instance
            .collection('factories')
            .where('companyIds', arrayContains: companyDoc.id)
            .get();
        allFactories.addAll(factoriesSnap.docs);
      }

      // ── 5. ✅ جلب جميع المخزونات دفعة واحدة (Batch) ──
      final Map<String, List<QueryDocumentSnapshot>> inventoryByFactory = {};
      
      // استخدام Future.wait لجلب جميع المخزونات بالتوازي
      final inventoryFutures = allFactories.map((factoryDoc) async {
        final inventorySnap = await FirebaseFirestore.instance
            .collection('factories')
            .doc(factoryDoc.id)
            .collection('inventory')
            .get();
        return {
          'factoryId': factoryDoc.id, 
          'docs': inventorySnap.docs
        };
      }).toList();

      final inventoryResults = await Future.wait(inventoryFutures);
      
      for (final result in inventoryResults) {
        final factoryId = result['factoryId'] as String?;
        final docs = result['docs'] as List<QueryDocumentSnapshot>?;
        if (factoryId != null && docs != null) {
          inventoryByFactory[factoryId] = docs;
        }
      }

      // ── 6. بناء النتائج ──
      final List<CompanyInventory> result = [];

      for (final companyDoc in companiesSnap.docs) {
        final companyData = companyDoc.data();
        
        // جلب مصانع هذه الشركة
        final factoryDocs = allFactories
            .where((f) {
              // ✅ استخدام f.data() مع التحقق من null
              final fData = f.data() as Map<String, dynamic>?;
              if (fData == null) return false;
              final companyIdsList = (fData['companyIds'] as List?)?.cast<String>() ?? [];
              return companyIdsList.contains(companyDoc.id);
            })
            .toList();

        final List<FactoryInventory> factories = [];

        for (final factoryDoc in factoryDocs) {
          final inventoryDocs = inventoryByFactory[factoryDoc.id] ?? [];
          
          final List<InventoryItem> items = [];
          for (final invDoc in inventoryDocs) {
            final itemData = itemsMap[invDoc.id];
            if (itemData == null) continue;

            final quantity = _toDouble((invDoc.data() as Map<String, dynamic>)['quantity']);
            
            // ✅ استخدام ?. مع toString() معالجة القيم null
            final nameAr = itemData['nameAr']?.toString() ?? invDoc.id;
            final nameEn = itemData['nameEn']?.toString() ?? invDoc.id;
            final category = itemData['category']?.toString() ?? 'raw_material';
            final unit = itemData['unit']?.toString() ?? '';

            items.add(InventoryItem(
              itemId: invDoc.id,
              nameAr: nameAr,
              nameEn: nameEn,
              category: category,
              quantity: quantity,
              unit: unit,
            ));
          }

          // ✅ استخدام factoryDoc.data() مع التحقق من null
          final factoryData = factoryDoc.data() as Map<String, dynamic>?;
          final factoryNameAr = factoryData?['nameAr']?.toString() ?? factoryDoc.id;
          final factoryNameEn = factoryData?['nameEn']?.toString() ?? factoryDoc.id;

          factories.add(FactoryInventory(
            factoryId: factoryDoc.id,
            nameAr: factoryNameAr,
            nameEn: factoryNameEn,
            items: items,
          ));
        }

        // ✅ استخدام ?. مع toString() معالجة القيم null
        final companyNameAr = companyData['nameAr']?.toString() ?? companyDoc.id;
        final companyNameEn = companyData['nameEn']?.toString() ?? companyDoc.id;

        result.add(CompanyInventory(
          companyId: companyDoc.id,
          nameAr: companyNameAr,
          nameEn: companyNameEn,
          factories: factories,
        ));
      }

      await _saveToCache(result);

      if (mounted) {
        setState(() {
          _data = result;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
      safeDebugPrint('✅ Inventory report fetched from Firestore (Optimized)');
    } catch (e) {
      safeDebugPrint('Firestore error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // ── دالة قديمة للتوافق مع RefreshIndicator ──
  Future<void> _fetchFromFirestore({required bool background}) async {
    await _fetchFromFirestoreOptimized(background: background);
  }

  Future<void> _saveToCache(List<CompanyInventory> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializable = data.map((c) => {
        'companyId': c.companyId,
        'nameAr': c.nameAr,
        'nameEn': c.nameEn,
        'factories': c.factories.map((f) => {
          'factoryId': f.factoryId,
          'nameAr': f.nameAr,
          'nameEn': f.nameEn,
          'items': f.items.map((i) => {
            'itemId': i.itemId,
            'nameAr': i.nameAr,
            'nameEn': i.nameEn,
            'category': i.category,
            'quantity': i.quantity,
            'unit': i.unit,
          }).toList(),
        }).toList(),
      }).toList();

      await prefs.setString(_cacheKey, json.encode(serializable));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      safeDebugPrint('Cache save error: $e');
    }
  }

  CompanyInventory _parseCompany(dynamic c) {
    // ✅ استخدام ?. مع التحقق من null
    final factoriesList = (c['factories'] as List?) ?? [];
    
    final factories = factoriesList.map((f) {
      final itemsList = (f['items'] as List?) ?? [];
      
      final items = itemsList.map((i) {
        return InventoryItem(
          itemId: i['itemId']?.toString() ?? '',
          nameAr: i['nameAr']?.toString() ?? '',
          nameEn: i['nameEn']?.toString() ?? '',
          category: i['category']?.toString() ?? 'raw_material',
          quantity: _toDouble(i['quantity']),
          unit: i['unit']?.toString() ?? '',
        );
      }).toList();
      
      return FactoryInventory(
        factoryId: f['factoryId']?.toString() ?? '',
        nameAr: f['nameAr']?.toString() ?? '',
        nameEn: f['nameEn']?.toString() ?? '',
        items: items,
      );
    }).toList();

    return CompanyInventory(
      companyId: c['companyId']?.toString() ?? '',
      nameAr: c['nameAr']?.toString() ?? '',
      nameEn: c['nameEn']?.toString() ?? '',
      factories: factories,
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ─────────────────────────────────────────────
  // فلترة وترتيب المنتجات
  // ─────────────────────────────────────────────

  List<InventoryItem> _filterAndSort(List<InventoryItem> items) {
    var filtered = _filterCategory == 'all'
        ? items
        : items.where((i) => i.category == _filterCategory).toList();

    switch (_sortBy) {
      case 'quantity_asc':
        filtered.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case 'quantity_desc':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'low_stock':
        filtered.sort((a, b) => a.quantity.compareTo(b.quantity));
        filtered = filtered.where((i) => i.quantity <= 10).toList();
        break;
      default:
        filtered.sort((a, b) => a.name(context).compareTo(b.name(context)));
    }
    return filtered;
  }

  // ─────────────────────────────────────────────
  // الواجهة
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'inventory_report'.tr(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchFromFirestore(background: false),
              child: Column(
                children: [
                  if (_isRefreshing)
                    LinearProgressIndicator(
                      backgroundColor: Colors.blue.withAlpha(30),
                    ),
                  _buildFilterBar(),
                  Expanded(
                    child: _data.isEmpty
                        ? Center(child: Text('no_data'.tr()))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _data.length,
                            itemBuilder: (_, i) => _buildCompanySection(_data[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterCategory,
              decoration: InputDecoration(
                labelText: 'category'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text('all'.tr())),
                DropdownMenuItem(value: 'raw_material', child: Text('raw_material'.tr())),
                DropdownMenuItem(value: 'packaging', child: Text('packaging'.tr())),
              ],
              onChanged: (v) => setState(() => _filterCategory = v ?? 'all'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: InputDecoration(
                labelText: 'sort_by'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'name', child: Text('name'.tr())),
                DropdownMenuItem(value: 'quantity_asc', child: Text('quantity_asc'.tr())),
                DropdownMenuItem(value: 'quantity_desc', child: Text('quantity_desc'.tr())),
                DropdownMenuItem(value: 'low_stock', child: Text('low_stock_only'.tr())),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'name'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection(CompanyInventory company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.business, color: Color(0xFF45C8DA)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                company.name(context),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildCompanySummaryChips(company),
        ),
        children: company.factories.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('no_factories'.tr()),
                )
              ]
            : company.factories.map((f) => _buildFactorySection(f)).toList(),
      ),
    );
  }

  Widget _buildCompanySummaryChips(CompanyInventory company) {
    return Wrap(
      spacing: 6,
      children: [
        _buildChip('${company.factories.length} ${'factories'.tr()}', Colors.blue),
        _buildChip('${company.totalItems} ${'items'.tr()}', Colors.teal),
        if (company.totalLowStock > 0)
          _buildChip('${company.totalLowStock} ${'low_stock'.tr()}', Colors.orange),
        if (company.totalOutOfStock > 0)
          _buildChip('${company.totalOutOfStock} ${'out_of_stock'.tr()}', Colors.red),
      ],
    );
  }

  Widget _buildFactorySection(FactoryInventory factory) {
    final filteredItems = _filterAndSort(factory.items);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Row(
            children: [
              const Icon(Icons.factory, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  factory.name(context),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 4,
              children: [
                _buildChip('${factory.totalItems} ${'items'.tr()}', Colors.teal, small: true),
                if (factory.lowStockCount > 0)
                  _buildChip('${factory.lowStockCount} ${'low'.tr()}', Colors.orange, small: true),
                if (factory.outOfStockCount > 0)
                  _buildChip('${factory.outOfStockCount} ${'empty'.tr()}', Colors.red, small: true),
              ],
            ),
          ),
          children: filteredItems.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _sortBy == 'low_stock' ? 'no_low_stock'.tr() : 'no_items'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _buildItemsTable(filteredItems),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(List<InventoryItem> items) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF45C8DA).withAlpha(30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('item_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('category'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('quantity'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.end)),
            ],
          ),
        ),
        ...items.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(InventoryItem item) {
    final isOutOfStock = item.quantity <= 0;
    final isLowStock = item.quantity > 0 && item.quantity <= 10;

    Color quantityColor = Colors.black87;
    if (isOutOfStock) {
      quantityColor = Colors.red;
    } else if (isLowStock) {
      quantityColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: isOutOfStock
            ? Colors.red.withAlpha(10)
            : isLowStock
                ? Colors.orange.withAlpha(10)
                : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (isOutOfStock)
                  const Icon(Icons.warning, size: 14, color: Colors.red)
                else if (isLowStock)
                  const Icon(Icons.warning_amber, size: 14, color: Colors.orange)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.name(context),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'category_${item.category}'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.unit}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: quantityColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}