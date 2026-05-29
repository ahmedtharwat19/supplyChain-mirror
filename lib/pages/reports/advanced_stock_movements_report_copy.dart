/* /* // lib/pages/reports/advanced_stock_movements_report.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/pages/stock_movements/services/movement_utils.dart';

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
  bool _isExporting = false;
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
  List<Map<String, dynamic>> _factories = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _movements = [];

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
  Map<String, double> _movementTypeStats = {};

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
      await _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) return;

    _items = [];
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
        query = query.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();

      _totalIn = 0;
      _totalOut = 0;
      _movementTypeStats = {};

      for (final doc in snapshot.docs) {
        // ✅ FIXED: Safely cast the document data to a non-nullable map structure
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final type = data['type']?.toString() ?? 'unknown';
        final date = (data['date'] as Timestamp?)?.toDate();
        final itemId = data['itemId']?.toString() ?? '';

        final item = _items.firstWhere(
          (i) => i['id'] == itemId,
          orElse: () => {'name': 'unknown_product'.tr()},
        );
        final itemName = item['name'];

        final isIn = MovementUtils.isIncoming(type);
        final isOut = MovementUtils.isOutgoing(type);

        if (isIn) {
          _totalIn += quantity;
        }
        if (isOut) {
          _totalOut += quantity;
        }

        _movementTypeStats[type] = (_movementTypeStats[type] ?? 0) + quantity;

        _movements.add({
          'date': date,
          'itemId': itemId,
          'itemName': itemName,
          'type': type,
          'typeText': MovementUtils.getMovementTypeText(type, _isArabic),
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

  Future<void> _exportToExcel() async {
    if (_movements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_data_to_export'.tr())),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // إنشاء CSV
      String csv = 'Date,Item,Type,Quantity,In,Out\n';
      for (final m in _movements) {
        csv +=
            '${_formatDate(m['date'])},${m['itemName']},${m['typeText']},${m['quantity']},${m['in']},${m['out']}\n';
      }

      final bytes = csv.codeUnits;

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download =
              'stock_movements_${DateTime.now().millisecondsSinceEpoch}.csv'
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/stock_movements_${DateTime.now().millisecondsSinceEpoch}.csv');
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'stock_movements_${DateTime.now().millisecondsSinceEpoch}.csv',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_success'.tr())),
        );
      }
    } catch (e) {
      safeDebugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_error'.tr())),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _getMovementTypeText(String type) {
    switch (type) {
      case 'purchase':
        return _isArabic ? 'شراء' : 'Purchase';
      case 'manufacturing':
        return _isArabic ? 'تصنيع' : 'Manufacturing';
      case 'sale':
        return _isArabic ? 'بيع' : 'Sale';
      case 'issue':
        return _isArabic ? 'صرف' : 'Issue';
      case 'return':
        return _isArabic ? 'مرتجع' : 'Return';
      case 'adjustment':
        return _isArabic ? 'تعديل' : 'Adjustment';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'advanced_stock_movements'.tr(),
      actions: [Container(
        if (_movements.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'export_to_csv'.tr(),
          ),
      ],
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
                            _items = [];
                            _movements = [];
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
                            _items = [];
                            _movements = [];
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
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('الكل'),
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
                        initialValue: _selectedMovementType,
                        isExpanded: true,
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
                              value: 'all',
                              child: Text(_isArabic ? 'الكل' : 'All Time')),
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
                            : const Icon(Icons.search),
                        label: Text(_isLoadingReport
                            ? 'analyzing'.tr()
                            : 'generate'.tr()),
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

          // بطاقات الإحصائيات
          if (_movements.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildStatCard('total_in'.tr(), _totalIn.toStringAsFixed(2),
                      Colors.green, Icons.arrow_downward),
                  _buildStatCard('total_out'.tr(), _totalOut.toStringAsFixed(2),
                      Colors.red, Icons.arrow_upward),
                  _buildStatCard(
                      'net_movement'.tr(),
                      _netMovement.toStringAsFixed(2),
                      _netMovement >= 0 ? Colors.blue : Colors.orange,
                      Icons.compare_arrows),
                ],
              ),
            ),

          // قائمة الحركات
          Expanded(
            child: _isLoading || _isLoadingReport
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
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (m['in'] > 0)
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                child: Icon(
                                  (m['in'] > 0)
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color:
                                      (m['in'] > 0) ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                m['itemName'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
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
                                  color:
                                      (m['in'] > 0) ? Colors.green : Colors.red,
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
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
 */

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
  // تحويل النوع إلى خريطة لتتمكن من استخدام الأقواس المربعة بأمان
  final data = doc.data() as Map<String, dynamic>?;
  if (data == null) continue;

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
        return _isArabic ? 'شراء' : 'Purchase';
      case 'manufacturing':
      case 'production':
        return _isArabic ? 'تصنيع' : 'Manufacturing';
      case 'sale':
        return _isArabic ? 'بيع' : 'Sale';
      case 'issue':
      case 'consumption':
        return _isArabic ? 'صرف' : 'Issue';
      case 'return':
        return _isArabic ? 'مرتجع' : 'Return';
      case 'adjustment_in':
      case 'adjustment_out':
      case 'adjustment':
        return _isArabic ? 'تعديل' : 'Adjustment';
      case 'waste':
        return _isArabic ? 'تالف' : 'Waste';
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
  return Expanded(  // ✅ لف بـ Expanded
    child: Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),  // ✅ قلل الـ padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),  // ✅ قلل حجم الأيقونة
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,  // ✅ قلل حجم الخط
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,  // ✅ قلل حجم الخط
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            // شريط الفلاتر
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
                      DropdownMenuItem<String>(
                          value: 'weekly',
                          child: Text(_isArabic ? 'أسبوعي' : 'Weekly')),
                      DropdownMenuItem<String>(
                          value: 'monthly',
                          child: Text(_isArabic ? 'شهري' : 'Monthly')),
                      DropdownMenuItem<String>(
                          value: 'quarterly',
                          child: Text(_isArabic ? 'ربع سنوي' : 'Quarterly')),
                      DropdownMenuItem<String>(
                          value: 'semi_annual',
                          child: Text(_isArabic ? 'نصف سنوي' : 'Semi-Annual')),
                      DropdownMenuItem<String>(
                          value: 'annual',
                          child: Text(_isArabic ? 'سنوي' : 'Annual')),
                      DropdownMenuItem<String>(
                          value: 'all',
                          child: Text(_isArabic ? 'الكل' : 'All Time')),
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
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              children: [
                _buildAnalysisCard(
                  'total_in'.tr(),
                  _totalIn.toStringAsFixed(2),
                  Icons.arrow_downward,
                  Colors.green,
                ),
                _buildAnalysisCard(
                  'total_out'.tr(),
                  _totalOut.toStringAsFixed(2),
                  Icons.arrow_upward,
                  Colors.red,
                ),
                _buildAnalysisCard(
                  'net_movement'.tr(),
                  _netMovement.toStringAsFixed(2),
                  Icons.compare_arrows,
                  _netMovement >= 0 ? Colors.blue : Colors.orange,
                ),
              ],
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
} */