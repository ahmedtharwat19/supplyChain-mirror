// lib/pages/reports/advanced_stock_movements_report.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AdvancedStockMovementsReport extends StatefulWidget {
  const AdvancedStockMovementsReport({super.key});

  @override
  State<AdvancedStockMovementsReport> createState() =>
      _AdvancedStockMovementsReportState();
}

class _AdvancedStockMovementsReportState
    extends State<AdvancedStockMovementsReport> {
  bool _isLoading = false;
  bool _isLoadingReport = false;
  bool _isArabic = false;

  // الفلاتر
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedItemId;
  String? _selectedMovementType;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  // البيانات
  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _movements = [];

  // أنواع الحركات
  final List<String> _movementTypes = [
    'all',
    'purchase',
    'manufacturing',
    'sale',
    'issue',
    'return',
    'adjustment'
  ];

  // إحصائيات
  double _totalIn = 0;
  double _totalOut = 0;
  double _netMovement = 0;

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

    _factories.clear();
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
      await _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) return;

    _items.clear();
    final movementsSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_selectedCompanyId)
        .collection('stock_movements')
        .where('factoryId', isEqualTo: _selectedFactoryId)
        .get();

    final Set<String> itemIds = {};
    for (final doc in movementsSnapshot.docs) {
      final itemId = doc.data()['itemId']?.toString();
      if (itemId != null && itemId.isNotEmpty) {
        itemIds.add(itemId);
      }
    }

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
        });
      }
    }

    _items.sort((a, b) => a['name'].compareTo(b['name']));
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
    _movements.clear();

    try {
      Query query = FirebaseFirestore.instance
          .collection('companies')
          .doc(_selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: _selectedFactoryId);

      if (_selectedItemId != null && _selectedItemId!.isNotEmpty) {
        query = query.where('itemId', isEqualTo: _selectedItemId);
      }

      if (_selectedMovementType != null &&
          _selectedMovementType != 'all' &&
          _selectedMovementType!.isNotEmpty) {
        query = query.where('type', isEqualTo: _selectedMovementType);
      }

      if (_startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();

      _totalIn = 0;
      _totalOut = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final type = data['type']?.toString() ?? 'unknown';
        final date = (data['date'] as Timestamp?)?.toDate();
        final itemId = data['itemId']?.toString() ?? '';

        final item = _items.firstWhere(
          (i) => i['id'] == itemId,
          orElse: () => {'name': 'unknown_product'.tr()},
        );
        final itemName = item['name'];

        final isIn = _isIncomingMovement(type);
        final isOut = _isOutgoingMovement(type);

        if (isIn) {
          _totalIn += quantity;
        }
        if (isOut) {
          _totalOut += quantity;
        }

        _movements.add({
          'date': date,
          'itemId': itemId,
          'itemName': itemName,
          'type': type,
          'typeText': _getMovementTypeText(type),
          'quantity': quantity,
          'in': isIn ? quantity : 0,
          'out': isOut ? quantity : 0,
        });
      }

      _netMovement = _totalIn - _totalOut;

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating movements report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  bool _isIncomingMovement(String type) {
    return type == 'purchase' || type == 'return' || type == 'adjustment_in';
  }

  bool _isOutgoingMovement(String type) {
    return type == 'manufacturing' || type == 'production' || 
           type == 'sale' || type == 'issue' || type == 'consumption' || 
           type == 'adjustment_out' || type == 'waste';
  }

 String _getMovementTypeText(String type) {
  switch (type) {
    case 'purchase':
      return 'purchase'.tr();
    case 'manufacturing':
    case 'production':
      return 'manufacturing'.tr();
    case 'sale':
      return 'sale'.tr();
    case 'issue':
    case 'consumption':
      return 'issue'.tr();
    case 'return':
      return 'return'.tr();
    case 'adjustment_in':
    case 'adjustment_out':
    case 'adjustment':
      return 'adjustment'.tr();
    case 'waste':
      return 'waste'.tr();
    default:
      return type;
  }
}

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAnalysisCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('advanced_stock_movements'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // شريط الفلاتر - الصف الأول
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedCompanyId,
                    decoration: InputDecoration(
                      labelText: 'select_company'.tr(),
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
                        _factories.clear();
                        _items.clear();
                        _movements.clear();
                      });
                      await _loadFactories();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedFactoryId,
                    decoration: InputDecoration(
                      labelText: 'select_factory'.tr(),
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
                        _items.clear();
                        _movements.clear();
                      });
                      await _loadItems();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // شريط الفلاتر - الصف الثاني
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedItemId,
                    decoration: InputDecoration(
                      labelText: 'select_item'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('all'.tr()),
                      ),
                      ..._items.map((i) {
                        return DropdownMenuItem<String>(
                          value: i['id'],
                          child: Text(i['name']),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedItemId = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedMovementType,
                    decoration: InputDecoration(
                      labelText: 'movement_type'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: _movementTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_getMovementTypeText(type)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedMovementType = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // شريط الفلاتر - الصف الثالث
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedPeriod,
                    decoration: InputDecoration(
                      labelText: 'period'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String>(value: 'weekly', child: Text('weekly'.tr())),
                      DropdownMenuItem<String>(value: 'monthly', child: Text('monthly'.tr())),
                      DropdownMenuItem<String>(value: 'quarterly', child: Text('quarterly'.tr())),
                      DropdownMenuItem<String>(value: 'semi_annual', child: Text('semi_annual'.tr())),
                      DropdownMenuItem<String>(value: 'annual', child: Text('annual'.tr())),
                      DropdownMenuItem<String>(value: 'all', child: Text('all'.tr())),
                      DropdownMenuItem<String>(value: 'custom', child: Text('custom'.tr())),
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
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: Text(_isLoadingReport ? 'analyzing'.tr() : 'generate'.tr()),
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
            const SizedBox(height: 16),

            // بطاقات الإحصائيات
            SizedBox(
              height: 130,
              child: Row(
                children: [
                  Expanded(child: _buildAnalysisCard(
                    'total_in'.tr(),
                    _totalIn.toStringAsFixed(2),
                    Icons.arrow_downward,
                    Colors.green,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalysisCard(
                    'total_out'.tr(),
                    _totalOut.toStringAsFixed(2),
                    Icons.arrow_upward,
                    Colors.red,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalysisCard(
                    'net_movement'.tr(),
                    _netMovement.toStringAsFixed(2),
                    Icons.compare_arrows,
                    _netMovement >= 0 ? Colors.blue : Colors.orange,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قائمة الحركات
            Expanded(
              child: _isLoadingReport
                  ? const Center(child: CircularProgressIndicator())
                  : _movements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'no_movements_found'.tr(),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final m = _movements[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (m['in'] > 0)
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  child: Icon(
                                    (m['in'] > 0)
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: (m['in'] > 0) ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  m['itemName'],
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${_formatDate(m['date'])} | ${m['typeText']}',
                                ),
                                trailing: Text(
                                  (m['in'] > 0)
                                      ? '+ ${m['quantity'].toStringAsFixed(2)}'
                                      : '- ${m['quantity'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (m['in'] > 0) ? Colors.green : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}