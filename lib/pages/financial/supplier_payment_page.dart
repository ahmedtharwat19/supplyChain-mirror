// pages/financial/supplier_payment_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/models/account.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/accounting_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupplierPaymentPage extends StatefulWidget {
  const SupplierPaymentPage({super.key});

  @override
  State<SupplierPaymentPage> createState() => _SupplierPaymentPageState();
}

class _SupplierPaymentPageState extends State<SupplierPaymentPage> {
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];
  List<Supplier> _suppliers = [];
  List<Account> _bankAccounts = [];
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final supplierSnapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where('userId', isEqualTo: user.uid)
          .where('companyId', isEqualTo: _selectedCompanyId)
          .get();
      _suppliers = supplierSnapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();

      final bankSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('category', isEqualTo: 'bank')
          .where('isActive', isEqualTo: true)
          .get();
      _bankAccounts = bankSnapshot.docs
          .map((doc) => Account.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      safeDebugPrint('Error loading payment data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePayment() async {
    Supplier? selectedSupplier;
    Account? selectedBank;
    String? paymentMethod = 'bank';
    final amountController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('supplier_payment'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Supplier>(
                    initialValue: selectedSupplier,
                    decoration: InputDecoration(labelText: 'supplier'.tr()),
                    items: _suppliers.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(context.locale.languageCode == 'ar' ? s.nameAr : s.nameEn),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedSupplier = value),
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
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('cash')),
                      DropdownMenuItem(value: 'bank', child: Text('bank')),
                    ],
                    onChanged: (value) => setStateDialog(() => paymentMethod = value),
                  ),
                  if (paymentMethod == 'bank')
                    _bankAccounts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('no_bank_accounts'.tr(), style: TextStyle(color: Colors.orange.shade700)),
                          )
                        : DropdownButtonFormField<Account>(
                            initialValue: selectedBank,
                            decoration: InputDecoration(labelText: 'bank_account'.tr()),
                            items: _bankAccounts.map((b) {
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
                child: Text('pay'.tr()),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      // ✅ التحقق من null بشكل صحيح
      if (selectedSupplier == null || amount == null || amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('invalid_data'.tr()), backgroundColor: Colors.red),
          );
        }
        return;
      }
      if (paymentMethod == 'bank' && selectedBank == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('select_bank'.tr()), backgroundColor: Colors.red),
          );
        }
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        final accountingService = AccountingService();
        // ✅ استخدام selectedSupplier! لأننا تحققنا من أنه ليس null
        await accountingService.createSupplierPaymentJournalEntry(
          companyId: _selectedCompanyId!,
          supplierId: selectedSupplier!.id!, // الآن آمن
          amount: amount,
          paymentMethod: paymentMethod!,
          bankAccountId: selectedBank?.id,
          userId: user!.uid,
          entryDate: DateTime.now(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('payment_saved'.tr())),
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
      _suppliers.clear();
      _bankAccounts.clear();
    });
    await _loadData();
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
      title: 'supplier_payment'.tr(),
      actions: actions,
      floatingActionButton: FloatingActionButton(
        onPressed: _makePayment,
        tooltip: 'pay_supplier'.tr(),
        child: const Icon(Icons.payment),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(child: Text('no_suppliers'.tr()))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(context.locale.languageCode == 'ar' ? supplier.nameAr : supplier.nameEn),
                        subtitle: Text(supplier.phone),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  },
                ),
    );
  }
}