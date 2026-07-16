// pages/financial/bank_accounts_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/models/account.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankAccountsPage extends StatefulWidget {
  const BankAccountsPage({super.key});

  @override
  State<BankAccountsPage> createState() => _BankAccountsPageState();
}

class _BankAccountsPageState extends State<BankAccountsPage> {
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];
  List<Account> _bankAccounts = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;

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
            SnackBar(content: Text('no_companies_found'.tr()), backgroundColor: Colors.red),
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
      final snapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('category', isEqualTo: 'bank')
          .where('isActive', isEqualTo: true)
          .get();

      _bankAccounts = snapshot.docs
          .map((doc) => Account.fromMap(doc.data(), doc.id))
          .toList();

      await _calculateBalances();
    } catch (e) {
      safeDebugPrint('Error loading banks: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateBalances() async {
    if (_selectedCompanyId == null || _bankAccounts.isEmpty) return;

    final entriesSnapshot = await FirebaseFirestore.instance
        .collection('journal_entries')
        .where('companyId', isEqualTo: _selectedCompanyId)
        .get();

    Map<String, double> balances = {};
    for (var account in _bankAccounts) {
      balances[account.id] = 0.0;
    }

    for (var doc in entriesSnapshot.docs) {
      final data = doc.data();
      final lines = data['lines'] as List? ?? [];
      for (var line in lines) {
        final accountId = line['accountId'] as String?;
        if (accountId == null || !balances.containsKey(accountId)) continue;
        final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
        balances[accountId] = (balances[accountId] ?? 0.0) + (debit - credit);
      }
    }

    if (mounted) setState(() { _balances = balances; });
  }

  Future<void> _addBankAccount() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final isArabicBeforeGap = context.locale.languageCode == 'ar';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('add_bank_account'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'bank_name'.tr()),
            ),
            TextField(
              controller: codeController,
              decoration: InputDecoration(labelText: 'account_code'.tr()),
              keyboardType: TextInputType.number,
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
            child: Text('add'.tr()),
          ),
        ],
      ),
    );

    if (result == true && _selectedCompanyId != null) {
      final user = FirebaseAuth.instance.currentUser;
      final code = codeController.text.isNotEmpty ? codeController.text : '2100';
      final name = nameController.text;

      final account = Account(
        id: '',
        companyId: _selectedCompanyId!,
        code: code,
        nameAr: isArabicBeforeGap ? name : '',
        nameEn: isArabicBeforeGap ? '' : name,
        type: AccountType.asset,
        category: AccountCategory.bank,
        createdAt: DateTime.now(),
        balance: 0.0,
      );

      try {
        await FirebaseFirestore.instance
            .collection('accounts')
            .add({ ...account.toMap(), 'createdBy': user?.uid ?? '' });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('bank_added'.tr())),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error'.tr()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _onCompanyChanged(String? newCompanyId) async {
    if (newCompanyId == null || newCompanyId == _selectedCompanyId) return;
    await CompanyHelper.setSelectedCompanyId(newCompanyId);
    setState(() {
      _selectedCompanyId = newCompanyId;
      _isLoading = true;
      _bankAccounts.clear();
      _balances.clear();
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
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
      title: 'bank_accounts'.tr(),
      actions: actions,
      floatingActionButton: FloatingActionButton(
        onPressed: _addBankAccount,
        tooltip: 'add_bank_account'.tr(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bankAccounts.isEmpty
              ? Center(child: Text('no_bank_accounts'.tr()))
              : ListView.builder(
                  itemCount: _bankAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _bankAccounts[index];
                    final balance = _balances[account.id] ?? 0.0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          isArabic ? account.nameAr : account.nameEn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${'account_code'.tr()}: ${account.code}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${balance.toStringAsFixed(2)} EGP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            Text('balance'.tr(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}