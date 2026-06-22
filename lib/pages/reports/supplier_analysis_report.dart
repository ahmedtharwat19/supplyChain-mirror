// lib/pages/reports/supplier_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class SupplierAnalysisReport extends StatefulWidget {
  const SupplierAnalysisReport({super.key});

  @override
  State<SupplierAnalysisReport> createState() => _SupplierAnalysisReportState();
}

class _SupplierAnalysisReportState extends State<SupplierAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _supplierData = [];

  int _totalSuppliers = 0;
  int _totalOrders = 0;
  double _totalSpent = 0;
  double _averageDeliveryDays = 0;

  @override
  void initState() {
    super.initState();
    _setPeriodDates();
    _loadData();
  }

  void _setPeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'weekly':
        _startDate = DateTime(now.year, now.month, now.day - 7);
        break;
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
          _startDate = DateTime(now.year, now.month - 3, now.day);
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
    setState(() => _isLoading = false);
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
      await _generateReport();
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showCustomDateRangePicker(
      context,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
      await _generateReport();
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_company_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _supplierData.clear();

    try {
      final isArabic = context.locale.languageCode == 'ar';

      // 1. جلب الموردين
      final suppliers = await _dataService.getSuppliersForCompany(
        _selectedCompanyId!,
      );

      final suppliersWithNames = suppliers.map((s) {
        return {
          'id': s['id'],
          'name': isArabic ? s['nameAr'] : s['nameEn'],
        };
      }).toList();

      if (suppliersWithNames.isEmpty) {
        setState(() => _isLoadingReport = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_suppliers_found'.tr())),
          );
        }
        return;
      }

      _totalSuppliers = suppliersWithNames.length;

      // 2. جلب أوامر الشراء للشركة
      final ordersDocs = await _dataService.getPurchaseOrders(
        companyId: _selectedCompanyId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      _totalOrders = ordersDocs.length;

      // 3. تحليل بيانات الموردين
      final Map<String, Map<String, dynamic>> supplierStats = {};

      for (final supplier in suppliersWithNames) {
        final supplierId = supplier['id'];
        supplierStats[supplierId] = {
          'name': supplier['name'],
          'totalOrders': 0,
          'totalAmount': 0.0,
          'onTimeDeliveries': 0,
          'totalLeadDays': 0,
          'leadTimeCount': 0,
          'categories': <String, double>{},
        };
      }

      double totalSpent = 0;
      int totalLeadDays = 0;
      int leadTimeCount = 0;

      for (final doc in ordersDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final supplierId = data['supplierId']?.toString() ?? '';
        final totalAmount = (data['totalAmountAfterTax'] as num?)?.toDouble() ?? 0;
        final status = data['status'];

        totalSpent += totalAmount;

        if (supplierStats.containsKey(supplierId)) {
          final stats = supplierStats[supplierId]!;
          stats['totalOrders'] = (stats['totalOrders'] as int) + 1;
          stats['totalAmount'] = (stats['totalAmount'] as double) + totalAmount;

          final expectedDate = (data['expectedDeliveryDate'] as Timestamp?)?.toDate();
          final actualDate = (data['actualDeliveryDate'] as Timestamp?)?.toDate();
          final orderDate = (data['orderDate'] as Timestamp?)?.toDate();

          if (status == 'completed' && expectedDate != null && actualDate != null) {
            final diffDays = actualDate.difference(expectedDate).inDays;
            if (diffDays <= 3) {
              stats['onTimeDeliveries'] = (stats['onTimeDeliveries'] as int) + 1;
            }
          }

          if (orderDate != null && actualDate != null) {
            final leadTime = actualDate.difference(orderDate).inDays;
            if (leadTime > 0) {
              stats['totalLeadDays'] = (stats['totalLeadDays'] as int) + leadTime;
              stats['leadTimeCount'] = (stats['leadTimeCount'] as int) + 1;
              totalLeadDays += leadTime;
              leadTimeCount++;
            }
          }

          final items = data['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final itemId = itemMap['itemId']?.toString() ?? '';
            final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
            final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
            final itemValue = quantity * unitPrice;

            final itemDoc = await FirebaseFirestore.instance
                .collection('items')
                .doc(itemId)
                .get();
            final category = itemDoc.data()?['category'] ?? 'unknown';

            final categories = stats['categories'] as Map<String, double>;
            categories[category] = (categories[category] ?? 0) + itemValue;
          }
        }
      }

      _totalSpent = totalSpent;
      _averageDeliveryDays = leadTimeCount > 0 ? totalLeadDays / leadTimeCount : 0;

      _supplierData.addAll(supplierStats.values.map((stats) {
        final onTimeRate = (stats['totalOrders'] as int) > 0
            ? ((stats['onTimeDeliveries'] as int) / (stats['totalOrders'] as int)) * 100
            : 0.0;

        final avgLeadTime = (stats['leadTimeCount'] as int) > 0
            ? (stats['totalLeadDays'] as int) / (stats['leadTimeCount'] as int)
            : 0.0;

        return {
          'name': stats['name'],
          'totalOrders': stats['totalOrders'],
          'totalAmount': stats['totalAmount'],
          'onTimeRate': onTimeRate,
          'avgLeadTime': avgLeadTime,
          'categories': stats['categories'],
        };
      }).toList());

      _supplierData.sort((a, b) {
        return (b['totalAmount'] as double).compareTo(a['totalAmount'] as double);
      });

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating supplier analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Color _getPerformanceColor(double rate) {
    if (rate >= 90) return Colors.green;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getSupplierClass(double totalAmount, double maxAmount) {
    final percentage = maxAmount > 0 ? (totalAmount / maxAmount) * 100 : 0;
    if (percentage >= 80) return 'A';
    if (percentage >= 50) return 'B';
    return 'C';
  }

  Color _getClassColor(String className) {
    switch (className) {
      case 'A':
        return Colors.red.shade700;
      case 'B':
        return Colors.orange.shade700;
      case 'C':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'supplier_analysis'.tr(),
      body: Column(
        children: [
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
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
                            _supplierData.clear();
                          });
                          await _generateReport();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          _generateReport();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_selectedPeriod == 'custom')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectCustomDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            '${formatDate(_startDate)} → ${formatDate(_endDate)}',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                if (_selectedPeriod != 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${'selected_period'.tr()}: ${_selectedPeriod.tr()}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${formatDate(_startDate)} → ${formatDate(_endDate)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_supplierData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatCard(
                    title: 'total_suppliers'.tr(),
                    value: _totalSuppliers.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'total_orders'.tr(),
                    value: _totalOrders.toString(),
                    icon: Icons.receipt_long,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatCard(
                    title: 'total_spent'.tr(),
                    value: '${_totalSpent.toStringAsFixed(2)} ${'currency'.tr()}',
                    icon: Icons.attach_money,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'avg_delivery_days'.tr(),
                    value: '${_averageDeliveryDays.toStringAsFixed(1)} ${'days'.tr()}',
                    icon: Icons.timer,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _supplierData.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.people,
                        title: _selectedCompanyId == null
                            ? 'select_company_first'.tr()
                            : 'no_suppliers_found'.tr(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _supplierData.length,
                        itemBuilder: (context, index) {
                          final supplier = _supplierData[index];
                          final maxAmount = _supplierData.isNotEmpty
                              ? (_supplierData.first['totalAmount'] as double)
                              : 1.0;
                          final supplierClass = _getSupplierClass(
                            supplier['totalAmount'] as double,
                            maxAmount,
                          );
                          final onTimeRate = supplier['onTimeRate'] as double;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getClassColor(supplierClass).withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    supplierClass,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getClassColor(supplierClass),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                supplier['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getPerformanceColor(onTimeRate).withAlpha(50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${onTimeRate.toStringAsFixed(1)}% ${'on_time'.tr()}',
                                      style: TextStyle(
                                        color: _getPerformanceColor(onTimeRate),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${supplier['totalOrders']} ${'orders'.tr()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(supplier['totalAmount'] as double).toStringAsFixed(2)} ${'currency'.tr()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${'avg_lead_time'.tr()}: ${(supplier['avgLeadTime'] as double).toStringAsFixed(1)} ${'days'.tr()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'performance_metrics'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildMetricRow(
                                        'total_orders'.tr(),
                                        supplier['totalOrders'].toString(),
                                        Icons.receipt_long,
                                        Colors.blue,
                                      ),
                                      _buildMetricRow(
                                        'total_amount'.tr(),
                                        '${(supplier['totalAmount'] as double).toStringAsFixed(2)} ${'currency'.tr()}',
                                        Icons.attach_money,
                                        Colors.purple,
                                      ),
                                      _buildMetricRow(
                                        'on_time_delivery_rate'.tr(),
                                        '${onTimeRate.toStringAsFixed(1)}%',
                                        Icons.schedule,
                                        _getPerformanceColor(onTimeRate),
                                      ),
                                      _buildMetricRow(
                                        'average_lead_time'.tr(),
                                        '${(supplier['avgLeadTime'] as double).toStringAsFixed(1)} ${'days'.tr()}',
                                        Icons.timer,
                                        Colors.orange,
                                      ),
                                      const SizedBox(height: 12),
                                      if ((supplier['categories'] as Map<String, double>).isNotEmpty) ...[
                                        Text(
                                          'category_distribution'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...(supplier['categories'] as Map<String, double>).entries.map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(
                                                    'category_${entry.key}'.tr(),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: LinearProgressIndicator(
                                                    value: _totalSpent > 0
                                                        ? (entry.value / _totalSpent).clamp(0.0, 1.0)
                                                        : 0,
                                                    backgroundColor: Colors.grey.shade200,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Colors.blue.shade400,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${entry.value.toStringAsFixed(2)} ${'currency'.tr()}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(75)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}