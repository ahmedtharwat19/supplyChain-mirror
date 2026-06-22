/* // lib/pages/reports/cost_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class CostAnalysisReport extends StatefulWidget {
  const CostAnalysisReport({super.key});

  @override
  State<CostAnalysisReport> createState() => _CostAnalysisReportState();
}

class _CostAnalysisReportState extends State<CostAnalysisReport> {
  bool _isLoading = false;
  bool _isLoadingReport = false;
  bool _isArabic = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _costData = [];

  // إحصائيات التكلفة
  double _totalPurchaseCost = 0;
  double _totalInventoryValue = 0;
  double _totalTaxAmount = 0;
  double _totalNetPayable = 0;

  // تكلفة حسب الفئة
  Map<String, double> _costByCategory = {
    'raw_material': 0,
    'packaging': 0,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isArabic = context.locale.languageCode == 'ar';
  }

  @override
  void initState() {
    super.initState();
    _setPeriodDates();
    _loadData();
  }

  void _setPeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'monthly':
        _startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'quarterly':
        _startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'semi_annual':
        _startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'annual':
        _startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'all':
        _startDate = DateTime(2020, 1, 1);
        break;
      case 'custom':
        if (_startDate == null) {
          _startDate = DateTime(now.year, now.month - 1, now.day);
          _endDate = now;
        }
        break;
    }
    if (_selectedPeriod != 'custom') {
      _endDate = now;
    }
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

    final userCompanyIds =
        (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

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

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      saveText: 'apply'.tr(),
      cancelText: 'cancel'.tr(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
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
    _costData.clear();
    _costByCategory = {'raw_material': 0, 'packaging': 0};
    _totalPurchaseCost = 0;
    _totalInventoryValue = 0;
    _totalTaxAmount = 0;
    _totalNetPayable = 0;

    try {
      // 1. جلب أوامر الشراء
      Query ordersQuery = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('companyId', isEqualTo: _selectedCompanyId);

      if (_startDate != null) {
        ordersQuery =
            ordersQuery.where('orderDate', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        ordersQuery = ordersQuery.where('orderDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      final ordersSnapshot = await ordersQuery.get();

      // 2. جلب المخزون الحالي
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .doc(_selectedFactoryId)
          .collection('inventory')
          .get();

      // حساب قيمة المخزون الحالي
      for (final invDoc in inventorySnapshot.docs) {
        final quantity = (invDoc.data()['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = await _getItemPrice(invDoc.id);
        final itemValue = quantity * unitPrice;
        _totalInventoryValue += itemValue;
      }

// تحليل تكاليف المشتريات
      for (final doc in ordersSnapshot.docs) {
        // ✅ FIXED: Safely cast the dynamic payload to a non-nullable map structure
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final totalAmount =
            (data['totalAmountAfterTax'] as num?)?.toDouble() ?? 0;
        final totalTax = (data['totalTax'] as num?)?.toDouble() ?? 0;
        final netPayable = (data['netPayable'] as num?)?.toDouble() ?? 0;
        final items = data['items'] as List<dynamic>? ?? [];

        _totalPurchaseCost += totalAmount;
        _totalTaxAmount += totalTax;
        _totalNetPayable += netPayable;

        // تحليل حسب الفئة
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemId = itemMap['itemId'];
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
          final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
          final itemValue = quantity * unitPrice;

          // جلب فئة المنتج
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final category = itemDoc.data()?['category'] ?? 'raw_material';
            if (category == 'raw_material') {
              _costByCategory['raw_material'] =
                  (_costByCategory['raw_material'] ?? 0) + itemValue;
            } else if (category == 'packaging') {
              _costByCategory['packaging'] =
                  (_costByCategory['packaging'] ?? 0) + itemValue;
            }
          }
        }

        // تفاصيل الطلب للعرض
        _costData.add({
          'poNumber': data['poNumber'],
          'orderDate': (data['orderDate'] as Timestamp?)?.toDate(),
          'totalAmount': totalAmount,
          'totalTax': totalTax,
          'netPayable': netPayable,
          'status': data['status'],
          'itemsCount': items.length,
        });
      }

      // حساب متوسط تكلفة الصنف
      if (_costData.isNotEmpty) {}

      // ترتيب البيانات حسب التاريخ
      _costData.sort((a, b) {
        final aDate = a['orderDate'] as DateTime? ?? DateTime.now();
        final bDate = b['orderDate'] as DateTime? ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating cost analysis report: $e');
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
          final unitPrice =
              data['unitPrice'] ?? data['averagePrice'] ?? data['price'];
          if (unitPrice != null && unitPrice > 0) {
            return unitPrice.toDouble();
          }
        }
      }
    } catch (e) {
      safeDebugPrint('Error getting price: $e');
    }
    return 10.0;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'cost_analysis_report'.tr(),
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPeriod,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'period'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                              value: 'monthly',
                              child: Text(_isArabic ? 'شهري' : 'Monthly')),
                          DropdownMenuItem<String>(
                              value: 'quarterly',
                              child:
                                  Text(_isArabic ? 'ربع سنوي' : 'Quarterly')),
                          DropdownMenuItem<String>(
                              value: 'semi_annual',
                              child:
                                  Text(_isArabic ? 'نصف سنوي' : 'Semi-Annual')),
                          DropdownMenuItem<String>(
                              value: 'annual',
                              child: Text(_isArabic ? 'سنوي' : 'Annual')),
                          DropdownMenuItem<String>(
                              value: 'all',
                              child:
                                  Text(_isArabic ? 'كل الفترات' : 'All Time')),
                          DropdownMenuItem<String>(
                              value: 'custom',
                              child: Text(_isArabic ? 'مدة محددة' : 'Custom')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedPeriod = val!;
                            _setPeriodDates();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingReport ? null : _generateReport,
                        icon: _isLoadingReport
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.analytics),
                        label: Text(_isLoadingReport
                            ? 'analyzing'.tr()
                            : 'analyze'.tr()),
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _selectCustomDateRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        '${_formatDate(_startDate)} → ${_formatDate(_endDate)}',
                        overflow: TextOverflow.ellipsis,
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
                : _costData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics,
                                size: 64, color: Colors.grey.shade400),
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
                          // بطاقات الإحصائيات الرئيسية
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'cost_summary'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildStatCard(
                                      title: 'total_purchases'.tr(),
                                      value:
                                          _totalPurchaseCost.toStringAsFixed(2),
                                      icon: Icons.shopping_cart,
                                      color: Colors.blue,
                                    ),
                                    _buildStatCard(
                                      title: 'inventory_value'.tr(),
                                      value: _totalInventoryValue
                                          .toStringAsFixed(2),
                                      icon: Icons.inventory,
                                      color: Colors.green,
                                    ),
                                    _buildStatCard(
                                      title: 'total_tax'.tr(),
                                      value: _totalTaxAmount.toStringAsFixed(2),
                                      icon: Icons.receipt,
                                      color: Colors.orange,
                                    ),
                                    _buildStatCard(
                                      title: 'net_payable'.tr(),
                                      value:
                                          _totalNetPayable.toStringAsFixed(2),
                                      icon: Icons.attach_money,
                                      color: Colors.purple,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // تكلفة حسب الفئة
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'cost_by_category'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildCategoryItem(
                                      title: 'raw_materials'.tr(),
                                      value:
                                          _costByCategory['raw_material'] ?? 0,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildCategoryItem(
                                      title: 'packaging_materials'.tr(),
                                      value: _costByCategory['packaging'] ?? 0,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Divider(),

                          // قائمة الطلبات
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'purchase_orders_details'.tr(),
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
                            itemCount: _costData.length,
                            itemBuilder: (context, index) {
                              final order = _costData[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        order['status'] == 'completed'
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                    child: Icon(
                                      order['status'] == 'completed'
                                          ? Icons.check
                                          : Icons.pending,
                                      color: order['status'] == 'completed'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    order['poNumber'] ?? 'PO-${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${'date'.tr()}: ${_formatDate(order['orderDate'])} | '
                                    '${'items_count'.tr()}: ${order['itemsCount']}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildDetailRow('total_amount'.tr(),
                                              '${order['totalAmount'].toStringAsFixed(2)} ${'currency'.tr()}'),
                                          const SizedBox(height: 4),
                                          _buildDetailRow('total_tax'.tr(),
                                              '${order['totalTax'].toStringAsFixed(2)} ${'currency'.tr()}'),
                                          const SizedBox(height: 4),
                                          _buildDetailRow('net_payable'.tr(),
                                              '${order['netPayable'].toStringAsFixed(2)} ${'currency'.tr()}'),
                                          const SizedBox(height: 4),
                                          _buildDetailRow(
                                              'status'.tr(),
                                              order['status'] == 'completed'
                                                  ? 'completed'.tr()
                                                  : 'pending'.tr()),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required String title,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade900),
          ),
        ),
      ],
    );
  }
}
 */
// lib/pages/reports/cost_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class CostAnalysisReport extends StatefulWidget {
  const CostAnalysisReport({super.key});

  @override
  State<CostAnalysisReport> createState() => _CostAnalysisReportState();
}

class _CostAnalysisReportState extends State<CostAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _costData = [];

  double _totalPurchaseCost = 0;
  double _totalInventoryValue = 0;
  double _totalTaxAmount = 0;
  double _totalNetPayable = 0;

  final Map<String, double> _costByCategory = {
    'raw_material': 0,
    'packaging': 0,
  };

  @override
  void initState() {
    super.initState();
    _setPeriodDates();
    _loadData();
  }

  void _setPeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'monthly':
        _startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'quarterly':
        _startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'semi_annual':
        _startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'annual':
        _startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'all':
        _startDate = DateTime(2020, 1, 1);
        break;
      case 'custom':
        if (_startDate == null) {
          _startDate = DateTime(now.year, now.month - 1, now.day);
          _endDate = now;
        }
        break;
    }
    if (_selectedPeriod != 'custom') {
      _endDate = now;
    }
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
    
    final isArabic = context.locale.languageCode == 'ar';
    setState(() {
      _companies..clear()..addAll(companies.map((c) {
        return {
          'id': c['id'],
          'name': isArabic ? c['nameAr'] : c['nameEn'],
        };
      }).toList());
    });

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      _selectedCompanyId = _companies.first['id'] as String;
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    final factories = await _dataService.getFactoriesForCompany(
      _selectedCompanyId!,
    );
    if (!mounted) return;
    
    final isArabic = context.locale.languageCode == 'ar';
    setState(() {
      _factories..clear()..addAll(factories.map((f) {
        return {
          'id': f['id'],
          'name': isArabic ? f['nameAr'] : f['nameEn'],
        };
      }).toList());
    });

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      _selectedFactoryId = _factories.first['id'] as String;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showCustomDateRangePicker(
      context,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
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
    _costData.clear();
    _costByCategory['raw_material'] = 0;
    _costByCategory['packaging'] = 0;
    _totalPurchaseCost = 0;
    _totalInventoryValue = 0;
    _totalTaxAmount = 0;
    _totalNetPayable = 0;

    try {
      // 1. جلب مخزون المصنع كله
      final inventoryMap = await _dataService.getFactoryInventory(
        _selectedFactoryId!,
      );

      // حساب قيمة المخزون الحالي
      for (final inventoryData in inventoryMap.values) {
        final quantity = (inventoryData['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (inventoryData['unitPrice'] as num?)?.toDouble() ?? 0;
        _totalInventoryValue += quantity * unitPrice;
      }

      // 2. جلب أسماء الأصناف
      final itemsMap = await _dataService.getItemsMap();

      // 3. جلب أوامر الشراء
      final ordersDocs = await _dataService.getPurchaseOrders(
        companyId: _selectedCompanyId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      for (final doc in ordersDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final totalAmount = (data['totalAmountAfterTax'] as num?)?.toDouble() ?? 0;
        final totalTax = (data['totalTax'] as num?)?.toDouble() ?? 0;
        final netPayable = (data['netPayable'] as num?)?.toDouble() ?? 0;
        final items = data['items'] as List<dynamic>? ?? [];

        _totalPurchaseCost += totalAmount;
        _totalTaxAmount += totalTax;
        _totalNetPayable += netPayable;

        // تحليل حسب الفئة
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemId = itemMap['itemId']?.toString() ?? '';
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
          final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
          final itemValue = quantity * unitPrice;

          final itemData = itemsMap[itemId];
          if (itemData != null) {
            final category = itemData['category'] ?? 'raw_material';
            if (category == 'raw_material') {
              _costByCategory['raw_material'] =
                  (_costByCategory['raw_material'] ?? 0) + itemValue;
            } else if (category == 'packaging') {
              _costByCategory['packaging'] =
                  (_costByCategory['packaging'] ?? 0) + itemValue;
            }
          }
        }

        _costData.add({
          'poNumber': data['poNumber'] ?? 'PO-${_costData.length + 1}',
          'orderDate': (data['orderDate'] as Timestamp?)?.toDate(),
          'totalAmount': totalAmount,
          'totalTax': totalTax,
          'netPayable': netPayable,
          'status': data['status'] ?? 'pending',
          'itemsCount': items.length,
        });
      }

      _costData.sort((a, b) {
        final aDate = a['orderDate'] as DateTime? ?? DateTime.now();
        final bDate = b['orderDate'] as DateTime? ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating cost analysis report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  // ✅ دالة مساعدة لتحميل الزر
  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildCategoryItem({
    required String title,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(2)} ${'currency'.tr()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade900),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    final filterBar = ReportFilterBar(
      companies: _companies.map((c) {
        return {
          'id': c['id'],
          'name': isArabic ? c['nameAr'] : c['nameEn'],
        };
      }).toList(),
      factories: _factories.map((f) {
        return {
          'id': f['id'],
          'name': isArabic ? f['nameAr'] : f['nameEn'],
        };
      }).toList(),
      selectedCompanyId: _selectedCompanyId,
      selectedFactoryId: _selectedFactoryId,
      onCompanyChanged: (val) async {
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
          _factories.clear();
          _costData.clear();
        });
        await _loadFactories();
      },
      onFactoryChanged: (val) {
        setState(() {
          _selectedFactoryId = val;
          _costData.clear();
        });
      },
      isLoading: _isLoading,
      extraFilters: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedPeriod,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'period'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: getPeriodOptions(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPeriod = val!;
                      _setPeriodDates();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingReport ? null : _generateReport,
                  icon: _isLoadingReport
                      ? _buildLoadingIndicator()
                      : const Icon(Icons.analytics),
                  label: Text(_isLoadingReport ? 'analyzing'.tr() : 'analyze'.tr()),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedPeriod == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _selectCustomDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  '${formatDate(_startDate)} → ${formatDate(_endDate)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );

    return AppScaffold(
      title: 'cost_analysis_report'.tr(),
      body: Column(
        children: [
          filterBar,
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _costData.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.analytics,
                        title: 'select_factory_and_analyze'.tr(),
                      )
                    : ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'cost_summary'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatCard(
                                      title: 'total_purchases'.tr(),
                                      value: _totalPurchaseCost.toStringAsFixed(2),
                                      icon: Icons.shopping_cart,
                                      color: Colors.blue,
                                      width: (MediaQuery.of(context).size.width - 48) / 2,
                                    ),
                                    StatCard(
                                      title: 'inventory_value'.tr(),
                                      value: _totalInventoryValue.toStringAsFixed(2),
                                      icon: Icons.inventory,
                                      color: Colors.green,
                                      width: (MediaQuery.of(context).size.width - 48) / 2,
                                    ),
                                    StatCard(
                                      title: 'total_tax'.tr(),
                                      value: _totalTaxAmount.toStringAsFixed(2),
                                      icon: Icons.receipt,
                                      color: Colors.orange,
                                      width: (MediaQuery.of(context).size.width - 48) / 2,
                                    ),
                                    StatCard(
                                      title: 'net_payable'.tr(),
                                      value: _totalNetPayable.toStringAsFixed(2),
                                      icon: Icons.attach_money,
                                      color: Colors.purple,
                                      width: (MediaQuery.of(context).size.width - 48) / 2,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'cost_by_category'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildCategoryItem(
                                      title: 'raw_materials'.tr(),
                                      value: _costByCategory['raw_material'] ?? 0,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildCategoryItem(
                                      title: 'packaging_materials'.tr(),
                                      value: _costByCategory['packaging'] ?? 0,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'purchase_orders_details'.tr(),
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
                            itemCount: _costData.length,
                            itemBuilder: (context, index) {
                              final order = _costData[index];
                              final status = order['status'] as String? ?? 'pending';
                              final isCompleted = status == 'completed';
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCompleted
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    child: Icon(
                                      isCompleted
                                          ? Icons.check
                                          : Icons.pending,
                                      color: isCompleted
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    order['poNumber'] ?? 'PO-${index + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${'date'.tr()}: ${formatDate(order['orderDate'])} | '
                                    '${'items_count'.tr()}: ${order['itemsCount']}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildDetailRow(
                                            'total_amount'.tr(),
                                            '${(order['totalAmount'] as num? ?? 0).toStringAsFixed(2)} ${'currency'.tr()}',
                                          ),
                                          const SizedBox(height: 4),
                                          _buildDetailRow(
                                            'total_tax'.tr(),
                                            '${(order['totalTax'] as num? ?? 0).toStringAsFixed(2)} ${'currency'.tr()}',
                                          ),
                                          const SizedBox(height: 4),
                                          _buildDetailRow(
                                            'net_payable'.tr(),
                                            '${(order['netPayable'] as num? ?? 0).toStringAsFixed(2)} ${'currency'.tr()}',
                                          ),
                                          const SizedBox(height: 4),
                                          _buildDetailRow(
                                            'status'.tr(),
                                            isCompleted
                                                ? 'completed'.tr()
                                                : 'pending'.tr(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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