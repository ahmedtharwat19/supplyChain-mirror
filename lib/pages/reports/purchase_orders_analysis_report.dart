// lib/pages/reports/purchase_orders_analysis_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class PurchaseOrdersAnalysisReport extends StatefulWidget {
  const PurchaseOrdersAnalysisReport({super.key});

  @override
  State<PurchaseOrdersAnalysisReport> createState() =>
      _PurchaseOrdersAnalysisReportState();
}

class _PurchaseOrdersAnalysisReportState
    extends State<PurchaseOrdersAnalysisReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedSupplierId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _suppliers = [];
  final List<Map<String, dynamic>> _orders = [];

  int _totalOrders = 0;
  int _completedOrders = 0;
  int _pendingOrders = 0;
  int _cancelledOrders = 0;
  double _totalValue = 0;
  double _averageOrderValue = 0;
  final Map<String, int> _monthlyDistribution = {};

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
      await _loadSuppliers();
      await _generateReport();
    }
  }

  Future<void> _loadSuppliers() async {
    if (_selectedCompanyId == null) return;
    if (!mounted) return;

    final suppliers = await _dataService.getSuppliersForCompany(
      _selectedCompanyId!,
    );
    if (!mounted) return;
    
    final isArabic = context.locale.languageCode == 'ar';
    setState(() {
      _suppliers..clear()..addAll(suppliers.map((s) {
        return {
          'id': s['id'],
          'name': isArabic ? s['nameAr'] : s['nameEn'],
        };
      }).toList());
    });
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
    _orders.clear();
    _monthlyDistribution.clear();

    try {
      final ordersDocs = await _dataService.getPurchaseOrders(
        companyId: _selectedCompanyId!,
        supplierId: _selectedSupplierId,
        startDate: _startDate,
        endDate: _endDate,
      );

      _totalOrders = ordersDocs.length;
      _completedOrders = 0;
      _pendingOrders = 0;
      _cancelledOrders = 0;
      _totalValue = 0;

      final supplierMap = <String, String>{};
      for (final s in _suppliers) {
        supplierMap[s['id']] = s['name'];
      }

      for (final doc in ordersDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? 'pending';
        final totalAmount = (data['totalAmountAfterTax'] as num?)?.toDouble() ?? 0;

        _totalValue += totalAmount;

        switch (status) {
          case 'completed':
            _completedOrders++;
            break;
          case 'cancelled':
            _cancelledOrders++;
            break;
          default:
            _pendingOrders++;
        }

        final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
        if (orderDate != null) {
          final monthKey = '${orderDate.year}/${orderDate.month.toString().padLeft(2, '0')}';
          _monthlyDistribution[monthKey] = (_monthlyDistribution[monthKey] ?? 0) + 1;
        }

        final supplierId = data['supplierId']?.toString() ?? '';
        _orders.add({
          'poNumber': data['poNumber'],
          'orderDate': orderDate,
          'expectedDelivery': (data['expectedDeliveryDate'] as Timestamp?)?.toDate(),
          'actualDelivery': (data['actualDeliveryDate'] as Timestamp?)?.toDate(),
          'status': status,
          'totalAmount': totalAmount,
          'supplierName': supplierMap[supplierId] ?? 'unknown_supplier'.tr(),
          'itemsCount': (data['items'] as List<dynamic>?)?.length ?? 0,
        });
      }

      _orders.sort((a, b) {
        final aDate = a['orderDate'] as DateTime? ?? DateTime.now();
        final bDate = b['orderDate'] as DateTime? ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      _averageOrderValue = _totalOrders > 0 ? _totalValue / _totalOrders : 0;

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating purchase orders analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'purchase_orders_analysis'.tr(),
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
                            _selectedSupplierId = null;
                            _suppliers.clear();
                            _orders.clear();
                          });
                          await _loadSuppliers();
                          await _generateReport();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSupplierId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'supplier'.tr(),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('all'),
                          ),
                          ..._suppliers.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['id'],
                              child: Text(s['name']),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedSupplierId = val;
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingReport ? null : _generateReport,
                        icon: _isLoadingReport
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
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
          if (_orders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatCard(
                    title: 'total_orders'.tr(),
                    value: _totalOrders.toString(),
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'total_value'.tr(),
                    value: '${_totalValue.toStringAsFixed(2)} ${'currency'.tr()}',
                    icon: Icons.attach_money,
                    color: Colors.purple,
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
                    title: 'avg_order_value'.tr(),
                    value: '${_averageOrderValue.toStringAsFixed(2)} ${'currency'.tr()}',
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'completed_orders'.tr(),
                    value: '$_completedOrders/$_totalOrders',
                    icon: Icons.check_circle,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildSmallStatCard(
                    title: 'pending'.tr(),
                    value: _pendingOrders.toString(),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildSmallStatCard(
                    title: 'cancelled'.tr(),
                    value: _cancelledOrders.toString(),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            if (_monthlyDistribution.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'monthly_distribution'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._monthlyDistribution.entries.take(12).map((entry) {
                      final maxCount = _monthlyDistribution.values.isNotEmpty
                          ? _monthlyDistribution.values.reduce((a, b) => a > b ? a : b)
                          : 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: maxCount > 0 ? entry.value / maxCount : 0,
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
                ),
              ),
            ],
          ],
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.receipt_long,
                        title: _selectedCompanyId == null
                            ? 'select_company_first'.tr()
                            : 'no_orders_found'.tr(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final status = order['status'] as String;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status).withAlpha(50),
                                child: Icon(
                                  status == 'completed'
                                      ? Icons.check
                                      : status == 'cancelled'
                                          ? Icons.cancel
                                          : Icons.pending,
                                  color: _getStatusColor(status),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                order['poNumber'] ?? 'PO-${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${order['supplierName']} | ${formatDate(order['orderDate'])} | ${order['itemsCount']} ${'items'.tr()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(order['totalAmount'] as double).toStringAsFixed(2)} ${'currency'.tr()}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'order_status_$status'.tr(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showOrderDetails(order),
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

  Widget _buildSmallStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('order_details'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('po_number'.tr(), order['poNumber'] ?? '-'),
            _buildDetailRow('supplier'.tr(), order['supplierName']),
            _buildDetailRow('order_date'.tr(), formatDate(order['orderDate'])),
            _buildDetailRow('expected_delivery'.tr(), formatDate(order['expectedDelivery'])),
            _buildDetailRow('actual_delivery'.tr(), formatDate(order['actualDelivery'])),
            _buildDetailRow('status'.tr(), 'order_status_${order['status']}'.tr()),
            _buildDetailRow('items_count'.tr(), order['itemsCount'].toString()),
            _buildDetailRow(
              'total_amount'.tr(),
              '${(order['totalAmount'] as double).toStringAsFixed(2)} ${'currency'.tr()}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}