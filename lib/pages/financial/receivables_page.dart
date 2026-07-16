// pages/financial/receivables_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/models/account.dart';
import 'package:puresip_purchasing/services/accounting_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReceivablesPage extends StatefulWidget {
  const ReceivablesPage({super.key});

  @override
  State<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends State<ReceivablesPage> {
  String? _companyId;
  List<Account> _bankAccounts = [];
  double _totalReceivables = 0.0;
  bool _isLoading = true;

  // متغيرات اختيار الشركة
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompaniesAndData();
  }

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

      await _loadData();
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (_selectedCompanyId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _companyId = _selectedCompanyId;
      final accountingService = AccountingService();

      final receivableAccount = await accountingService.getAccountByCode(
        companyId: _companyId!,
        code: '3000',
      );

      if (receivableAccount != null) {
        final entriesSnapshot = await FirebaseFirestore.instance
            .collection('journal_entries')
            .where('companyId', isEqualTo: _companyId)
            .get();

        double balance = 0.0;
        for (var doc in entriesSnapshot.docs) {
          final data = doc.data();
          final lines = data['lines'] as List? ?? [];
          for (var line in lines) {
            if (line['accountId'] == receivableAccount.id) {
              final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
              final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
              balance += debit - credit;
            }
          }
        }
        _totalReceivables = balance;
      }

      // جلب حسابات البنوك النشطة
      final bankSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('companyId', isEqualTo: _companyId)
          .where('category', isEqualTo: 'bank')
          .where('isActive', isEqualTo: true)
          .get();

      _bankAccounts = bankSnapshot.docs
          .map((doc) => Account.fromMap(doc.data(), doc.id))
          .where((account) => account.id.isNotEmpty) // تجنب أي بيانات فارغة
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('❌ Error loading receivables: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addReceipt() async {
    final customerController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    Account? selectedBank;
    String? paymentMethod = 'bank';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('customer_receipt'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: customerController,
                    decoration: InputDecoration(labelText: 'customer_name'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'amount'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: 'description'.tr()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: InputDecoration(labelText: 'payment_method'.tr()),
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text('cash'.tr())),
                      DropdownMenuItem(value: 'bank', child: Text('bank'.tr())),
                    ],
                    onChanged: (value) => setStateDialog(() => paymentMethod = value),
                  ),
                  if (paymentMethod == 'bank')
                    // ✅ التحقق من وجود حسابات بنكية قبل العرض
                    _bankAccounts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'no_bank_accounts'.tr(),
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          )
                        : DropdownButtonFormField<Account>(
                            initialValue: selectedBank,
                            decoration: InputDecoration(labelText: 'bank_account'.tr()),
                            items: _bankAccounts.map((b) {
                              // ✅ تجنب null في الأسماء
                              final name = context.locale.languageCode == 'ar'
                                  ? (b.nameAr.isNotEmpty ? b.nameAr : b.nameEn)
                                  : (b.nameEn.isNotEmpty ? b.nameEn : b.nameAr);
                              return DropdownMenuItem(
                                value: b,
                                child: Text(name.isNotEmpty ? name : 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (value) => setStateDialog(() => selectedBank = value),
                          ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('save'.tr()),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0 || customerController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('invalid_data'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (paymentMethod == 'bank' && selectedBank == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('select_bank'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        final accountingService = AccountingService();

        final description = descController.text.isNotEmpty
            ? descController.text
            : 'customer_receipt_default'.tr();

        await accountingService.createReceivableJournalEntry(
          companyId: _companyId!,
          customerId: customerController.text,
          amount: amount,
          paymentMethod: paymentMethod!,
          bankAccountId: selectedBank?.id,
          description: description,
          userId: user!.uid,
          entryDate: DateTime.now(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('receipt_saved'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          await _loadData();
        }
      } catch (e) {
        safeDebugPrint('❌ Error saving receipt: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;

    return AppScaffold(
      title: 'receivables'.tr(),
      actions: [
        // ✅ استخدام دالة مساعدة لاختيار الشركة (مع دعم اللغة)
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
              });
              await _loadData();
              if (mounted) setState(() => _isLoading = false);
            }
          },
          dropdownColor: Colors.white,
          textColor: Colors.black,
          iconColor: Colors.black,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _addReceipt,
        tooltip: 'add_receipt'.tr(),
        child: const Icon(Icons.receipt),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'total_receivables'.tr(),
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '${_totalReceivables.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _totalReceivables >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('no_transactions'.tr()),
                  ),
                ),
              ],
            ),
    );
  }
}