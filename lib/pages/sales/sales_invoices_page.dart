// pages/sales/sales_invoices_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/pages/sales/add_sales_invoice_page.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesInvoicesPage extends StatefulWidget {
  const SalesInvoicesPage({super.key});

  @override
  State<SalesInvoicesPage> createState() => _SalesInvoicesPageState();
}

class _SalesInvoicesPageState extends State<SalesInvoicesPage> {
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];
  List<Map<String, dynamic>> _invoices = [];
  double _totalSales = 0.0;
  bool _isLoading = true;
  bool _isSyncing = false;

  static const String _keyInvoicesCache = 'sales_invoices_cache';
  static const String _keyTotalSalesCache = 'total_sales_cache';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCompaniesAndData();
    if (mounted) setState(() => _isLoading = false);
    _syncFromFirestoreInBackground();
  }

  Future<void> _loadCompaniesAndData() async {
    try {
      final companies = await CompanyHelper.getUserCompanies();
      if (companies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('no_companies_found'.tr()),
                backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      String? selectedId = await CompanyHelper.getSelectedCompanyId();
      if (selectedId == null || !companies.any((c) => c['id'] == selectedId)) {
        selectedId = companies.first['id'];
      }

      setState(() {
        _companies = companies;
        _selectedCompanyId = selectedId;
      });

      await _loadFromCache();
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('error_loading_companies'.tr()),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFromCache() async {
    if (_selectedCompanyId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalStr =
          prefs.getString('${_keyTotalSalesCache}_$_selectedCompanyId');
      if (totalStr != null) _totalSales = double.parse(totalStr);

      final invoicesJson =
          prefs.getString('${_keyInvoicesCache}_$_selectedCompanyId');
      if (invoicesJson != null) {
        final List<dynamic> decoded = json.decode(invoicesJson);
        _invoices =
            decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        safeDebugPrint('📦 Loaded ${_invoices.length} invoices from cache');
      }
    } catch (e) {
      safeDebugPrint('⚠️ Cache load error: $e');
    }
  }

  Future<void> _saveToCache() async {
    if (_selectedCompanyId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_keyTotalSalesCache}_$_selectedCompanyId', _totalSales.toString());
      await prefs.setString(
          '${_keyInvoicesCache}_$_selectedCompanyId', json.encode(_invoices));
      safeDebugPrint('💾 Sales invoices saved to cache');
    } catch (e) {
      safeDebugPrint('❌ Error saving cache: $e');
    }
  }

  Future<void> _syncFromFirestoreInBackground() async {
    if (_selectedCompanyId == null) return;
    if (mounted) setState(() => _isSyncing = true);
    await _fetchFromFirestore();
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _fetchFromFirestore() async {
    if (_selectedCompanyId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('journal_entries')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('referenceType', isEqualTo: 'sales_invoice')
          .orderBy('entryDate', descending: true)
          .get();

      List<Map<String, dynamic>> loadedInvoices = [];
      double total = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        total += amount;

        loadedInvoices.add({
          'id': doc.id,
          'customerName': data['customerName'] ?? 'غير معروف',
          'totalAmount': amount,
          'description': data['description'] ?? '',
          'entryDate': (data['entryDate'] as Timestamp).toDate(),
          'paymentMethod': data['paymentMethod'] ?? 'credit',
          'items': data['items'] ?? [],
        });
      }

      _invoices = loadedInvoices;
      _totalSales = total;

      safeDebugPrint(
          '✅ Synced ${_invoices.length} invoices, total: $_totalSales');
      await _saveToCache();
      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('❌ Firestore sync error: $e');
    }
  }

  Future<void> _onCompanyChanged(String? newCompanyId) async {
    if (newCompanyId == null || newCompanyId == _selectedCompanyId) return;
    await CompanyHelper.setSelectedCompanyId(newCompanyId);
    setState(() {
      _selectedCompanyId = newCompanyId;
      _isLoading = true;
      _invoices.clear();
      _totalSales = 0.0;
    });
    await _loadFromCache();
    await _syncFromFirestoreInBackground();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (_companies.length > 1 && _selectedCompanyId != null) {
      actions.add(
        CompanyHelper.buildCompanyDropdown(
          companies: _companies,
          selectedCompanyId: _selectedCompanyId,
          onChanged: _onCompanyChanged,
          languageCode: context.locale.languageCode,
          dropdownColor: Colors.white,
          textColor: Colors.black,
          iconColor: Colors.black,
        ),
      );
    }

    return AppScaffold(
      title: 'sales_invoices'.tr(),
      actions: actions,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddSalesInvoicePage(
                      initialCompanyId: _selectedCompanyId,
                    )),
          ).then((_) => _syncFromFirestoreInBackground());
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('total_sales'.tr(),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          if (_isSyncing)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),
                        ],
                      ),
                      Text(
                        '${_totalSales.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color:
                                _totalSales >= 0 ? Colors.orange : Colors.red),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _invoices.isEmpty
                      ? Center(child: Text('no_invoices'.tr()))
                      : ListView.builder(
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final inv = _invoices[index];
                            final amount = inv['totalAmount'] as double;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Text((index + 1).toString(),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                title: Text(inv['customerName']),
                                subtitle: Text(
                                    '${DateFormat('dd/MM/yyyy').format(inv['entryDate'])} | ${inv['description']}'),
                                trailing: Text(
                                  '${amount.toStringAsFixed(2)} EGP',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.orange),
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
}
