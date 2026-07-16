// pages/financial/financial_balances_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/models/account.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinancialBalancesPage extends StatefulWidget {
  const FinancialBalancesPage({super.key});

  @override
  State<FinancialBalancesPage> createState() => _FinancialBalancesPageState();
}

class _FinancialBalancesPageState extends State<FinancialBalancesPage> {
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];
  List<Account> _accounts = [];
  bool _isLoading = true;

  static const String _keyAccountsCachePrefix = 'financial_accounts_';

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

      await _loadFromCache();
      if (mounted) setState(() => _isLoading = false);
      _syncFromFirestoreInBackground();
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromCache() async {
    if (_selectedCompanyId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString('$_keyAccountsCachePrefix$_selectedCompanyId');
      if (accountsJson != null) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _accounts = _accountsFromJson(accountsList);
        safeDebugPrint('✅ Loaded ${_accounts.length} accounts from cache');
      }
    } catch (e) {
      safeDebugPrint('⚠️ Cache load error: $e');
    }
  }

  List<Account> _accountsFromJson(List<dynamic> jsonList) {
    return jsonList.map((item) {
      final createdAtStr = item['createdAt'] as String?;
      final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      return Account(
        id: item['id'] ?? '',
        companyId: item['companyId'] ?? '',
        code: item['code'] ?? '',
        nameAr: item['nameAr'] ?? '',
        nameEn: item['nameEn'] ?? '',
        type: AccountType.values.firstWhere(
          (e) => e.name == item['type'],
          orElse: () => AccountType.asset,
        ),
        category: AccountCategory.values.firstWhere(
          (e) => e.name == item['category'],
          orElse: () => AccountCategory.other,
        ),
        isActive: item['isActive'] ?? true,
        balance: (item['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAt,
        parentAccountId: item['parentAccountId'],
      );
    }).toList();
  }

  Future<void> _syncFromFirestoreInBackground() async {
    if (_selectedCompanyId == null) return;
    if (mounted) {
      await _fetchFromFirestore();
    }
    if (mounted) return;
  }

  Future<void> _fetchFromFirestore() async {
    if (_selectedCompanyId == null) return;
    try {
      final accSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('isActive', isEqualTo: true)
          .get();

      final List<Account> loadedAccounts = accSnapshot.docs
          .map((doc) => Account.fromMap(doc.data(), doc.id))
          .toList();

      // حساب الأرصدة من القيود
      final entriesSnapshot = await FirebaseFirestore.instance
          .collection('journal_entries')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .get();

      Map<String, double> calculatedBalances = {};
      for (var doc in entriesSnapshot.docs) {
        final data = doc.data();
        final lines = data['lines'] as List? ?? [];
        for (var line in lines) {
          final accountId = line['accountId'] as String?;
          if (accountId == null) continue;
          final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
          final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
          calculatedBalances[accountId] = (calculatedBalances[accountId] ?? 0.0) + (debit - credit);
        }
      }

      final updatedAccounts = loadedAccounts.map((account) {
        final calculatedBalance = calculatedBalances[account.id] ?? 0.0;
        return account.copyWith(balance: calculatedBalance);
      }).toList();

      // حفظ في الكاش
      await _saveAccountsToCache(_selectedCompanyId!, updatedAccounts);
      if (mounted) {
        setState(() {
          _accounts = updatedAccounts;
        });
      }
      safeDebugPrint('✅ Synced ${_accounts.length} accounts');
    } catch (e) {
      safeDebugPrint('❌ Firestore sync error: $e');
    }
  }

  Future<void> _saveAccountsToCache(String companyId, List<Account> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = accounts.map((account) {
        final map = account.toMap();
        map['createdAt'] = account.createdAt.toIso8601String();
        return map;
      }).toList();
      await prefs.setString('$_keyAccountsCachePrefix$companyId', json.encode(accountsJson));
    } catch (e) {
      safeDebugPrint('❌ Error caching accounts: $e');
    }
  }

  Future<void> _onCompanyChanged(String? newCompanyId) async {
    if (newCompanyId == null || newCompanyId == _selectedCompanyId) return;
    await CompanyHelper.setSelectedCompanyId(newCompanyId);
    setState(() {
      _selectedCompanyId = newCompanyId;
      _isLoading = true;
      _accounts.clear();
    });
    await _loadFromCache();
    await _syncFromFirestoreInBackground();
    if (mounted) setState(() => _isLoading = false);
  }

  String _getAccountTypeTranslation(AccountType type) {
    switch (type) {
      case AccountType.asset: return 'account_type_asset'.tr();
      case AccountType.liability: return 'account_type_liability'.tr();
      case AccountType.equity: return 'account_type_equity'.tr();
      case AccountType.revenue: return 'account_type_revenue'.tr();
      case AccountType.expense: return 'account_type_expense'.tr();
    }
  }

  IconData _getIconForAccount(AccountCategory category) {
    switch (category) {
      case AccountCategory.cash: return Icons.money;
      case AccountCategory.bank: return Icons.account_balance;
      case AccountCategory.accountsPayable: return Icons.people;
      case AccountCategory.inventory: return Icons.inventory;
      case AccountCategory.purchases: return Icons.shopping_cart;
      case AccountCategory.sales: return Icons.attach_money;
      default: return Icons.account_balance_wallet;
    }
  }

  Color _getColorForAccount(AccountType type) {
    switch (type) {
      case AccountType.asset: return Colors.green;
      case AccountType.liability: return Colors.orange;
      case AccountType.equity: return Colors.purple;
      case AccountType.revenue: return Colors.blue;
      case AccountType.expense: return Colors.red;
    }
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
      title: 'financial_balances'.tr(),
      actions: actions,
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncFromFirestoreInBackground();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _companies.isEmpty ? 'no_companies_found'.tr() : 'no_accounts_found'.tr(),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getColorForAccount(account.type).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getIconForAccount(account.category),
                              color: _getColorForAccount(account.type),
                            ),
                          ),
                          title: Text(
                            isArabic ? account.nameAr : (account.nameEn.isNotEmpty ? account.nameEn : account.nameAr),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${'account_code'.tr()}: ${account.code} | ${_getAccountTypeTranslation(account.type)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                account.balance.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: account.balance >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                              const Text('EGP', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}