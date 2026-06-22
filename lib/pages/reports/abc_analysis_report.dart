/* 
// lib/pages/reports/abc_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AbcAnalysisReport extends StatefulWidget {
  const AbcAnalysisReport({super.key});

  @override
  State<AbcAnalysisReport> createState() => _AbcAnalysisReportState();
}

class _AbcAnalysisReportState extends State<AbcAnalysisReport> {
  bool _isLoading = false;
  bool _isLoadingReport = false;  // ✅ متغير منفصل لتحميل التقرير
  bool _isArabic = false;
  
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  
  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  List<Map<String, dynamic>> _abcItems = [];
  
  int _totalItems = 0;
  double _totalValue = 0;
  final Map<String, dynamic> _abcSummary = {
    'A': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.red.shade700},
    'B': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.orange.shade700},
    'C': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.green.shade700},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isArabic = context.locale.languageCode == 'ar';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadCompanies();
    await _loadFactories();
    setState(() => _isLoading = false);
  }

  Future<void> _loadCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userCompanyIds = (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

    for (final companyId in userCompanyIds) {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (companyDoc.exists) {
        final data = companyDoc.data()!;
        _companies.add({
          'id': companyId,
          'name': _isArabic ? data['nameAr'] : data['nameEn'],
        });
      }
    }

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      setState(() {
        _selectedCompanyId = _companies.first['id'] as String;
      });
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    _factories = [];
    final snapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: _selectedCompanyId)
        .get();

    safeDebugPrint('Factories found: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      _factories.add({
        'id': doc.id,
        'name': _isArabic ? data['nameAr'] : data['nameEn'],
      });
      safeDebugPrint('Factory added: ${_factories.last['name']}');
    }

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      setState(() {
        _selectedFactoryId = _factories.first['id'] as String;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) {
      safeDebugPrint('Cannot generate report: missing company or factory');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_factory_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _abcItems.clear();

    try {
      safeDebugPrint('Generating ABC report for factory: $_selectedFactoryId');
      
      // جلب جميع الأصناف من المخزون
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .doc(_selectedFactoryId)
          .collection('inventory')
          .get();

      if (inventorySnapshot.docs.isEmpty) {
        safeDebugPrint('No inventory items found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_inventory_data'.tr())),
          );
        }
        setState(() => _isLoadingReport = false);
        return;
      }

      // حساب القيمة الإجمالية لكل صنف
      final List<Map<String, dynamic>> itemsWithValue = [];
      double totalValue = 0;

      for (final invDoc in inventorySnapshot.docs) {
        final itemId = invDoc.id;
        final quantity = (invDoc.data()['quantity'] as num?)?.toDouble() ?? 0;
        
        if (quantity == 0) continue;

        // جلب سعر الصنف
        final price = await _getItemPrice(itemId);
        final itemValue = quantity * price;
        
        // جلب اسم الصنف
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();
        
        final itemData = itemDoc.data();
        final itemName = _isArabic
            ? (itemData?['nameAr'] ?? itemData?['nameEn'] ?? itemId)
            : (itemData?['nameEn'] ?? itemData?['nameAr'] ?? itemId);
        
        final itemCategory = itemData?['category'] ?? 'raw_material';
        
        itemsWithValue.add({
          'itemId': itemId,
          'itemName': itemName,
          'category': itemCategory,
          'quantity': quantity,
          'price': price,
          'value': itemValue,
        });
        
        totalValue += itemValue;
      }

      _totalValue = totalValue;
      _totalItems = itemsWithValue.length;

      if (_totalItems == 0) {
        setState(() => _isLoadingReport = false);
        return;
      }

      // ترتيب الأصناف حسب القيمة (تنازلياً)
      itemsWithValue.sort((a, b) => b['value'].compareTo(a['value']));

      // تصنيف ABC
      double cumulativeValue = 0;
      
      // إعادة تعيين الإحصائيات
      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['count'] = 0;
        _abcSummary[category]!['value'] = 0.0;
      }
      
      for (int i = 0; i < itemsWithValue.length; i++) {
        final item = itemsWithValue[i];
        cumulativeValue += item['value'];
        final cumulativePercentage = (cumulativeValue / totalValue) * 100;
        
        String category;
        if (cumulativePercentage <= 70) {
          category = 'A';
        } else if (cumulativePercentage <= 90) {
          category = 'B';
        } else {
          category = 'C';
        }
        
        _abcItems.add({
          ...item,
          'category': category,
          'cumulativePercentage': cumulativePercentage,
        });
        
        _abcSummary[category]!['count']++;
        _abcSummary[category]!['value'] += item['value'];
      }
      
      // حساب النسب المئوية للفئات
      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['percentage'] = _totalItems > 0
            ? (_abcSummary[category]!['count'] / _totalItems) * 100
            : 0;
      }

      safeDebugPrint('ABC report completed: A=${_abcSummary['A']!['count']}, B=${_abcSummary['B']!['count']}, C=${_abcSummary['C']!['count']}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'report_generated'.tr()} ($_totalItems ${'items'.tr()})')),
        );
      }
      
      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating ABC report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Future<double> _getItemPrice(String itemId) async {
    try {
      if (_selectedFactoryId != null) {
        final inventoryDoc = await FirebaseFirestore.instance
            .collection('factories')
            .doc(_selectedFactoryId)
            .collection('inventory')
            .doc(itemId)
            .get();
        
        if (inventoryDoc.exists) {
          final data = inventoryDoc.data()!;
          final unitPrice = data['unitPrice'] ?? data['averagePrice'] ?? data['price'];
          if (unitPrice != null && unitPrice > 0) {
            return unitPrice.toDouble();
          }
        }
      }
    } catch (e) {
      safeDebugPrint('Error getting price from inventory for $itemId: $e');
    }
    
    return 10.0;
  }

  Widget _buildCategoryCard(String category, Map<String, dynamic> data) {
    Color color = data['color'];
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['count']} ${'items'.tr()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(data['value']).toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${data['percentage'].toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'abc_analysis_report'.tr(),
      body: Column(
        children: [
          // شريط الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'company'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() {
                            _selectedCompanyId = val;
                            _selectedFactoryId = null;
                            _factories = [];
                            _abcItems = [];
                          });
                          await _loadFactories();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFactoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'factory'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _factories.map((f) {
                          return DropdownMenuItem<String>(
                            value: f['id'],
                            child: Text(f['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFactoryId = val;
                            _abcItems = [];
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingReport ? null : _generateReport,
                        icon: _isLoadingReport
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.analytics),
                        label: Text(_isLoadingReport ? 'analyzing'.tr() : 'analyze'.tr()),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                  ],
                ),
                // ✅ عرض اسم المصنع المختار
                if (_selectedFactoryId != null && _factories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.factory, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '${'selected_factory'.tr()}: ',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _factories.firstWhere((f) => f['id'] == _selectedFactoryId)['name'],
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // النتائج
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _abcItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFactoryId == null
                                  ? 'select_factory_first'.tr()
                                  : 'click_analyze'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // بطاقات ملخص ABC
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'abc_distribution'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildCategoryCard('A', _abcSummary['A']!),
                                    _buildCategoryCard('B', _abcSummary['B']!),
                                    _buildCategoryCard('C', _abcSummary['C']!),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.inventory,
                                        label: 'total_items'.tr(),
                                        value: _totalItems.toString(),
                                      ),
                                      _buildStatItem(
                                        icon: Icons.attach_money,
                                        label: 'total_value'.tr(),
                                        value: '${_totalValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Divider(),
                          
                          // قائمة الأصناف
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'items_classification'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _abcItems.length,
                            itemBuilder: (context, index) {
                              final item = _abcItems[index];
                              final category = item['category'];
                              Color color = category == 'A' ? Colors.red : (category == 'B' ? Colors.orange : Colors.green);
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['itemName'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${'quantity'.tr()}: ${(item['quantity'] as double).toStringAsFixed(0)} | '
                                    '${'value'.tr()}: ${item['value'].toStringAsFixed(2)} ${'currency'.tr()}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item['cumulativePercentage'].toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        '${(item['value'] / _totalValue * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/* // lib/pages/reports/abc_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AbcAnalysisReport extends StatefulWidget {
  const AbcAnalysisReport({super.key});

  @override
  State<AbcAnalysisReport> createState() => _AbcAnalysisReportState();
}

class _AbcAnalysisReportState extends State<AbcAnalysisReport> {
  bool _isLoading = false;
  bool _isArabic = false;
  
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  
  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _abcItems = [];
  
  // إحصائيات
  int _totalItems = 0;
  double _totalValue = 0;
  final Map<String, dynamic> _abcSummary = {
    'A': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.red.shade700},
    'B': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.orange.shade700},
    'C': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.green.shade700},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isArabic = context.locale.languageCode == 'ar';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCompanies();
    await _loadFactories();
  }

  Future<void> _loadCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userCompanyIds = (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

    for (final companyId in userCompanyIds) {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (companyDoc.exists) {
        final data = companyDoc.data()!;
        _companies.add({
          'id': companyId,
          'name': _isArabic ? data['nameAr'] : data['nameEn'],
        });
      }
    }

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      setState(() {
        _selectedCompanyId = _companies.first['id'] as String;
      });
      await _loadFactories();
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    _factories = [];
    final snapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: _selectedCompanyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      _factories.add({
        'id': doc.id,
        'name': _isArabic ? data['nameAr'] : data['nameEn'],
      });
    }

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      setState(() {
        _selectedFactoryId = _factories.first['id'] as String;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) return;

    setState(() => _isLoading = true);
    _abcItems.clear();

    try {
      // جلب جميع الأصناف من المخزون
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .doc(_selectedFactoryId)
          .collection('inventory')
          .get();

      if (inventorySnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // حساب القيمة الإجمالية لكل صنف (الكمية × سعر الشراء)
      final List<Map<String, dynamic>> itemsWithValue = [];
      double totalValue = 0;

      for (final invDoc in inventorySnapshot.docs) {
        final itemId = invDoc.id;
        final quantity = (invDoc.data()['quantity'] as num?)?.toDouble() ?? 0;
        
        if (quantity == 0) continue;

        // جلب سعر الصنف (من آخر حركة شراء)
        final price = await _getItemPrice(itemId);
        final itemValue = quantity * price;
        
        // جلب اسم الصنف
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();
        
        final itemData = itemDoc.data();
        final itemName = _isArabic
            ? (itemData?['nameAr'] ?? itemData?['nameEn'] ?? itemId)
            : (itemData?['nameEn'] ?? itemData?['nameAr'] ?? itemId);
        
        final itemCategory = itemData?['category'] ?? 'raw_material';
        
        itemsWithValue.add({
          'itemId': itemId,
          'itemName': itemName,
          'category': itemCategory,
          'quantity': quantity,
          'price': price,
          'value': itemValue,
        });
        
        totalValue += itemValue;
      }

      _totalValue = totalValue;
      _totalItems = itemsWithValue.length;

      // ترتيب الأصناف حسب القيمة (تنازلياً)
      itemsWithValue.sort((a, b) => b['value'].compareTo(a['value']));

      // تصنيف ABC
      double cumulativeValue = 0;
      
      for (int i = 0; i < itemsWithValue.length; i++) {
        final item = itemsWithValue[i];
        cumulativeValue += item['value'];
        final cumulativePercentage = (cumulativeValue / totalValue) * 100;
        
        String category;
        if (cumulativePercentage <= 70) {
          category = 'A';
        } else if (cumulativePercentage <= 90) {
          category = 'B';
        } else {
          category = 'C';
        }
        
        _abcItems.add({
          ...item,
          'category': category,
          'cumulativePercentage': cumulativePercentage,
        });
        
        _abcSummary[category]!['count']++;
        _abcSummary[category]!['value'] += item['value'];
      }
      
      // حساب النسب المئوية للفئات
      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['percentage'] = _totalItems > 0
            ? (_abcSummary[category]!['count'] / _totalItems) * 100
            : 0;
      }

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating ABC report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

/*   Future<double> _getItemPrice(String itemId) async {
    // محاولة جلب آخر سعر شراء للصنف
    try {
      final lastPurchase = await FirebaseFirestore.instance
          .collectionGroup('stock_movements')
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: 'purchase')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      
      if (lastPurchase.docs.isNotEmpty) {
        final unitPrice = lastPurchase.docs.first.data()['unitPrice'];
        if (unitPrice != null && unitPrice > 0) {
          return unitPrice.toDouble();
        }
      }
    } catch (e) {
      safeDebugPrint('Error getting price for item $itemId: $e');
    }
    
    // سعر افتراضي إذا لم يتم العثور على سعر
    return 10.0;
  }
 */


Future<double> _getItemPrice(String itemId) async {
  try {
    if (_selectedCompanyId == null) return 10.0;
    
    // جلب جميع حركات الشراء لهذا الصنف
    final purchases = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_selectedCompanyId)
        .collection('stock_movements')
        .where('itemId', isEqualTo: itemId)
        .where('type', isEqualTo: 'purchase')
        .get();
    
    if (purchases.docs.isNotEmpty) {
      double totalValue = 0;
      int validCount = 0;
      
      for (final doc in purchases.docs) {
        final data = doc.data();
        final unitPrice = data['unitPrice'];
        if (unitPrice != null && unitPrice > 0) {
          totalValue += unitPrice.toDouble();
          validCount++;
        } else {
          // حساب السعر من الكمية والإجمالي
          final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
          final total = (data['total'] as num?)?.toDouble() ?? 0;
          if (quantity > 0 && total > 0) {
            totalValue += total / quantity;
            validCount++;
          }
        }
      }
      
      if (validCount > 0) {
        return totalValue / validCount;
      }
    }
  } catch (e) {
    safeDebugPrint('Error getting price for item $itemId: $e');
  }
  
  return 10.0;
}

  Widget _buildCategoryCard(String category, Map<String, dynamic> data) {
    Color color = data['color'];
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['count']} ${'items'.tr()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(data['value']).toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${data['percentage'].toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'abc_analysis_report'.tr(),
      body: Column(
        children: [
          // شريط الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'company'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() {
                            _selectedCompanyId = val;
                            _selectedFactoryId = null;
                            _factories = [];
                          });
                          await _loadFactories();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFactoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'factory'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _factories.map((f) {
                          return DropdownMenuItem<String>(
                            value: f['id'],
                            child: Text(f['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFactoryId = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateReport,
                        icon: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.analytics),
                        label: Text('analyze'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // النتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _abcItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'select_factory_and_analyze'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // بطاقات ملخص ABC
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'abc_distribution'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildCategoryCard('A', _abcSummary['A']!),
                                    _buildCategoryCard('B', _abcSummary['B']!),
                                    _buildCategoryCard('C', _abcSummary['C']!),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.inventory,
                                        label: 'total_items'.tr(),
                                        value: _totalItems.toString(),
                                      ),
                                      _buildStatItem(
                                        icon: Icons.attach_money,
                                        label: 'total_value'.tr(),
                                        value: '${_totalValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Divider(),
                          
                          // قائمة الأصناف
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'items_classification'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _abcItems.length,
                            itemBuilder: (context, index) {
                              final item = _abcItems[index];
                              final category = item['category'];
                              Color color = category == 'A' ? Colors.red : (category == 'B' ? Colors.orange : Colors.green);
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['itemName'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${'quantity'.tr()}: ${(item['quantity'] as double).toStringAsFixed(0)} | '
                                    '${'value'.tr()}: ${item['value'].toStringAsFixed(2)} ${'currency'.tr()}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item['cumulativePercentage'].toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        '${(item['value'] / _totalValue * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
} */ */

/* 
// lib/pages/reports/abc_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class AbcAnalysisReport extends StatefulWidget {
  const AbcAnalysisReport({super.key});

  @override
  State<AbcAnalysisReport> createState() => _AbcAnalysisReportState();
}

class _AbcAnalysisReportState extends State<AbcAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _abcItems = [];

  int _totalItems = 0;
  double _totalValue = 0;

  final Map<String, dynamic> _abcSummary = {
    'A': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.red.shade700},
    'B': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.orange.shade700},
    'C': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.green.shade700},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadCompanies();
    await _loadFactories();
    setState(() => _isLoading = false);
  }

  Future<void> _loadCompanies() async {
    final companies = await _dataService.getUserCompanies();
    setState(() => _companies..clear()..addAll(companies));

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      _selectedCompanyId = _companies.first['id'] as String;
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    final factories = await _dataService.getFactoriesForCompany(
      _selectedCompanyId!,
    );
    setState(() => _factories..clear()..addAll(factories));

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      _selectedFactoryId = _factories.first['id'] as String;
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_factory_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _abcItems.clear();

    try {
      // 1. جلب مخزون المصنع كله
      final inventoryMap = await _dataService.getFactoryInventory(
        _selectedFactoryId!,
      );

      if (inventoryMap.isEmpty) {
        setState(() => _isLoadingReport = false);
        return;
      }

      // 2. جلب أسماء الأصناف
      final itemsMap = await _dataService.getItemsMap();

      // 3. حساب القيمة الإجمالية لكل صنف
      final List<Map<String, dynamic>> itemsWithValue = [];
      double totalValue = 0;

      for (final entry in inventoryMap.entries) {
        final itemId = entry.key;
        final inventoryData = entry.value;
        final quantity = (inventoryData['quantity'] as num?)?.toDouble() ?? 0;

        if (quantity == 0) continue;

        final price = (inventoryData['unitPrice'] as num?)?.toDouble() ?? 0;
        final itemValue = quantity * price;

        final itemData = itemsMap[itemId];
        final itemName = itemData?['name'] ?? itemId;

        itemsWithValue.add({
          'itemId': itemId,
          'itemName': itemName,
          'category': itemData?['category'] ?? 'raw_material',
          'quantity': quantity,
          'price': price,
          'value': itemValue,
        });

        totalValue += itemValue;
      }

      _totalValue = totalValue;
      _totalItems = itemsWithValue.length;

      if (_totalItems == 0) {
        setState(() => _isLoadingReport = false);
        return;
      }

      // ترتيب الأصناف حسب القيمة (تنازلياً)
      itemsWithValue.sort((a, b) => b['value'].compareTo(a['value']));

      // تصنيف ABC
      double cumulativeValue = 0;

      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['count'] = 0;
        _abcSummary[category]!['value'] = 0.0;
      }

      for (int i = 0; i < itemsWithValue.length; i++) {
        final item = itemsWithValue[i];
        cumulativeValue += item['value'];
        final cumulativePercentage = (cumulativeValue / totalValue) * 100;

        String category;
        if (cumulativePercentage <= 70) {
          category = 'A';
        } else if (cumulativePercentage <= 90) {
          category = 'B';
        } else {
          category = 'C';
        }

        _abcItems.add({
          ...item,
          'category': category,
          'cumulativePercentage': cumulativePercentage,
        });

        _abcSummary[category]!['count']++;
        _abcSummary[category]!['value'] += item['value'];
      }

      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['percentage'] = _totalItems > 0
            ? (_abcSummary[category]!['count'] / _totalItems) * 100
            : 0;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'report_generated'.tr()} ($_totalItems ${'items'.tr()})')),
        );
      }

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating ABC report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Widget _buildCategoryCard(String category, Map<String, dynamic> data) {
    final color = data['color'] as Color;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['count']} ${'items'.tr()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(data['value']).toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${data['percentage'].toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    final filterBar = ReportFilterBar(
      companies: _companies,
      factories: _factories,
      selectedCompanyId: _selectedCompanyId,
      selectedFactoryId: _selectedFactoryId,
      onCompanyChanged: (val) async {
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
          _factories.clear();
          _abcItems.clear();
        });
        await _loadFactories();
      },
      onFactoryChanged: (val) {
        setState(() {
          _selectedFactoryId = val;
          _abcItems.clear();
        });
      },
      isLoading: _isLoading,
      extraFilters: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoadingReport ? null : _generateReport,
              icon: _isLoadingReport
                  ? buildLoadingIndicator()
                  : const Icon(Icons.analytics),
              label: Text(_isLoadingReport ? 'analyzing'.tr() : 'analyze'.tr()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
            ),
          ),
        ],
      ),
    );

    return AppScaffold(
      title: 'abc_analysis_report'.tr(),
      body: Column(
        children: [
          filterBar,
          if (_selectedFactoryId != null && _factories.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.factory, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${'selected_factory'.tr()}: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _factories.firstWhere((f) => f['id'] == _selectedFactoryId)['name'],
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _abcItems.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.pie_chart,
                        title: _selectedFactoryId == null
                            ? 'select_factory_first'.tr()
                            : 'click_analyze'.tr(),
                      )
                    : ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'abc_distribution'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildCategoryCard('A', _abcSummary['A']!),
                                    _buildCategoryCard('B', _abcSummary['B']!),
                                    _buildCategoryCard('C', _abcSummary['C']!),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.inventory,
                                        label: 'total_items'.tr(),
                                        value: _totalItems.toString(),
                                      ),
                                      _buildStatItem(
                                        icon: Icons.attach_money,
                                        label: 'total_value'.tr(),
                                        value: '${_totalValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'items_classification'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _abcItems.length,
                            itemBuilder: (context, index) {
                              final item = _abcItems[index];
                              final category = item['category'];
                              final color = category == 'A'
                                  ? Colors.red
                                  : (category == 'B' ? Colors.orange : Colors.green);

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['itemName'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${'quantity'.tr()}: ${(item['quantity'] as double).toStringAsFixed(0)} | '
                                    '${'value'.tr()}: ${item['value'].toStringAsFixed(2)} ${'currency'.tr()}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item['cumulativePercentage'].toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        '${(item['value'] / _totalValue * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
} */

// lib/pages/reports/abc_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class AbcAnalysisReport extends StatefulWidget {
  const AbcAnalysisReport({super.key});

  @override
  State<AbcAnalysisReport> createState() => _AbcAnalysisReportState();
}

class _AbcAnalysisReportState extends State<AbcAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _abcItems = [];

  int _totalItems = 0;
  double _totalValue = 0;

  final Map<String, dynamic> _abcSummary = {
    'A': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.red.shade700},
    'B': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.orange.shade700},
    'C': {'count': 0, 'value': 0.0, 'percentage': 0.0, 'color': Colors.green.shade700},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadCompanies();
    await _loadFactories();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCompanies() async {
    final companies = await _dataService.getUserCompanies();
    if (!mounted) return;
    
    setState(() {
      _companies..clear()..addAll(companies.map((c) {
        // ✅ استخدام اللغة الحالية من context
        final isArabic = context.locale.languageCode == 'ar';
        final name = isArabic 
            ? (c['nameAr'] ?? c['nameEn'] ?? c['id'])
            : (c['nameEn'] ?? c['nameAr'] ?? c['id']);
        
        safeDebugPrint('📌 Company: ${c['id']} -> $name');
        
        return {
          'id': c['id'],
          'name': name,
          'nameAr': c['nameAr'] ?? c['id'],
          'nameEn': c['nameEn'] ?? c['id'],
        };
      }).toList());
    });

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      _selectedCompanyId = _companies.first['id'] as String;
      safeDebugPrint('✅ Selected company: $_selectedCompanyId');
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    final factories = await _dataService.getFactoriesForCompany(
      _selectedCompanyId!,
    );
    if (!mounted) return;
    
    setState(() {
      _factories..clear()..addAll(factories.map((f) {
        // ✅ استخدام اللغة الحالية من context
        final isArabic = context.locale.languageCode == 'ar';
        final name = isArabic 
            ? (f['nameAr'] ?? f['nameEn'] ?? f['id'])
            : (f['nameEn'] ?? f['nameAr'] ?? f['id']);
        
        safeDebugPrint('🏭 Factory: ${f['id']} -> $name');
        
        return {
          'id': f['id'],
          'name': name,
          'nameAr': f['nameAr'] ?? f['id'],
          'nameEn': f['nameEn'] ?? f['id'],
        };
      }).toList());
    });

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      _selectedFactoryId = _factories.first['id'] as String;
      safeDebugPrint('✅ Selected factory: $_selectedFactoryId');
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_factory_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _abcItems.clear();

    try {
      final inventoryMap = await _dataService.getFactoryInventory(
        _selectedFactoryId!,
      );

      if (inventoryMap.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingReport = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_inventory_data'.tr())),
          );
        }
        return;
      }

      final itemsMap = await _dataService.getItemsMap();

      final List<Map<String, dynamic>> itemsWithValue = [];
      double totalValue = 0;

      for (final entry in inventoryMap.entries) {
        final itemId = entry.key;
        final inventoryData = entry.value;
        final quantity = (inventoryData['quantity'] as num?)?.toDouble() ?? 0;

        if (quantity == 0) continue;

        final price = (inventoryData['unitPrice'] as num?)?.toDouble() ?? 0;
        final itemValue = quantity * price;

        final itemData = itemsMap[itemId];
        final itemName = itemData?['name'] ?? itemId;

        itemsWithValue.add({
          'itemId': itemId,
          'itemName': itemName,
          'category': itemData?['category'] ?? 'raw_material',
          'quantity': quantity,
          'price': price,
          'value': itemValue,
        });

        totalValue += itemValue;
      }

      _totalValue = totalValue;
      _totalItems = itemsWithValue.length;

      if (_totalItems == 0) {
        if (mounted) setState(() => _isLoadingReport = false);
        return;
      }

      itemsWithValue.sort((a, b) => b['value'].compareTo(a['value']));

      double cumulativeValue = 0;

      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['count'] = 0;
        _abcSummary[category]!['value'] = 0.0;
      }

      for (int i = 0; i < itemsWithValue.length; i++) {
        final item = itemsWithValue[i];
        cumulativeValue += item['value'];
        final cumulativePercentage = (cumulativeValue / totalValue) * 100;

        String category;
        if (cumulativePercentage <= 70) {
          category = 'A';
        } else if (cumulativePercentage <= 90) {
          category = 'B';
        } else {
          category = 'C';
        }

        _abcItems.add({
          ...item,
          'category': category,
          'cumulativePercentage': cumulativePercentage,
        });

        _abcSummary[category]!['count']++;
        _abcSummary[category]!['value'] += item['value'];
      }

      for (final category in _abcSummary.keys) {
        _abcSummary[category]!['percentage'] = _totalItems > 0
            ? (_abcSummary[category]!['count'] / _totalItems) * 100
            : 0;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'report_generated'.tr()} ($_totalItems ${'items'.tr()})')),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('❌ Error generating ABC report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  Widget _buildCategoryCard(String category, Map<String, dynamic> data) {
    final color = data['color'] as Color;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['count']} ${'items'.tr()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(data['value']).toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${data['percentage'].toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          label.tr(), // ✅ استخدام الترجمة
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ طباعة للتحقق من البيانات
    safeDebugPrint('📊 Companies in build: ${_companies.length}');
    safeDebugPrint('📊 Factories in build: ${_factories.length}');
    
    if (_companies.isNotEmpty) {
      safeDebugPrint('📌 First company: ${_companies.first}');
    }
    if (_factories.isNotEmpty) {
      safeDebugPrint('🏭 First factory: ${_factories.first}');
    }

    final filterBar = ReportFilterBar(
      companies: _companies,
      factories: _factories,
      selectedCompanyId: _selectedCompanyId,
      selectedFactoryId: _selectedFactoryId,
      onCompanyChanged: (val) async {
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
          _factories.clear();
          _abcItems.clear();
        });
        await _loadFactories();
      },
      onFactoryChanged: (val) {
        setState(() {
          _selectedFactoryId = val;
          _abcItems.clear();
        });
      },
      isLoading: _isLoading,
      extraFilters: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoadingReport ? null : _generateReport,
              icon: _isLoadingReport
                  ? buildLoadingIndicator()
                  : const Icon(Icons.analytics),
              label: Text(_isLoadingReport ? 'analyzing'.tr() : 'analyze'.tr()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
            ),
          ),
        ],
      ),
    );

    return AppScaffold(
      title: 'abc_analysis_report'.tr(),
      body: Column(
        children: [
          filterBar,
          if (_selectedFactoryId != null && _factories.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.factory, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${'selected_factory'.tr()}: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _factories.firstWhere((f) => f['id'] == _selectedFactoryId)['name'] ?? '',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _abcItems.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.pie_chart,
                        title: _selectedFactoryId == null
                            ? 'select_factory_first'.tr()
                            : 'click_analyze'.tr(),
                      )
                    : ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'abc_distribution'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildCategoryCard('A', _abcSummary['A']!),
                                    _buildCategoryCard('B', _abcSummary['B']!),
                                    _buildCategoryCard('C', _abcSummary['C']!),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.inventory,
                                        label: 'total_items'.tr(),
                                        value: _totalItems.toString(),
                                      ),
                                      _buildStatItem(
                                        icon: Icons.attach_money,
                                        label: 'total_value'.tr(),
                                        value: '${_totalValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'items_classification'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _abcItems.length,
                            itemBuilder: (context, index) {
                              final item = _abcItems[index];
                              final category = item['category'];
                              final color = category == 'A'
                                  ? Colors.red
                                  : (category == 'B' ? Colors.orange : Colors.green);

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['itemName'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${'quantity'.tr()}: ${(item['quantity'] as double).toStringAsFixed(0)} | '
                                    '${'value'.tr()}: ${item['value'].toStringAsFixed(2)} ${'currency'.tr()}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item['cumulativePercentage'].toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        '${(item['value'] / _totalValue * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}