// lib/pages/reports/factory_performance_report.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class FactoryPerformanceReport extends StatefulWidget {
  const FactoryPerformanceReport({super.key});

  @override
  State<FactoryPerformanceReport> createState() =>
      _FactoryPerformanceReportState();
}

class _FactoryPerformanceReportState extends State<FactoryPerformanceReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factoryData = [];

  int _totalFactories = 0;
  int _totalItems = 0;
  double _totalStockValue = 0;
  double _averageTurnover = 0;

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
    _factoryData.clear();

    try {
      final isArabic = context.locale.languageCode == 'ar';

      // 1. جلب المصانع
      final factories = await _dataService.getFactoriesForCompany(
        _selectedCompanyId!,
      );

      final factoriesWithNames = factories.map((f) {
        return {
          'id': f['id'],
          'name': isArabic ? f['nameAr'] : f['nameEn'],
        };
      }).toList();

      if (factoriesWithNames.isEmpty) {
        setState(() => _isLoadingReport = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_factories_found'.tr())),
          );
        }
        return;
      }

      _totalFactories = factoriesWithNames.length;
      double totalStockValue = 0;
      double totalTurnover = 0;
      int turnoverCount = 0;

      // 2. تحليل كل مصنع
      for (final factory in factoriesWithNames) {
        final factoryId = factory['id'];

        // جلب المخزون
        final inventoryMap = await _dataService.getFactoryInventory(factoryId);

        // جلب الحركات
        final movementsDocs = await _dataService.getStockMovements(
          companyId: _selectedCompanyId!,
          factoryId: factoryId,
          startDate: _startDate,
          endDate: _endDate,
        );

        // حساب إحصائيات المخزون
        int itemCount = inventoryMap.length;
        double stockValue = 0;
        int lowStockCount = 0;
        int outOfStockCount = 0;

        for (final entry in inventoryMap.entries) {
          final data = entry.value;
          final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
          final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0;
          stockValue += quantity * unitPrice;

          if (quantity <= 0) {
            outOfStockCount++;
          } else if (quantity <= 10) {
            lowStockCount++;
          }
        }

        totalStockValue += stockValue;

        // حساب معدل الدوران
        double turnover = 0;
        if (stockValue > 0 && movementsDocs.isNotEmpty) {
          final totalMovementValue = movementsDocs.fold<double>(
            0,
            (sum, doc) {
              final data = doc.data() as Map<String, dynamic>;
              final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
              final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0;
              return sum + (quantity * unitPrice);
            },
          );
          turnover = totalMovementValue / stockValue;
          totalTurnover += turnover;
          turnoverCount++;
        }

        // تحليل أنواع الحركات
        final movementTypes = <String, int>{};
        for (final doc in movementsDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type']?.toString() ?? 'unknown';
          movementTypes[type] = (movementTypes[type] ?? 0) + 1;
        }

        _factoryData.add({
          'id': factoryId,
          'name': factory['name'],
          'itemCount': itemCount,
          'stockValue': stockValue,
          'lowStockCount': lowStockCount,
          'outOfStockCount': outOfStockCount,
          'movementCount': movementsDocs.length,
          'turnover': turnover,
          'movementTypes': movementTypes,
        });
      }

      _totalItems = _factoryData.fold<int>(
        0,
        (sum, f) => sum + (f['itemCount'] as int),
      );

      _totalStockValue = totalStockValue;
      _averageTurnover = turnoverCount > 0 ? totalTurnover / turnoverCount : 0;

      _factoryData.sort((a, b) {
        return (b['stockValue'] as double).compareTo(a['stockValue'] as double);
      });

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating factory performance report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Color _getPerformanceColor(double turnover) {
    if (turnover >= 3) return Colors.green;
    if (turnover >= 1) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'factory_performance'.tr(),
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
                            _factoryData.clear();
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
                            : const Icon(Icons.factory),
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
          if (_factoryData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatCard(
                    title: 'total_factories'.tr(),
                    value: _totalFactories.toString(),
                    icon: Icons.factory,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'total_items'.tr(),
                    value: _totalItems.toString(),
                    icon: Icons.inventory,
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
                    title: 'total_stock_value'.tr(),
                    value: '${_totalStockValue.toStringAsFixed(2)} ${'currency'.tr()}',
                    icon: Icons.attach_money,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'avg_turnover'.tr(),
                    value: _averageTurnover.toStringAsFixed(2),
                    icon: Icons.autorenew,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _factoryData.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.factory,
                        title: _selectedCompanyId == null
                            ? 'select_company_first'.tr()
                            : 'no_factories_found'.tr(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _factoryData.length,
                        itemBuilder: (context, index) {
                          final factory = _factoryData[index];
                          final turnover = factory['turnover'] as double;
                          final stockValue = factory['stockValue'] as double;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getPerformanceColor(turnover).withAlpha(50),
                                child: Icon(
                                  Icons.factory,
                                  color: _getPerformanceColor(turnover),
                                ),
                              ),
                              title: Text(
                                factory['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getPerformanceColor(turnover).withAlpha(50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'turnover'.tr(),
                                      style: TextStyle(
                                        color: _getPerformanceColor(turnover),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(turnover).toStringAsFixed(2)}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getPerformanceColor(turnover),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${factory['itemCount']} ${'items'.tr()}',
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
                                    '${stockValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${'movements'.tr()}: ${factory['movementCount']}',
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
                                        'factory_details'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildMetricRow(
                                        'total_items'.tr(),
                                        factory['itemCount'].toString(),
                                        Icons.inventory,
                                        Colors.blue,
                                      ),
                                      _buildMetricRow(
                                        'stock_value'.tr(),
                                        '${stockValue.toStringAsFixed(2)} ${'currency'.tr()}',
                                        Icons.attach_money,
                                        Colors.purple,
                                      ),
                                      _buildMetricRow(
                                        'low_stock_items'.tr(),
                                        factory['lowStockCount'].toString(),
                                        Icons.warning_amber,
                                        Colors.orange,
                                      ),
                                      _buildMetricRow(
                                        'out_of_stock_items'.tr(),
                                        factory['outOfStockCount'].toString(),
                                        Icons.warning,
                                        Colors.red,
                                      ),
                                      _buildMetricRow(
                                        'total_movements'.tr(),
                                        factory['movementCount'].toString(),
                                        Icons.compare_arrows,
                                        Colors.teal,
                                      ),
                                      _buildMetricRow(
                                        'turnover_rate'.tr(),
                                        '${turnover.toStringAsFixed(2)}x',
                                        Icons.autorenew,
                                        _getPerformanceColor(turnover),
                                      ),
                                      if ((factory['movementTypes'] as Map<String, int>).isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'movement_types_distribution'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...(factory['movementTypes'] as Map<String, int>).entries.map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(
                                                    'movement_type_${entry.key}'.tr(),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: LinearProgressIndicator(
                                                    value: (factory['movementCount'] as int) > 0
                                                        ? entry.value / (factory['movementCount'] as int)
                                                        : 0,
                                                    backgroundColor: Colors.grey.shade200,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Colors.blue.shade400,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  entry.value.toString(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue.shade700,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}