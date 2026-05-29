// lib/pages/reports/consumption_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class ConsumptionReport extends StatefulWidget {
  const ConsumptionReport({super.key});

  @override
  State<ConsumptionReport> createState() => _ConsumptionReportState();
}

class _ConsumptionReportState extends State<ConsumptionReport> {
  bool _isLoading = false;
  bool _isLoadingReport = false;
  bool _isArabic = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedItemId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _consumptionData = [];

  double _totalConsumption = 0;
  double _averageDailyConsumption = 0;
  double _maxDailyConsumption = 0;
  double _minDailyConsumption = 0;

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

    setState(() => _isLoading = true);
    _factories = [];

    try {
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
        await _loadItems();
      }
    } catch (e) {
      safeDebugPrint('Error loading factories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadItems() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) {
      safeDebugPrint('Cannot load items: missing company or factory');
      return;
    }

    setState(() => _isLoading = true);
    _items = [];

    try {
      safeDebugPrint(
          'Loading items for company: $_selectedCompanyId, factory: $_selectedFactoryId');

      final movementsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: _selectedFactoryId)
          .get();

      safeDebugPrint('Total movements found: ${movementsSnapshot.docs.length}');

      final Set<String> itemIds = {};
      for (final doc in movementsSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId']?.toString();
        if (itemId != null && itemId.isNotEmpty) {
          itemIds.add(itemId);
          safeDebugPrint('Item ID found: $itemId');
        }
      }

      safeDebugPrint('Unique item IDs: ${itemIds.length}');

      for (final itemId in itemIds) {
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();

        if (itemDoc.exists) {
          final data = itemDoc.data()!;
          _items.add({
            'id': itemId,
            'name': _isArabic ? data['nameAr'] : data['nameEn'],
            'category': data['category'] ?? 'raw_material',
          });
          safeDebugPrint('Item added: ${_items.last['name']}');
        } else {
          safeDebugPrint('Item document not found for ID: $itemId');
        }
      }

      _items.sort((a, b) => a['name'].compareTo(b['name']));

      safeDebugPrint('Total items loaded: ${_items.length}');

      if (_items.isNotEmpty && _selectedItemId == null) {
        setState(() {
          _selectedItemId = _items.first['id'] as String;
        });
      }
    } catch (e) {
      safeDebugPrint('Error loading items: $e');
    } finally {
      setState(() => _isLoading = false);
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
      await _generateReport();
    }
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
    _consumptionData.clear();

    try {
      safeDebugPrint('Generating report for item: $_selectedItemId');

      Query query = FirebaseFirestore.instance
          .collection('companies')
          .doc(_selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: _selectedFactoryId)
          .where('itemId', isEqualTo: _selectedItemId);

      if (_startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('date', descending: false);

      final snapshot = await query.get();

      safeDebugPrint('Movements found for item: ${snapshot.docs.length}');

      double totalConsumption = 0;
      Map<String, double> dailyConsumption = {};

      for (final doc in snapshot.docs) {
        // ✅ FIXED: Safely cast the dynamic payload or fallback to an empty map
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final date = (data['date'] as Timestamp?)?.toDate();
        final movementType =
            data['type']?.toString(); // ✅ FIXED: Added ? before the bracket

        if (movementType != 'purchase' && date != null) {
          final dateKey = _formatDate(date);
          dailyConsumption[dateKey] =
              (dailyConsumption[dateKey] ?? 0) + quantity;
          totalConsumption += quantity;

          _consumptionData.add({
            'date': date,
            'quantity': quantity,
            'type': movementType,
            'referenceId': data['referenceId'],
          });
          safeDebugPrint(
              'Added consumption: $quantity at ${_formatDate(date)}');
        }
      }

      _totalConsumption = totalConsumption;

      if (dailyConsumption.isNotEmpty) {
        final values = dailyConsumption.values.toList();
        _maxDailyConsumption = values.reduce((a, b) => a > b ? a : b);
        _minDailyConsumption = values.reduce((a, b) => a < b ? a : b);
        _averageDailyConsumption = totalConsumption / dailyConsumption.length;
      } else {
        _maxDailyConsumption = 0;
        _minDailyConsumption = 0;
        _averageDailyConsumption = 0;
      }

      safeDebugPrint('Total consumption: $_totalConsumption');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${'report_generated'.tr()} (${_consumptionData.length} movements)'),
          ),
        );
      }

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating consumption report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _getTypeText(String? type) {
    switch (type) {
      case 'issue':
      case 'consumption':
        return _isArabic ? 'صرف' : 'Issue';
      case 'manufacturing':
        return _isArabic ? 'تصنيع' : 'Manufacturing';
      case 'sale':
        return _isArabic ? 'بيع' : 'Sale';
    default:
  if (type == null) {
    return _isArabic ? 'أخرى' : 'Other';
  }
  return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'consumption_report'.tr(),
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
                            _selectedItemId = null;
                            _factories = [];
                            _items = [];
                            _consumptionData = [];
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
                        onChanged: (val) async {
                          setState(() {
                            _selectedFactoryId = val;
                            _selectedItemId = null;
                            _items = [];
                            _consumptionData = [];
                          });
                          await _loadItems();
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
                        initialValue: _selectedItemId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'item'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _items.map((i) {
                          return DropdownMenuItem<String>(
                            value: i['id'],
                            child: Text(i['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedItemId = val;
                            _consumptionData = [];
                          });
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
                        ),
                        items: [
                          DropdownMenuItem<String>(
                              value: 'weekly',
                              child: Text(_isArabic ? 'أسبوعي' : 'Weekly')),
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
                            '${_formatDate(_startDate!)} → ${_formatDate(_endDate!)}',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                            : const Icon(Icons.bar_chart),
                        label: Text(_isLoadingReport
                            ? 'analyzing'.tr()
                            : 'analyze'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // عرض الصنف المختار
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
                      _items.firstWhere(
                            (i) => i['id'] == _selectedItemId,
                            orElse: () => {'name': ''},
                          )['name'] as String? ??
                          '',
                      style: TextStyle(color: Colors.blue.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // النتائج
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _consumptionData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _selectedItemId == null
                                  ? 'select_item_first'.tr()
                                  : 'no_consumption_data'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // بطاقات الإحصائيات
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'consumption_summary'.tr(),
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
                                      title: 'total_consumption'.tr(),
                                      value:
                                          _totalConsumption.toStringAsFixed(2),
                                      icon: Icons.inventory,
                                      color: Colors.blue,
                                    ),
                                    _buildStatCard(
                                      title: 'avg_daily_consumption'.tr(),
                                      value: _averageDailyConsumption
                                          .toStringAsFixed(2),
                                      icon: Icons.show_chart,
                                      color: Colors.green,
                                    ),
                                    _buildStatCard(
                                      title: 'max_daily_consumption'.tr(),
                                      value: _maxDailyConsumption
                                          .toStringAsFixed(2),
                                      icon: Icons.trending_up,
                                      color: Colors.orange,
                                    ),
                                    _buildStatCard(
                                      title: 'min_daily_consumption'.tr(),
                                      value: _minDailyConsumption
                                          .toStringAsFixed(2),
                                      icon: Icons.trending_down,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Divider(),

                          // قائمة الاستهلاك
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'consumption_details'.tr(),
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
                            itemCount: _consumptionData.length,
                            itemBuilder: (context, index) {
                              final item = _consumptionData[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(
                                    _formatDate(item['date']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${'type'.tr()}: ${_getTypeText(item['type'])}',
                                  ),
                                  trailing: Text(
                                    '- ${item['quantity'].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
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
}
