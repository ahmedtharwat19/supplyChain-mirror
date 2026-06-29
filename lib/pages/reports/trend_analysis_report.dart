  // lib/pages/reports/trend_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class TrendAnalysisReport extends StatefulWidget {
  const TrendAnalysisReport({super.key});

  @override
  State<TrendAnalysisReport> createState() => _TrendAnalysisReportState();
}

class _TrendAnalysisReportState extends State<TrendAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedItemId;
  String _trendType = 'consumption';
  int _monthsCount = 6;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _trendData = [];

  double _trendAverage = 0;
  double _trendGrowth = 0;
  double _maxValue = 0;
  double _minValue = 0;
  String _trendDirection = 'stable';

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
    
    // ✅ تخزين البيانات الخام
    setState(() {
      _companies..clear()..addAll(companies.map((c) {
        return {
          'id': c['id'].toString(),
          'nameAr': c['nameAr']?.toString() ?? c['id'].toString(),
          'nameEn': c['nameEn']?.toString() ?? c['id'].toString(),
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
    
    // ✅ تخزين البيانات الخام
    setState(() {
      _factories..clear()..addAll(factories.map((f) {
        return {
          'id': f['id'].toString(),
          'nameAr': f['nameAr']?.toString() ?? f['id'].toString(),
          'nameEn': f['nameEn']?.toString() ?? f['id'].toString(),
        };
      }).toList());
    });

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      _selectedFactoryId = _factories.first['id'] as String;
      await _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) return;

    final itemsMap = await _dataService.getItemsMap();

    final movementsDocs = await _dataService.getStockMovements(
      companyId: _selectedCompanyId!,
      factoryId: _selectedFactoryId!,
    );

    final Set<String> itemIds = {};
    for (final doc in movementsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final itemId = data['itemId']?.toString();
      if (itemId != null && itemId.isNotEmpty) {
        itemIds.add(itemId);
      }
    }

    // ✅ تخزين البيانات الخام
    final items = itemIds.where((id) => itemsMap.containsKey(id)).map((id) {
      final data = itemsMap[id]!;
      return {
        'id': id,
        'nameAr': data['nameAr'] ?? id,
        'nameEn': data['nameEn'] ?? id,
      };
    }).toList();

    items.sort((a, b) => a['nameEn'].compareTo(b['nameEn']));

    setState(() {
      _items..clear()..addAll(items);
      if (_items.isNotEmpty && _selectedItemId == null) {
        _selectedItemId = _items.first['id'] as String;
      }
    });
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null ||
        _selectedFactoryId == null ||
        _selectedItemId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_item_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _trendData.clear();

    try {
      final now = DateTime.now();
      final startDate = DateTime(
        now.year,
        now.month - _monthsCount,
        now.day,
      );

      final movementsDocs = await _dataService.getStockMovements(
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId!,
        itemId: _selectedItemId,
        startDate: startDate,
        endDate: now,
      );

      final Map<String, Map<String, double>> monthlyData = {};

      for (final doc in movementsDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['date'] as Timestamp?)?.toDate();
        final type = data['type']?.toString() ?? '';
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;

        if (date == null) continue;

        final monthKey = '${date.year}/${date.month.toString().padLeft(2, '0')}';

        if (!monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = {
            'purchases': 0.0,
            'consumption': 0.0,
            'movements': 0.0,
          };
        }

        if (type == 'purchase') {
          monthlyData[monthKey]!['purchases'] =
              (monthlyData[monthKey]!['purchases'] ?? 0) + quantity;
        } else {
          monthlyData[monthKey]!['consumption'] =
              (monthlyData[monthKey]!['consumption'] ?? 0) + quantity;
        }
        monthlyData[monthKey]!['movements'] =
            (monthlyData[monthKey]!['movements'] ?? 0) + quantity;
      }

      final sortedKeys = monthlyData.keys.toList()..sort();

      final values = <double>[];
      for (final key in sortedKeys) {
        final data = monthlyData[key]!;
        double value;
        switch (_trendType) {
          case 'purchases':
            value = data['purchases'] ?? 0;
            break;
          case 'movements':
            value = data['movements'] ?? 0;
            break;
          default:
            value = data['consumption'] ?? 0;
        }

        values.add(value);
        _trendData.add({
          'month': key,
          'value': value,
        });
      }

      if (values.isNotEmpty) {
        _trendAverage = values.reduce((a, b) => a + b) / values.length;
        _maxValue = values.reduce((a, b) => a > b ? a : b);
        _minValue = values.reduce((a, b) => a < b ? a : b);

        final half = values.length ~/ 2;
        if (half > 0) {
          final firstHalf = values.sublist(0, half);
          final secondHalf = values.sublist(half);
          final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
          final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

          _trendGrowth = firstAvg > 0
              ? ((secondAvg - firstAvg) / firstAvg) * 100
              : 0;

          if (_trendGrowth > 5) {
            _trendDirection = 'up';
          } else if (_trendGrowth < -5) {
            _trendDirection = 'down';
          } else {
            _trendDirection = 'stable';
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating trend analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  Color _getTrendColor() {
    switch (_trendDirection) {
      case 'up':
        return Colors.green;
      case 'down':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getTrendIcon() {
    switch (_trendDirection) {
      case 'up':
        return '📈';
      case 'down':
        return '📉';
      default:
        return '➡️';
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

  @override
  Widget build(BuildContext context) {
    // ✅ تحديد اللغة الحالية في الـ build
    final isArabic = context.locale.languageCode == 'ar';

    // ✅ تحويل البيانات إلى الشكل المطلوب مع الاسم حسب اللغة
    final companyItems = _companies.map((c) {
      return {
        'id': c['id'],
        'name': isArabic 
            ? (c['nameAr'] ?? c['nameEn'] ?? c['id'])
            : (c['nameEn'] ?? c['nameAr'] ?? c['id']),
      };
    }).toList();

    final factoryItems = _factories.map((f) {
      return {
        'id': f['id'],
        'name': isArabic 
            ? (f['nameAr'] ?? f['nameEn'] ?? f['id'])
            : (f['nameEn'] ?? f['nameAr'] ?? f['id']),
      };
    }).toList();

    final itemItems = _items.map((i) {
      return {
        'id': i['id'],
        'name': isArabic 
            ? (i['nameAr'] ?? i['nameEn'] ?? i['id'])
            : (i['nameEn'] ?? i['nameAr'] ?? i['id']),
      };
    }).toList();

    // ✅ استخدام بيانات محولة حسب اللغة
    final filterBar = ReportFilterBar(
      companies: companyItems,
      factories: factoryItems,
      selectedCompanyId: _selectedCompanyId,
      selectedFactoryId: _selectedFactoryId,
      onCompanyChanged: (val) async {
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
          _selectedItemId = null;
          _factories.clear();
          _items.clear();
          _trendData.clear();
        });
        await _loadFactories();
      },
      onFactoryChanged: (val) async {
        setState(() {
          _selectedFactoryId = val;
          _selectedItemId = null;
          _items.clear();
          _trendData.clear();
        });
        await _loadItems();
      },
      isLoading: _isLoading,
      extraFilters: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedItemId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'item'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: itemItems.map((i) {
                    return DropdownMenuItem<String>(
                      value: i['id'],
                      child: Text(i['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedItemId = val;
                      _trendData.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _trendType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'trend_type'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'consumption',
                      child: Text('consumption'.tr()),
                    ),
                    DropdownMenuItem<String>(
                      value: 'purchases',
                      child: Text('purchases'.tr()),
                    ),
                    DropdownMenuItem<String>(
                      value: 'movements',
                      child: Text('movements'.tr()),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _trendType = val!;
                      _trendData.clear();
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
                child: DropdownButtonFormField<int>(
                  initialValue: _monthsCount,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'months_count'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [3, 6, 9, 12, 24].map((months) {
                    return DropdownMenuItem<int>(
                      value: months,
                      child: Text('$months ${'months'.tr()}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _monthsCount = val!;
                      _trendData.clear();
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
                      : const Icon(Icons.trending_up),
                  label: Text(_isLoadingReport ? 'analyzing'.tr() : 'analyze'.tr()),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // ✅ اسم الصنف المختار حسب اللغة
    String selectedItemName = '';
    if (_selectedItemId != null) {
      final found = itemItems.firstWhere(
        (i) => i['id'] == _selectedItemId,
        orElse: () => {'name': ''},
      );
      selectedItemName = found['name'] ?? '';
    }

    return AppScaffold(
      title: 'trend_analysis'.tr(),
      body: Column(
        children: [
          filterBar,
          if (_selectedItemId != null && _items.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${'selected_item'.tr()}: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Text(
                      selectedItemName,
                      style: TextStyle(color: Colors.blue.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTrendColor().withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _trendType.tr(),
                      style: TextStyle(
                        color: _getTrendColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _trendData.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.trending_up,
                        title: _selectedItemId == null
                            ? 'select_item_first'.tr()
                            : 'no_data_available'.tr(),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Row(
                            children: [
                              _buildTrendStatCard(
                                title: 'trend_direction'.tr(),
                                value: _getTrendIcon(),
                                subtitle: 'trend_$_trendDirection'.tr(),
                                color: _getTrendColor(),
                              ),
                              const SizedBox(width: 8),
                              _buildTrendStatCard(
                                title: 'average'.tr(),
                                value: _trendAverage.toStringAsFixed(2),
                                subtitle: 'per_month'.tr(),
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTrendStatCard(
                                title: 'growth_rate'.tr(),
                                value: '${_trendGrowth.toStringAsFixed(1)}%',
                                subtitle: _trendGrowth >= 0
                                    ? 'increasing'.tr()
                                    : 'decreasing'.tr(),
                                color: _trendGrowth >= 0 ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              _buildTrendStatCard(
                                title: 'range'.tr(),
                                value: '${_minValue.toStringAsFixed(2)} → ${_maxValue.toStringAsFixed(2)}',
                                subtitle: 'min_max'.tr(),
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'trend_chart'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._trendData.map((data) {
                                  final value = data['value'] as double;
                                  final maxValue = _maxValue > 0 ? _maxValue : 1;
                                  final percentage = value / maxValue;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            data['month'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: percentage.clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.blue.shade300,
                                                      Colors.blue.shade700,
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    value.toStringAsFixed(2),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(percentage * 100).toStringAsFixed(0)}%',
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
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getTrendColor().withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getTrendColor().withAlpha(50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _getTrendIcon(),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'trend_analysis_summary'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'trend_analysis_$_trendDirection'.tr(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendStatCard({
    required String title,
    required String value,
    required String subtitle,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}