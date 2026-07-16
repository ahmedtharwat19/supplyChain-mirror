// pages/financial/cash_management_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/services/accounting_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashManagementPage extends StatefulWidget {
  const CashManagementPage({super.key});

  @override
  State<CashManagementPage> createState() => _CashManagementPageState();
}

class _CashManagementPageState extends State<CashManagementPage> {
  String? _companyId;
  String? _cashAccountId;
  double _cashBalance = 0.0;
  bool _isLoading = true;
  bool _isSyncing = false;
  final List<Map<String, dynamic>> _recentTransactions = [];

  // متغيرات اختيار الشركة
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];

  // كاش لأسماء الموردين
  final Map<String, Map<String, String>> _supplierNameCache = {};

  // مفاتيح التخزين المؤقت
  static const String _keyCashBalance = 'cash_balance_cache';
  static const String _keyCashTransactions = 'cash_transactions_cache';
  static const String _keyCashAccountId = 'cash_account_id_cache';

  @override
  void initState() {
    super.initState();
    _loadCompaniesAndData();
  }

  // ─── تحميل الشركات ثم البيانات ──────────────────────────────────
  Future<void> _loadCompaniesAndData() async {
    try {
      final companies = await CompanyHelper.getUserCompanies();
      if (companies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_companies_found'.tr()),
              backgroundColor: Colors.red,
            ),
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

      await _initialize();
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initialize() async {
    await _loadFromCache();
    if (mounted) setState(() => _isLoading = false);
    _syncFromFirestoreInBackground();
  }

  // ─── تحميل من الكاش ──────────────────────────────────────────────
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _companyId = _selectedCompanyId;
      if (_companyId != null) {
        _cashAccountId = prefs.getString('${_keyCashAccountId}_$_companyId');
        final balanceStr = prefs.getString('${_keyCashBalance}_$_companyId');
        if (balanceStr != null) {
          _cashBalance = double.parse(balanceStr);
        }

        final transactionsJson = prefs.getString('${_keyCashTransactions}_$_companyId');
        if (transactionsJson != null) {
          final List<dynamic> decoded = json.decode(transactionsJson);
          _recentTransactions.clear();
          _recentTransactions.addAll(decoded.map((item) {
            return {
              'description': item['description'] ?? '',
              'amount': (item['amount'] as num).toDouble(),
              'date': DateTime.parse(item['date']),
              'referenceId': item['referenceId'] ?? '',
              'referenceType': item['referenceType'] ?? '',
            };
          }).toList());
          safeDebugPrint('📦 Loaded ${_recentTransactions.length} transactions from cache');
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Cache load error: $e');
    }
  }

  // ─── حفظ في الكاش ──────────────────────────────────────────────────
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_companyId != null) {
        await prefs.setString('${_keyCashAccountId}_$_companyId', _cashAccountId ?? '');
        await prefs.setString('${_keyCashBalance}_$_companyId', _cashBalance.toString());

        final transactionsJson = _recentTransactions.map((txn) {
          return {
            'description': txn['description'],
            'amount': txn['amount'],
            'date': (txn['date'] as DateTime).toIso8601String(),
            'referenceId': txn['referenceId'] ?? '',
            'referenceType': txn['referenceType'] ?? '',
          };
        }).toList();
        await prefs.setString(
          '${_keyCashTransactions}_$_companyId',
          json.encode(transactionsJson),
        );
      }

      safeDebugPrint('💾 Cash data saved to cache');
    } catch (e) {
      safeDebugPrint('❌ Error saving cache: $e');
    }
  }

  // ─── مزامنة Firestore ──────────────────────────────────────────────
  Future<void> _syncFromFirestoreInBackground() async {
    if (mounted) setState(() => _isSyncing = true);
    await _fetchFromFirestore();
    if (mounted) setState(() => _isSyncing = false);
  }

  // ─── جلب اسم المورد ──────────────────────────────────────────────
  Future<String> _getSupplierName(String supplierId, String languageCode) async {
    if (_supplierNameCache.containsKey(supplierId)) {
      final names = _supplierNameCache[supplierId]!;
      if (languageCode == 'ar') {
        return names['ar'] ?? names['en'] ?? supplierId;
      } else {
        return names['en'] ?? names['ar'] ?? supplierId;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final nameAr = data['nameAr'] ?? '';
        final nameEn = data['nameEn'] ?? '';

        _supplierNameCache[supplierId] = {
          'ar': nameAr.isNotEmpty ? nameAr : supplierId,
          'en': nameEn.isNotEmpty ? nameEn : supplierId,
        };

        if (languageCode == 'ar') {
          return nameAr.isNotEmpty ? nameAr : nameEn;
        } else {
          return nameEn.isNotEmpty ? nameEn : nameAr;
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Error fetching supplier name: $e');
    }

    return languageCode == 'ar'
        ? '${'supplier_unknown'.tr()} (${supplierId.substring(0, 6)})'
        : '${'supplier_unknown'.tr()} (${supplierId.substring(0, 6)})';
  }

  // ─── جلب البيانات من Firestore ──────────────────────────────────
  Future<void> _fetchFromFirestore() async {
    if (_selectedCompanyId == null) {
      safeDebugPrint('⚠️ No company selected');
      return;
    }

    try {
      final String languageCode = context.locale.languageCode;
      _companyId = _selectedCompanyId;
      final accountingService = AccountingService();

      final cashAccount = await accountingService.getAccountByCode(
        companyId: _companyId!,
        code: '1000',
      );
      if (cashAccount == null) {
        safeDebugPrint('❌ Cash account not found for company: $_companyId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('cash_account_not_found'.tr()),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // لا نرمي خطأ، بل نترك الرصيد صفر ونواصل
        _cashAccountId = null;
        _cashBalance = 0.0;
        _recentTransactions.clear();
        await _saveToCache();
        if (mounted) setState(() {});
        return;
      }

      _cashAccountId = cashAccount.id;

      final allEntriesSnapshot = await FirebaseFirestore.instance
          .collection('journal_entries')
          .where('companyId', isEqualTo: _companyId)
          .orderBy('entryDate', descending: false)
          .get();

      double calculatedBalance = 0.0;
      final List<Map<String, dynamic>> allTransactions = [];

      for (var doc in allEntriesSnapshot.docs) {
        final data = doc.data();
        final lines = data['lines'] as List? ?? [];
        bool isCashLine = false;
        double change = 0.0;

        for (var line in lines) {
          if (line['accountId'] == _cashAccountId) {
            final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
            final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
            change = debit - credit;
            calculatedBalance += change;
            isCashLine = true;
            break;
          }
        }

        if (isCashLine) {
          String description = data['description'] ?? '';
          final referenceType = data['referenceType'] ?? '';

          if (referenceType == 'supplier_payment') {
            final supplierId = data['supplierId'] ?? data['referenceId'] ?? '';
            if (supplierId.isNotEmpty) {
              final supplierName = await _getSupplierName(supplierId, languageCode);
              if (description.contains('{0}')) {
                description = description.replaceFirst('{0}', supplierName);
              } else {
                final prefix = languageCode == 'ar' ? 'دفع للمورد' : 'Payment to supplier';
                description = '$prefix: $supplierName';
              }
            }
          }

          allTransactions.add({
            'description': description,
            'amount': change,
            'date': (data['entryDate'] as Timestamp).toDate(),
            'referenceId': data['referenceId'] ?? data['supplierId'] ?? '',
            'referenceType': referenceType,
          });
        }
      }

      _cashBalance = calculatedBalance;
      _recentTransactions.clear();
      final startIndex = allTransactions.length > 10 ? allTransactions.length - 10 : 0;
      _recentTransactions.addAll(allTransactions.sublist(startIndex).reversed);

      safeDebugPrint('💰 Cash balance: $_cashBalance');
      safeDebugPrint('📊 Transactions: ${_recentTransactions.length}');

      await _saveToCache();
      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('❌ Firestore sync error: $e');
    }
  }

  // ─── إضافة حركة نقدية جديدة ──────────────────────────────────────
  Future<void> _addCashTransaction(String type) async {
    if (_selectedCompanyId == null) {
      _showError('company_not_set'.tr());
      return;
    }
    if (_cashAccountId == null) {
      _showError('cash_account_not_found'.tr());
      return;
    }

    final amountController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'deposit' ? 'cash_deposit'.tr() : 'cash_withdrawal'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'amount'.tr(),
                prefixText: 'EGP ',
              ),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: 'description'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        _showError('invalid_amount'.tr());
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('user_not_logged_in'.tr());

        final accountingService = AccountingService();
        await accountingService.createCashTransactionJournalEntry(
          companyId: _selectedCompanyId!,
          amount: amount,
          type: type,
          description: descController.text.isNotEmpty
              ? descController.text
              : (type == 'deposit' ? 'cash_deposit'.tr() : 'cash_withdrawal'.tr()),
          userId: user.uid,
          entryDate: DateTime.now(),
        );

        safeDebugPrint('✅ Cash transaction saved');
        await _syncFromFirestoreInBackground();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('transaction_saved'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        safeDebugPrint('❌ Error: $e');
        _showError('${'error_saving'.tr()}: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;

    return AppScaffold(
      title: 'cash_management'.tr(),
      actions: [
        // ✅ استخدام دالة مساعدة لاختيار الشركة مع دعم اللغة
        CompanyHelper.buildCompanyDropdown(
          companies: _companies,
          selectedCompanyId: _selectedCompanyId,
          languageCode: languageCode,
          onChanged: (newValue) async {
            if (newValue != null && newValue != _selectedCompanyId) {
              await CompanyHelper.setSelectedCompanyId(newValue);
              setState(() {
                _selectedCompanyId = newValue;
                _isLoading = true;
                _recentTransactions.clear();
                _supplierNameCache.clear();
                _cashAccountId = null;
              });
              await _initialize();
              if (mounted) setState(() => _isLoading = false);
            }
          },
          dropdownColor: Colors.white,
          textColor: Colors.black,
          iconColor: Colors.black,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cashBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _cashBalance >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'cash_balance'.tr(),
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          if (_isSyncing)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${_cashBalance.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _cashBalance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _addCashTransaction('deposit'),
                      icon: const Icon(Icons.arrow_upward),
                      label: Text('deposit'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addCashTransaction('withdrawal'),
                      icon: const Icon(Icons.arrow_downward),
                      label: Text('withdrawal'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _recentTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'no_transactions'.tr(),
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _recentTransactions.length,
                          itemBuilder: (context, index) {
                            final txn = _recentTransactions[index];
                            final amount = txn['amount'] as double;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      amount >= 0 ? Colors.green : Colors.red,
                                  child: Icon(
                                    amount >= 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  txn['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  DateFormat('dd/MM/yyyy hh:mm a')
                                      .format(txn['date']),
                                ),
                                trailing: Text(
                                  '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(2)} EGP',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: amount >= 0 ? Colors.green : Colors.red,
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
}