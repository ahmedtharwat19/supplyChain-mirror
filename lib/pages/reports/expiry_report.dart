// lib/pages/reports/expiry_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class ExpiryReport extends StatefulWidget {
  const ExpiryReport({super.key});

  @override
  State<ExpiryReport> createState() => _ExpiryReportState();
}

class _ExpiryReportState extends State<ExpiryReport> {
  bool _isLoading = false;
  bool _isArabic = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  int _alertDays = 30; // تنبيه قبل 30 يوم من الصلاحية
  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _expiringItems = [];

  final List<int> _alertOptions = [7, 14, 30, 60, 90];

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

    final userCompanyIds =
        (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

    for (final companyId in userCompanyIds) {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
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
    _expiringItems.clear();

    try {
      final today = DateTime.now();
    //  final alertDate = today.add(Duration(days: _alertDays));

      // جلب جميع الأصناف التي لها تاريخ صلاحية
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('hasExpiry', isEqualTo: true)
          .get();

      final expiryItemsIds = itemsSnapshot.docs.map((doc) => doc.id).toList();

      if (expiryItemsIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // جلب المخزون لهذه الأصناف
      for (final itemId in expiryItemsIds) {
        final inventoryDoc = await FirebaseFirestore.instance
            .collection('factories')
            .doc(_selectedFactoryId)
            .collection('inventory')
            .doc(itemId)
            .get();

        if (!inventoryDoc.exists) continue;

        final inventoryData = inventoryDoc.data()!;
        final expiryDate =
            (inventoryData['expiryDate'] as Timestamp?)?.toDate();
        final batchNumber = inventoryData['batchNumber'] ?? '';
        final quantity = inventoryData['quantity'] ?? 0;

        if (expiryDate == null) continue;

        final daysUntilExpiry = expiryDate.difference(today).inDays;

        // إذا كان الصنف منتهي الصلاحية أو على وشك الانتهاء
        if (daysUntilExpiry <= _alertDays) {
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .get();

          final itemData = itemDoc.data();
          final itemName = _isArabic
              ? (itemData?['nameAr'] ?? itemData?['nameEn'] ?? itemId)
              : (itemData?['nameEn'] ?? itemData?['nameAr'] ?? itemId);

          _expiringItems.add({
            'itemId': itemId,
            'itemName': itemName,
            'batchNumber': batchNumber,
            'quantity': quantity,
            'expiryDate': expiryDate,
            'daysUntilExpiry': daysUntilExpiry,
            'isExpired': daysUntilExpiry < 0,
            'status': daysUntilExpiry < 0
                ? 'expired'
                : (daysUntilExpiry <= 7 ? 'critical' : 'warning'),
          });
        }
      }

      // ترتيب النتائج (الأقرب للانتهاء أولاً)
      _expiringItems
          .sort((a, b) => a['daysUntilExpiry'].compareTo(b['daysUntilExpiry']));

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating expiry report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'expired':
        return Colors.red;
      case 'critical':
        return Colors.orange;
      case 'warning':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    if (_isArabic) {
      switch (status) {
        case 'expired':
          return 'منتهي الصلاحية';
        case 'critical':
          return 'حرج (أقل من 7 أيام)';
        case 'warning':
          return 'تنبيه';
        default:
          return '';
      }
    } else {
      switch (status) {
        case 'expired':
          return 'Expired';
        case 'critical':
          return 'Critical (< 7 days)';
        case 'warning':
          return 'Warning';
        default:
          return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'expiry_report'.tr(),
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
                      child: DropdownButtonFormField<int>(
                        initialValue: _alertDays,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'alert_before_expiry'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _alertOptions.map((days) {
                          return DropdownMenuItem<int>(
                            value: days,
                            child: Text('$days ${'days'.tr()}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _alertDays = val!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateReport,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: Text('generate_report'.tr()),
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
                : _expiringItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified,
                                size: 64, color: Colors.green.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'no_expiring_items'.tr(),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'all_items_good'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _expiringItems.length,
                        itemBuilder: (context, index) {
                          final item = _expiringItems[index];
                          final status = item['status'];
                          final days = item['daysUntilExpiry'];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: _getStatusColor(status)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status)
                                    .withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.timer,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['itemName'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusText(status),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${'batch_number'.tr()}: ${item['batchNumber']}'),
                                  Text(
                                      '${'quantity'.tr()}: ${item['quantity']}'),
                                  Text(
                                    '${'expiry_date'.tr()}: ${_formatDate(item['expiryDate'])}',
                                    style: TextStyle(
                                      color: days < 0
                                          ? Colors.red
                                          : Colors.grey.shade700,
                                      fontWeight: days < 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    days < 0
                                        ? '${'expired_since'.tr()}: ${-days} ${'days'.tr()}'
                                        : '${'days_until_expiry'.tr()}: $days ${'days'.tr()}',
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow(
                                        Icons.warning,
                                        'recommendation'.tr(),
                                        days < 0
                                            ? (_isArabic
                                                ? 'يجب التخلص من هذا المنتج فوراً'
                                                : 'Must be disposed immediately')
                                            : days <= 7
                                                ? (_isArabic
                                                    ? 'يجب استخدام هذا المنتج بشكل عاجل أو إجراء تخفيضات'
                                                    : 'Urgent use or markdown required')
                                                : (_isArabic
                                                    ? 'خطط لاستخدام هذا المنتج قبل انتهاء صلاحيته'
                                                    : 'Plan to use before expiry'),
                                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
