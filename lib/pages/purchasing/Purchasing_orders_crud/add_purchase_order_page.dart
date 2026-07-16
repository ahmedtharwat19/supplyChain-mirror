/* /* import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
//import 'package:puresip_purchasing/services/user_terms_service.dart';
import '../../../services/firestore_service.dart';
import 'item_selection_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
 // final UserTermsService _termsService = UserTermsService(); // يستخدم لاحقاً

  // ==================== بيانات أساسية ====================
  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  // ==================== ضريبة الخصم ====================
  double _withholdingTaxAmount = 0.0;
  bool _supplierSubjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  // ==================== شروط الدفع والتسليم ====================
  List<UserPaymentTerm> _userPaymentTerms = [];
  List<UserDeliveryTerm> _userDeliveryTerms = [];
  String? _selectedPaymentTermId;
  String? _selectedDeliveryTermId;

  // ==================== العناصر الإضافية ====================
  List<AdditionalItem> _additionalConditions = [];
  List<AdditionalItem> _additionalDocuments = [];
  List<AdditionalItem> _additionalNotes = [];
  
  List<String> _selectedConditionsIds = [];
  List<String> _selectedDocumentsIds = [];
  List<String> _selectedNotesIds = [];

  bool _isLoadingAdditional = true;
  bool _isLoadingTerms = true;

  bool _showCompanySelector = true;
  bool _showFactorySelector = true;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadAllData();
  }

  // ==================== تحميل كل البيانات بشكل متسلسل ====================
  Future<void> _loadAllData() async {
    await _loadInitialData();      // الشركات، الموردين، الأصناف
    await _loadAdditionalItems();   // العناصر الإضافية
    await _loadUserTerms();         // شروط الدفع والتسليم
  }

  // ==================== تحميل البيانات الأساسية ====================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('user_data_not_found'.tr());
        return;
      }

      final userData = userDoc.data()!;
      final companyIds = (userData['companyIds'] as List?)?.cast<String>() ?? [];
      if (companyIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('no_companies_found'.tr());
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserCompanies(companyIds),
        _firestoreService.getUserVendors(
          user.uid,
          (userData['supplierIds'] as List?)?.cast<String>() ?? [],
        ),
        _firestoreService.getUserItems(user.uid),
      ]);

      final companies = results[0] as List<Company>;
      final suppliers = results[1] as List<Supplier>;
      final items = results[2] as List<Item>;

      final String? firstCompanyId = companies.isNotEmpty ? companies.first.id : null;

      if (mounted) {
        setState(() {
          _companies = companies;
          _suppliers = suppliers;
          _allItems = items;

          if (companies.isNotEmpty && (_selectedCompanyId == null || _selectedCompanyId!.isEmpty)) {
            _selectedCompanyId = firstCompanyId;
            _showCompanySelector = companies.length > 1;
          } else if (companies.length == 1) {
            _showCompanySelector = false;
          } else {
            _showCompanySelector = true;
          }
          _isLoading = false;
        });
      }

      if (firstCompanyId != null && firstCompanyId.isNotEmpty) {
        await _loadFactoriesForCompany(firstCompanyId);
      } else {
        if (mounted) {
          setState(() {
            _factories = [];
            _showFactorySelector = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar('error_loading_data'.tr());
    }
  }

  // ==================== تحميل المصانع بناءً على الشركة ====================
  Future<void> _loadFactoriesForCompany(String companyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
      return;
    }

    try {
      final factories = await _firestoreService.getFactoriesByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _factories = factories;
          if (_factories.isNotEmpty && _selectedFactoryId == null) {
            _selectedFactoryId = _factories.first.id;
            _showFactorySelector = _factories.length > 1;
          } else if (_factories.length == 1) {
            _showFactorySelector = false;
          } else {
            _showFactorySelector = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
    }
  }

  // ==================== تحميل العناصر الإضافية ====================
  Future<void> _loadAdditionalItems() async {
    if (!mounted) return;
    setState(() => _isLoadingAdditional = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAdditional = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('additional_items')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs.map((doc) => AdditionalItem.fromMap(doc.data(), doc.id)).toList();

      if (mounted) {
        setState(() {
          _additionalConditions = allItems.where((i) => i.type == AdditionalItemType.condition).toList();
          _additionalDocuments = allItems.where((i) => i.type == AdditionalItemType.document).toList();
          _additionalNotes = allItems.where((i) => i.type == AdditionalItemType.note).toList();
          _isLoadingAdditional = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAdditional = false);
    }
  }

  // ==================== تحميل شروط الدفع والتسليم ====================
  Future<void> _loadUserTerms() async {
    if (!mounted) return;
    setState(() => _isLoadingTerms = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTerms = false);
      return;
    }

    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final deliverySnapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final paymentTerms = paymentSnapshot.docs
          .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
          .toList();
      final deliveryTerms = deliverySnapshot.docs
          .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _userPaymentTerms = paymentTerms;
          _userDeliveryTerms = deliveryTerms;
          if (_userPaymentTerms.isNotEmpty && _selectedPaymentTermId == null) {
            _selectedPaymentTermId = _userPaymentTerms.first.id;
          }
          if (_userDeliveryTerms.isNotEmpty && _selectedDeliveryTermId == null) {
            _selectedDeliveryTermId = _userDeliveryTerms.first.id;
          }
          _isLoadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  // ==================== حساب القيم ====================
  double _calculateSubtotal() => _items.fold(0.0, (t, i) => t + i.totalPrice);
  double _calculateTotalTax() => _items.fold(0.0, (t, i) => t + i.taxAmount);
  double _calculateNetPayable() => (_calculateSubtotal() + _calculateTotalTax()) - _withholdingTaxAmount;

  void _calculateWithholdingTax() {
    if (_selectedSupplierId != null) {
      final selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(
          id: '', nameAr: '', nameEn: '', phone: '', email: '', address: '',
          userId: '', createdAt: Timestamp.now(),
          subjectToWithholding: false, withholdingTaxRate: 1.0,
        ),
      );
      setState(() {
        _supplierSubjectToWithholding = selectedSupplier.subjectToWithholding;
        _withholdingTaxRate = selectedSupplier.withholdingTaxRate;
        _withholdingTaxAmount = _supplierSubjectToWithholding ? _calculateSubtotal() * (_withholdingTaxRate / 100) : 0.0;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _isLoadingTerms) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _submitOrder)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('basic_info'.tr()),
              const SizedBox(height: 8),
              _buildCompanyDropdown(),
              const SizedBox(height: 12),
              _buildFactoryDropdown(),
              const SizedBox(height: 12),
              _buildSupplierDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),

              _buildSectionTitle('taxes_discounts'.tr()),
              const SizedBox(height: 8),
              _buildTaxRateField(),
              const SizedBox(height: 12),
              _buildWithholdingTaxInfo(),
              const SizedBox(height: 12),

              _buildSectionTitle('payment_delivery_terms'.tr()),
              const SizedBox(height: 8),
              _buildPaymentTermsDropdown(),
              const SizedBox(height: 12),
              _buildDeliveryTermsDropdown(),
              const SizedBox(height: 12),

              _buildSectionTitle('additional_requirements'.tr()),
              const SizedBox(height: 8),
              _buildMultiSelectSection(
                title: 'conditions'.tr(),
                items: _additionalConditions,
                selectedIds: _selectedConditionsIds,
                onChanged: (list) => setState(() => _selectedConditionsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'required_documents'.tr(),
                items: _additionalDocuments,
                selectedIds: _selectedDocumentsIds,
                onChanged: (list) => setState(() => _selectedDocumentsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'notes'.tr(),
                items: _additionalNotes,
                selectedIds: _selectedNotesIds,
                onChanged: (list) => setState(() => _selectedNotesIds = list),
                isLoading: _isLoadingAdditional,
              ),

              _buildSectionTitle('items'.tr()),
              const SizedBox(height: 8),
              _buildItemsList(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              ),

              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              // ✅ تم تصحيح SwitchListTile هنا
              SwitchListTile(
                title: Text('delivered'.tr()),
                value: _isDelivered,
                onChanged: (val) => setState(() => _isDelivered = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== دوال بناء الأقسام ====================
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Widget _buildCompanyDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (!_showCompanySelector && _companies.isNotEmpty) {
      final selectedCompany = _companies.firstWhere(
        (c) => c.id == _selectedCompanyId,
        orElse: () => _companies.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('company'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(isArabic ? selectedCompany.nameAr : (selectedCompany.nameEn.isNotEmpty ? selectedCompany.nameEn : selectedCompany.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return DropdownButtonFormField<String>(
      initialValue: _companies.any((c) => c.id == _selectedCompanyId) ? _selectedCompanyId : null,
      decoration: InputDecoration(labelText: 'company'.tr(), border: const OutlineInputBorder()),
      items: _companies.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Text(isArabic ? c.nameAr : (c.nameEn.isNotEmpty ? c.nameEn : c.nameAr)),
        );
      }).toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
        });
        await _loadFactoriesForCompany(val);
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    if (_selectedCompanyId == null) return const SizedBox();
    final isArabic = context.locale.languageCode == 'ar';
    
    if (!_showFactorySelector && _factories.isNotEmpty) {
      final selectedFactory = _factories.firstWhere(
        (f) => f.id == _selectedFactoryId,
        orElse: () => _factories.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('factory'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(isArabic ? selectedFactory.nameAr : (selectedFactory.nameEn.isNotEmpty ? selectedFactory.nameEn : selectedFactory.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_factories.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_factories_found'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(labelText: 'factory'.tr(), border: const OutlineInputBorder()),
      items: _factories.map((f) {
        return DropdownMenuItem(
          value: f.id,
          child: Text(isArabic ? f.nameAr : (f.nameEn.isNotEmpty ? f.nameEn : f.nameAr)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(labelText: 'supplier'.tr(), border: const OutlineInputBorder()),
      items: _suppliers.map((v) {
        return DropdownMenuItem(
          value: v.id,
          child: Text(isArabic ? v.nameAr : (v.nameEn.isNotEmpty ? v.nameEn : v.nameAr)),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedSupplierId = val);
        _calculateWithholdingTax();
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _orderDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null && mounted) setState(() => _orderDate = d);
        },
      ),
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: 'tax_rate_percent'.tr(), suffixText: '%', border: const OutlineInputBorder()),
      onChanged: (v) {
        final rate = double.tryParse(v) ?? _taxRate;
        setState(() => _taxRate = rate);
        for (int i = 0; i < _items.length; i++) {
          _items[i] = _items[i].updateTaxStatus(_items[i].isTaxable, _items[i].isTaxable ? rate : 0);
        }
        _calculateWithholdingTax();
      },
    );
  }

  Widget _buildWithholdingTaxInfo() {
    if (_selectedSupplierId == null) return const SizedBox();
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '', nameAr: '', nameEn: '', phone: '', email: '', address: '',
        userId: '', createdAt: Timestamp.now(),
        subjectToWithholding: false, withholdingTaxRate: 1.0,
      ),
    );
    if (!selectedSupplier.subjectToWithholding) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'withholding_tax_rate_info'.tr(args: [selectedSupplier.withholdingTaxRate.toString()]),
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userPaymentTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_payment_terms'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('payment_terms'.tr()),
            value: _selectedPaymentTermId,
            items: _userPaymentTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic), style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPaymentTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userDeliveryTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_delivery_terms'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('delivery_terms'.tr()),
            value: _selectedDeliveryTermId,
            items: _userDeliveryTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic), style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDeliveryTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<AdditionalItem> items,
    required List<String> selectedIds,
    required Function(List<String>) onChanged,
    required bool isLoading,
  }) {
    final isArabic = context.locale.languageCode == 'ar';
    if (isLoading) {
      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    }
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_items_available'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedIds.contains(item.id);
                return FilterChip(
                  label: Text(item.getTitle(isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newList = List.from(selectedIds);
                    if (selected) {
                      newList.add(item.id);
                    } else {
                      newList.remove(item.id);
                    }
                    onChanged(newList);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('no_items_added'.tr(), style: const TextStyle(color: Colors.grey))),
        ),
      );
    }
    final isArabic = context.locale.languageCode == 'ar';
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          key: ValueKey(item.itemId),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(isArabic ? item.nameAr : (item.nameEn.isNotEmpty ? item.nameEn : item.nameAr), style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        decoration: const InputDecoration(labelText: 'quantity', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? item.quantity;
                          if (newQty != item.quantity) {
                            setState(() {
                              _items[index] = item.updateQuantity(newQty);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        decoration: const InputDecoration(labelText: 'unit_price', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), prefixText: 'EGP '),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newPrice = double.tryParse(v) ?? item.unitPrice;
                          if (newPrice != item.unitPrice) {
                            setState(() {
                              _items[index] = item.updateUnitPrice(newPrice);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('is_taxable'),
                        value: item.isTaxable,
                        onChanged: (val) {
                          setState(() {
                            _items[index] = item.updateTaxStatus(val, val ? _taxRate : 0);
                            _calculateWithholdingTax();
                          });
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('total:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    if (_items.isEmpty) return const SizedBox();
    final subtotal = _calculateSubtotal();
    final totalTax = _calculateTotalTax();
    final beforeWithholding = subtotal + totalTax;
    final netPayable = _calculateNetPayable();
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('order_summary'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            if (_supplierSubjectToWithholding && _withholdingTaxAmount > 0)
              _buildSummaryRow('withholding_tax'.tr(), -_withholdingTaxAmount, valueColor: Colors.red),
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false, Color? valueColor}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text('$sign${displayValue.toStringAsFixed(2)} ${'currency'.tr()}', style: TextStyle(color: valueColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

/*   Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(allItems: _allItems, preSelectedItems: _items.map((i) => i.itemId).toList()),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
      }
    });
    _calculateWithholdingTax();
  }
 */
 
 Future<void> _showItemSelectionDialog() async {
  final selected = await showDialog<List<Item>>(
    context: context,
    builder: (_) => ItemSelectionDialog(
      allItems: _allItems,
      preSelectedItems: _items.map((i) => i.itemId).toList(),
      isArabic: context.locale.languageCode == 'ar', // ✅ تمرير اللغة
    ),
  );
  if (selected == null || selected.isEmpty) return;
  setState(() {
    for (var i in selected) {
      if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
    }
  });
  _calculateWithholdingTax();
}
 
  bool _validateForm() {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return false;
    }
    if (_selectedSupplierId == null) {
      _showErrorSnackbar('supplier_not_selected'.tr());
      return false;
    }
    if (_items.isEmpty) {
      _showErrorSnackbar('no_items_selected'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return;
    }
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber = await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';

      final subtotal = _calculateSubtotal();
      final totalTax = _calculateTotalTax();
      final beforeWithholding = subtotal + totalTax;
      final netPayable = _calculateNetPayable();

      final selectedPaymentTerm = _userPaymentTerms.firstWhere(
        (t) => t.id == _selectedPaymentTermId,
        orElse: () => _userPaymentTerms.first,
      );
      final selectedDeliveryTerm = _userDeliveryTerms.firstWhere(
        (t) => t.id == _selectedDeliveryTermId,
        orElse: () => _userDeliveryTerms.first,
      );

      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: subtotal,
        totalTax: totalTax,
        totalAmountAfterTax: beforeWithholding,
        isDelivered: _isDelivered,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        paymentTermCode: selectedPaymentTerm.code,
        deliveryTermCode: selectedDeliveryTerm.code,
        conditionsIds: _selectedConditionsIds,
        documentsIds: _selectedDocumentsIds,
        notesIds: _selectedNotesIds,
      );

      await _firestoreService.createPurchaseOrder(order);
      
      if (_isDelivered && _selectedFactoryId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestoreService.processStockDelivery(
            companyId: _selectedCompanyId!,
            factoryId: _selectedFactoryId!,
            orderId: orderId,
            userId: user.uid,
            items: _items,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
} */

// pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/currency_service.dart';
import 'package:puresip_purchasing/services/user_currency_service.dart';
import '../../../services/firestore_service.dart';
import 'item_selection_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final UserCurrencyService _userCurrencyService = UserCurrencyService();

  // ==================== بيانات أساسية ====================
  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  // ==================== ضريبة الخصم ====================
  double _withholdingTaxAmount = 0.0;
  bool _supplierSubjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  // ==================== شروط الدفع والتسليم ====================
  List<UserPaymentTerm> _userPaymentTerms = [];
  List<UserDeliveryTerm> _userDeliveryTerms = [];
  String? _selectedPaymentTermId;
  String? _selectedDeliveryTermId;

  // ==================== العناصر الإضافية ====================
  List<AdditionalItem> _additionalConditions = [];
  List<AdditionalItem> _additionalDocuments = [];
  List<AdditionalItem> _additionalNotes = [];

  List<String> _selectedConditionsIds = [];
  List<String> _selectedDocumentsIds = [];
  List<String> _selectedNotesIds = [];

  bool _isLoadingAdditional = true;
  bool _isLoadingTerms = true;

  bool _showCompanySelector = true;
  bool _showFactorySelector = true;

  // ==================== متغيرات العملة ====================
  String _baseCurrency = 'EGP';
  String? _selectedCurrencyCode = 'EGP';
  double _exchangeRate = 1.0;
  bool _isLoadingCurrency = true;

  final List<String> _currencies = CurrencyService.getAvailableCurrencies();

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadAllData();
    _loadUserBaseCurrency();
  }

  // ==================== تحميل عملة المستخدم الأساسية ====================
  Future<void> _loadUserBaseCurrency() async {
    setState(() => _isLoadingCurrency = true);
    try {
      _baseCurrency = await _userCurrencyService.getUserBaseCurrency();
      _selectedCurrencyCode = _baseCurrency;
      _exchangeRate = 1.0;
      safeDebugPrint('✅ User base currency: $_baseCurrency');
    } catch (e) {
      safeDebugPrint('Error loading base currency: $e');
    } finally {
      setState(() => _isLoadingCurrency = false);
    }
  }

  // ==================== تحميل كل البيانات ====================
  Future<void> _loadAllData() async {
    await _loadInitialData();
    await _loadAdditionalItems();
    await _loadUserTerms();
  }

  // ==================== تحميل البيانات الأساسية ====================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('user_data_not_found'.tr());
        return;
      }

      final userData = userDoc.data()!;
      final companyIds =
          (userData['companyIds'] as List?)?.cast<String>() ?? [];
      if (companyIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('no_companies_found'.tr());
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserCompanies(companyIds),
        _firestoreService.getUserVendors(
          user.uid,
          (userData['supplierIds'] as List?)?.cast<String>() ?? [],
        ),
        _firestoreService.getUserItems(user.uid),
      ]);

      final companies = results[0] as List<Company>;
      final suppliers = results[1] as List<Supplier>;
      final items = results[2] as List<Item>;

      final String? firstCompanyId =
          companies.isNotEmpty ? companies.first.id : null;

      if (mounted) {
        setState(() {
          _companies = companies;
          _suppliers = suppliers;
          _allItems = items;

          if (companies.isNotEmpty &&
              (_selectedCompanyId == null || _selectedCompanyId!.isEmpty)) {
            _selectedCompanyId = firstCompanyId;
            _showCompanySelector = companies.length > 1;
          } else if (companies.length == 1) {
            _showCompanySelector = false;
          } else {
            _showCompanySelector = true;
          }
          _isLoading = false;
        });
      }

      if (firstCompanyId != null && firstCompanyId.isNotEmpty) {
        await _loadFactoriesForCompany(firstCompanyId);
      } else {
        if (mounted) {
          setState(() {
            _factories = [];
            _showFactorySelector = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar('error_loading_data'.tr());
    }
  }

  // ==================== تحميل المصانع ====================
  Future<void> _loadFactoriesForCompany(String companyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
      return;
    }

    try {
      final factories =
          await _firestoreService.getFactoriesByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _factories = factories;
          if (_factories.isNotEmpty && _selectedFactoryId == null) {
            _selectedFactoryId = _factories.first.id;
            _showFactorySelector = _factories.length > 1;
          } else if (_factories.length == 1) {
            _showFactorySelector = false;
          } else {
            _showFactorySelector = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
    }
  }

  // ==================== تحميل العناصر الإضافية ====================
  Future<void> _loadAdditionalItems() async {
    if (!mounted) return;
    setState(() => _isLoadingAdditional = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAdditional = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('additional_items')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs
          .map((doc) => AdditionalItem.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _additionalConditions =
              allItems.where((i) => i.type == AdditionalItemType.condition).toList();
          _additionalDocuments =
              allItems.where((i) => i.type == AdditionalItemType.document).toList();
          _additionalNotes =
              allItems.where((i) => i.type == AdditionalItemType.note).toList();
          _isLoadingAdditional = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAdditional = false);
    }
  }

  // ==================== تحميل شروط الدفع والتسليم ====================
  Future<void> _loadUserTerms() async {
    if (!mounted) return;
    setState(() => _isLoadingTerms = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTerms = false);
      return;
    }

    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final deliverySnapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final paymentTerms = paymentSnapshot.docs
          .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
          .toList();
      final deliveryTerms = deliverySnapshot.docs
          .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _userPaymentTerms = paymentTerms;
          _userDeliveryTerms = deliveryTerms;
          if (_userPaymentTerms.isNotEmpty && _selectedPaymentTermId == null) {
            _selectedPaymentTermId = _userPaymentTerms.first.id;
          }
          if (_userDeliveryTerms.isNotEmpty && _selectedDeliveryTermId == null) {
            _selectedDeliveryTermId = _userDeliveryTerms.first.id;
          }
          _isLoadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  // ==================== حساب القيم ====================
  double _calculateSubtotal() =>
      _items.fold(0.0, (t, i) => t + i.totalPrice);
  double _calculateTotalTax() =>
      _items.fold(0.0, (t, i) => t + i.taxAmount);
  double _calculateNetPayable() =>
      (_calculateSubtotal() + _calculateTotalTax()) - _withholdingTaxAmount;

  void _calculateWithholdingTax() {
    if (_selectedSupplierId != null) {
      final selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(
          id: '',
          nameAr: '',
          nameEn: '',
          phone: '',
          email: '',
          address: '',
          userId: '',
          createdAt: Timestamp.now(),
          subjectToWithholding: false,
          withholdingTaxRate: 1.0,
        ),
      );
      setState(() {
        _supplierSubjectToWithholding = selectedSupplier.subjectToWithholding;
        _withholdingTaxRate = selectedSupplier.withholdingTaxRate;
        _withholdingTaxAmount = _supplierSubjectToWithholding
            ? _calculateSubtotal() * (_withholdingTaxRate / 100)
            : 0.0;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== حساب القيمة بالعملة الأساسية ====================
  double _getAmountInBaseCurrency(double amount) {
    return amount * _exchangeRate;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _isLoadingTerms || _isLoadingCurrency) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('basic_info'.tr()),
              const SizedBox(height: 8),
              _buildCompanyDropdown(),
              const SizedBox(height: 12),
              _buildFactoryDropdown(),
              const SizedBox(height: 12),
              _buildSupplierDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildCurrencySelector(),
              const SizedBox(height: 12),

              _buildSectionTitle('taxes_discounts'.tr()),
              const SizedBox(height: 8),
              _buildTaxRateField(),
              const SizedBox(height: 12),
              _buildWithholdingTaxInfo(),
              const SizedBox(height: 12),

              _buildSectionTitle('payment_delivery_terms'.tr()),
              const SizedBox(height: 8),
              _buildPaymentTermsDropdown(),
              const SizedBox(height: 12),
              _buildDeliveryTermsDropdown(),
              const SizedBox(height: 12),

              _buildSectionTitle('additional_requirements'.tr()),
              const SizedBox(height: 8),
              _buildMultiSelectSection(
                title: 'conditions'.tr(),
                items: _additionalConditions,
                selectedIds: _selectedConditionsIds,
                onChanged: (list) => setState(() => _selectedConditionsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'required_documents'.tr(),
                items: _additionalDocuments,
                selectedIds: _selectedDocumentsIds,
                onChanged: (list) => setState(() => _selectedDocumentsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'notes'.tr(),
                items: _additionalNotes,
                selectedIds: _selectedNotesIds,
                onChanged: (list) => setState(() => _selectedNotesIds = list),
                isLoading: _isLoadingAdditional,
              ),

              _buildSectionTitle('items'.tr()),
              const SizedBox(height: 8),
              _buildItemsList(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),

              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('delivered'.tr()),
                value: _isDelivered,
                onChanged: (val) => setState(() => _isDelivered = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== دوال بناء الأقسام ====================
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (!_showCompanySelector && _companies.isNotEmpty) {
      final selectedCompany = _companies.firstWhere(
        (c) => c.id == _selectedCompanyId,
        orElse: () => _companies.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('company'.tr(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedCompany.nameAr
                          : (selectedCompany.nameEn.isNotEmpty
                              ? selectedCompany.nameEn
                              : selectedCompany.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue:
          _companies.any((c) => c.id == _selectedCompanyId) ? _selectedCompanyId : null,
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _companies.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Text(
            isArabic
                ? c.nameAr
                : (c.nameEn.isNotEmpty ? c.nameEn : c.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
        });
        await _loadFactoriesForCompany(val);
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    if (_selectedCompanyId == null) return const SizedBox();
    final isArabic = context.locale.languageCode == 'ar';

    if (!_showFactorySelector && _factories.isNotEmpty) {
      final selectedFactory = _factories.firstWhere(
        (f) => f.id == _selectedFactoryId,
        orElse: () => _factories.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('factory'.tr(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedFactory.nameAr
                          : (selectedFactory.nameEn.isNotEmpty
                              ? selectedFactory.nameEn
                              : selectedFactory.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_factories.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_factories_found'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _factories.map((f) {
        return DropdownMenuItem(
          value: f.id,
          child: Text(
            isArabic
                ? f.nameAr
                : (f.nameEn.isNotEmpty ? f.nameEn : f.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _suppliers.map((v) {
        return DropdownMenuItem(
          value: v.id,
          child: Text(
            isArabic
                ? v.nameAr
                : (v.nameEn.isNotEmpty ? v.nameEn : v.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedSupplierId = val);
        _calculateWithholdingTax();
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _orderDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null && mounted) setState(() => _orderDate = d);
        },
      ),
    );
  }

  // ==================== اختيار العملة ====================
  Widget _buildCurrencySelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCurrencyCode,
      decoration: InputDecoration(
        labelText: 'currency'.tr(),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
        helperText: 'base_currency'.tr(args: [_baseCurrency]),
        helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      items: _currencies.map<DropdownMenuItem<String>>((code) {
        final symbol = CurrencyService.getSymbol(code);
        final name = CurrencyService.getCurrencyName(code);
        final isBase = code == _baseCurrency;
        return DropdownMenuItem(
          value: code,
          child: Row(
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isBase ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBase ? Colors.green[700] : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name)),
              if (isBase)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'base'.tr(),
                    style: TextStyle(fontSize: 9, color: Colors.green[700]),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCurrencyCode = value);
          _exchangeRate = 1.0;
        }
      },
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final rate = double.tryParse(v) ?? _taxRate;
        setState(() => _taxRate = rate);
        for (int i = 0; i < _items.length; i++) {
          _items[i] = _items[i].updateTaxStatus(
              _items[i].isTaxable, _items[i].isTaxable ? rate : 0);
        }
        _calculateWithholdingTax();
      },
    );
  }

  Widget _buildWithholdingTaxInfo() {
    if (_selectedSupplierId == null) return const SizedBox();
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '',
        nameAr: '',
        nameEn: '',
        phone: '',
        email: '',
        address: '',
        userId: '',
        createdAt: Timestamp.now(),
        subjectToWithholding: false,
        withholdingTaxRate: 1.0,
      ),
    );
    if (!selectedSupplier.subjectToWithholding) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'withholding_tax_rate_info'.tr(
                    args: [selectedSupplier.withholdingTaxRate.toString()]),
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userPaymentTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_payment_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('payment_terms'.tr()),
            value: _selectedPaymentTermId,
            items: _userPaymentTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPaymentTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userDeliveryTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_delivery_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('delivery_terms'.tr()),
            value: _selectedDeliveryTermId,
            items: _userDeliveryTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDeliveryTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<AdditionalItem> items,
    required List<String> selectedIds,
    required Function(List<String>) onChanged,
    required bool isLoading,
  }) {
    final isArabic = context.locale.languageCode == 'ar';
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_items_available'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedIds.contains(item.id);
                return FilterChip(
                  label: Text(item.getTitle(isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newList = List.from(selectedIds);
                    if (selected) {
                      newList.add(item.id);
                    } else {
                      newList.remove(item.id);
                    }
                    onChanged(newList);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('no_items_added'.tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    final isArabic = context.locale.languageCode == 'ar';
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          key: ValueKey(item.itemId),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isArabic
                            ? item.nameAr
                            : (item.nameEn.isNotEmpty ? item.nameEn : item.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        decoration: const InputDecoration(
                          labelText: 'quantity',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? item.quantity;
                          if (newQty != item.quantity) {
                            setState(() {
                              _items[index] = item.updateQuantity(newQty);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        decoration: InputDecoration(
                          labelText: 'unit_price'.tr(),
                          border: const OutlineInputBorder(),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '$_selectedCurrencyCode ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newPrice = double.tryParse(v) ?? item.unitPrice;
                          if (newPrice != item.unitPrice) {
                            setState(() {
                              _items[index] = item.updateUnitPrice(newPrice);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('is_taxable'),
                        value: item.isTaxable,
                        onChanged: (val) {
                          setState(() {
                            _items[index] = item.updateTaxStatus(
                                val, val ? _taxRate : 0);
                            _calculateWithholdingTax();
                          });
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('total:',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${item.totalAfterTaxAmount.toStringAsFixed(2)} $_selectedCurrencyCode',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    if (_items.isEmpty) return const SizedBox();
    final subtotal = _calculateSubtotal();
    final totalTax = _calculateTotalTax();
    final beforeWithholding = subtotal + totalTax;
    final netPayable = _calculateNetPayable();
    final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('order_summary'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            if (_supplierSubjectToWithholding && _withholdingTaxAmount > 0)
              _buildSummaryRow('withholding_tax'.tr(), -_withholdingTaxAmount,
                  valueColor: Colors.red),
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
            if (_selectedCurrencyCode != _baseCurrency) ...[
              const Divider(thickness: 1),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'amount_in_base_currency'.tr(args: [_baseCurrency]),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_baseCurrency ${amountInBaseCurrency.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isTotal = false, Color? valueColor}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            '$sign${displayValue.toStringAsFixed(2)} $_selectedCurrencyCode',
            style: TextStyle(
                color: valueColor,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
        isArabic: context.locale.languageCode == 'ar',
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
      }
    });
    _calculateWithholdingTax();
  }

  bool _validateForm() {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return false;
    }
    if (_selectedSupplierId == null) {
      _showErrorSnackbar('supplier_not_selected'.tr());
      return false;
    }
    if (_items.isEmpty) {
      _showErrorSnackbar('no_items_selected'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return;
    }
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber =
          await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';

      final subtotal = _calculateSubtotal();
      final totalTax = _calculateTotalTax();
      final beforeWithholding = subtotal + totalTax;
      final netPayable = _calculateNetPayable();

      final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

      final selectedPaymentTerm = _userPaymentTerms.firstWhere(
        (t) => t.id == _selectedPaymentTermId,
        orElse: () => _userPaymentTerms.first,
      );
      final selectedDeliveryTerm = _userDeliveryTerms.firstWhere(
        (t) => t.id == _selectedDeliveryTermId,
        orElse: () => _userDeliveryTerms.first,
      );

      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: subtotal,
        totalTax: totalTax,
        totalAmountAfterTax: beforeWithholding,
        isDelivered: _isDelivered,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        paymentTermCode: selectedPaymentTerm.code,
        deliveryTermCode: selectedDeliveryTerm.code,
        conditionsIds: _selectedConditionsIds,
        documentsIds: _selectedDocumentsIds,
        notesIds: _selectedNotesIds,
        currencyCode: _selectedCurrencyCode,
        exchangeRate: _exchangeRate,
        totalAmountInBaseCurrency: amountInBaseCurrency,
      );

      await _firestoreService.createPurchaseOrder(order);

      if (_isDelivered && _selectedFactoryId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestoreService.processStockDelivery(
            companyId: _selectedCompanyId!,
            factoryId: _selectedFactoryId!,
            orderId: orderId,
            userId: user.uid,
            items: _items,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
} */

/* import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
//import 'package:puresip_purchasing/services/user_terms_service.dart';
import '../../../services/firestore_service.dart';
import 'item_selection_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
 // final UserTermsService _termsService = UserTermsService(); // يستخدم لاحقاً

  // ==================== بيانات أساسية ====================
  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  // ==================== ضريبة الخصم ====================
  double _withholdingTaxAmount = 0.0;
  bool _supplierSubjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  // ==================== شروط الدفع والتسليم ====================
  List<UserPaymentTerm> _userPaymentTerms = [];
  List<UserDeliveryTerm> _userDeliveryTerms = [];
  String? _selectedPaymentTermId;
  String? _selectedDeliveryTermId;

  // ==================== العناصر الإضافية ====================
  List<AdditionalItem> _additionalConditions = [];
  List<AdditionalItem> _additionalDocuments = [];
  List<AdditionalItem> _additionalNotes = [];
  
  List<String> _selectedConditionsIds = [];
  List<String> _selectedDocumentsIds = [];
  List<String> _selectedNotesIds = [];

  bool _isLoadingAdditional = true;
  bool _isLoadingTerms = true;

  bool _showCompanySelector = true;
  bool _showFactorySelector = true;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadAllData();
  }

  // ==================== تحميل كل البيانات بشكل متسلسل ====================
  Future<void> _loadAllData() async {
    await _loadInitialData();      // الشركات، الموردين، الأصناف
    await _loadAdditionalItems();   // العناصر الإضافية
    await _loadUserTerms();         // شروط الدفع والتسليم
  }

  // ==================== تحميل البيانات الأساسية ====================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('user_data_not_found'.tr());
        return;
      }

      final userData = userDoc.data()!;
      final companyIds = (userData['companyIds'] as List?)?.cast<String>() ?? [];
      if (companyIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('no_companies_found'.tr());
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserCompanies(companyIds),
        _firestoreService.getUserVendors(
          user.uid,
          (userData['supplierIds'] as List?)?.cast<String>() ?? [],
        ),
        _firestoreService.getUserItems(user.uid),
      ]);

      final companies = results[0] as List<Company>;
      final suppliers = results[1] as List<Supplier>;
      final items = results[2] as List<Item>;

      final String? firstCompanyId = companies.isNotEmpty ? companies.first.id : null;

      if (mounted) {
        setState(() {
          _companies = companies;
          _suppliers = suppliers;
          _allItems = items;

          if (companies.isNotEmpty && (_selectedCompanyId == null || _selectedCompanyId!.isEmpty)) {
            _selectedCompanyId = firstCompanyId;
            _showCompanySelector = companies.length > 1;
          } else if (companies.length == 1) {
            _showCompanySelector = false;
          } else {
            _showCompanySelector = true;
          }
          _isLoading = false;
        });
      }

      if (firstCompanyId != null && firstCompanyId.isNotEmpty) {
        await _loadFactoriesForCompany(firstCompanyId);
      } else {
        if (mounted) {
          setState(() {
            _factories = [];
            _showFactorySelector = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar('error_loading_data'.tr());
    }
  }

  // ==================== تحميل المصانع بناءً على الشركة ====================
  Future<void> _loadFactoriesForCompany(String companyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
      return;
    }

    try {
      final factories = await _firestoreService.getFactoriesByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _factories = factories;
          if (_factories.isNotEmpty && _selectedFactoryId == null) {
            _selectedFactoryId = _factories.first.id;
            _showFactorySelector = _factories.length > 1;
          } else if (_factories.length == 1) {
            _showFactorySelector = false;
          } else {
            _showFactorySelector = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
    }
  }

  // ==================== تحميل العناصر الإضافية ====================
  Future<void> _loadAdditionalItems() async {
    if (!mounted) return;
    setState(() => _isLoadingAdditional = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAdditional = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('additional_items')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs.map((doc) => AdditionalItem.fromMap(doc.data(), doc.id)).toList();

      if (mounted) {
        setState(() {
          _additionalConditions = allItems.where((i) => i.type == AdditionalItemType.condition).toList();
          _additionalDocuments = allItems.where((i) => i.type == AdditionalItemType.document).toList();
          _additionalNotes = allItems.where((i) => i.type == AdditionalItemType.note).toList();
          _isLoadingAdditional = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAdditional = false);
    }
  }

  // ==================== تحميل شروط الدفع والتسليم ====================
  Future<void> _loadUserTerms() async {
    if (!mounted) return;
    setState(() => _isLoadingTerms = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTerms = false);
      return;
    }

    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final deliverySnapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final paymentTerms = paymentSnapshot.docs
          .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
          .toList();
      final deliveryTerms = deliverySnapshot.docs
          .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _userPaymentTerms = paymentTerms;
          _userDeliveryTerms = deliveryTerms;
          if (_userPaymentTerms.isNotEmpty && _selectedPaymentTermId == null) {
            _selectedPaymentTermId = _userPaymentTerms.first.id;
          }
          if (_userDeliveryTerms.isNotEmpty && _selectedDeliveryTermId == null) {
            _selectedDeliveryTermId = _userDeliveryTerms.first.id;
          }
          _isLoadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  // ==================== حساب القيم ====================
  double _calculateSubtotal() => _items.fold(0.0, (t, i) => t + i.totalPrice);
  double _calculateTotalTax() => _items.fold(0.0, (t, i) => t + i.taxAmount);
  double _calculateNetPayable() => (_calculateSubtotal() + _calculateTotalTax()) - _withholdingTaxAmount;

  void _calculateWithholdingTax() {
    if (_selectedSupplierId != null) {
      final selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(
          id: '', nameAr: '', nameEn: '', phone: '', email: '', address: '',
          userId: '', createdAt: Timestamp.now(),
          subjectToWithholding: false, withholdingTaxRate: 1.0,
        ),
      );
      setState(() {
        _supplierSubjectToWithholding = selectedSupplier.subjectToWithholding;
        _withholdingTaxRate = selectedSupplier.withholdingTaxRate;
        _withholdingTaxAmount = _supplierSubjectToWithholding ? _calculateSubtotal() * (_withholdingTaxRate / 100) : 0.0;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _isLoadingTerms) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _submitOrder)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('basic_info'.tr()),
              const SizedBox(height: 8),
              _buildCompanyDropdown(),
              const SizedBox(height: 12),
              _buildFactoryDropdown(),
              const SizedBox(height: 12),
              _buildSupplierDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),

              _buildSectionTitle('taxes_discounts'.tr()),
              const SizedBox(height: 8),
              _buildTaxRateField(),
              const SizedBox(height: 12),
              _buildWithholdingTaxInfo(),
              const SizedBox(height: 12),

              _buildSectionTitle('payment_delivery_terms'.tr()),
              const SizedBox(height: 8),
              _buildPaymentTermsDropdown(),
              const SizedBox(height: 12),
              _buildDeliveryTermsDropdown(),
              const SizedBox(height: 12),

              _buildSectionTitle('additional_requirements'.tr()),
              const SizedBox(height: 8),
              _buildMultiSelectSection(
                title: 'conditions'.tr(),
                items: _additionalConditions,
                selectedIds: _selectedConditionsIds,
                onChanged: (list) => setState(() => _selectedConditionsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'required_documents'.tr(),
                items: _additionalDocuments,
                selectedIds: _selectedDocumentsIds,
                onChanged: (list) => setState(() => _selectedDocumentsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'notes'.tr(),
                items: _additionalNotes,
                selectedIds: _selectedNotesIds,
                onChanged: (list) => setState(() => _selectedNotesIds = list),
                isLoading: _isLoadingAdditional,
              ),

              _buildSectionTitle('items'.tr()),
              const SizedBox(height: 8),
              _buildItemsList(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              ),

              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              // ✅ تم تصحيح SwitchListTile هنا
              SwitchListTile(
                title: Text('delivered'.tr()),
                value: _isDelivered,
                onChanged: (val) => setState(() => _isDelivered = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== دوال بناء الأقسام ====================
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Widget _buildCompanyDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (!_showCompanySelector && _companies.isNotEmpty) {
      final selectedCompany = _companies.firstWhere(
        (c) => c.id == _selectedCompanyId,
        orElse: () => _companies.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('company'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(isArabic ? selectedCompany.nameAr : (selectedCompany.nameEn.isNotEmpty ? selectedCompany.nameEn : selectedCompany.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return DropdownButtonFormField<String>(
      initialValue: _companies.any((c) => c.id == _selectedCompanyId) ? _selectedCompanyId : null,
      decoration: InputDecoration(labelText: 'company'.tr(), border: const OutlineInputBorder()),
      items: _companies.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Text(isArabic ? c.nameAr : (c.nameEn.isNotEmpty ? c.nameEn : c.nameAr)),
        );
      }).toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
        });
        await _loadFactoriesForCompany(val);
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    if (_selectedCompanyId == null) return const SizedBox();
    final isArabic = context.locale.languageCode == 'ar';
    
    if (!_showFactorySelector && _factories.isNotEmpty) {
      final selectedFactory = _factories.firstWhere(
        (f) => f.id == _selectedFactoryId,
        orElse: () => _factories.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('factory'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(isArabic ? selectedFactory.nameAr : (selectedFactory.nameEn.isNotEmpty ? selectedFactory.nameEn : selectedFactory.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_factories.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_factories_found'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(labelText: 'factory'.tr(), border: const OutlineInputBorder()),
      items: _factories.map((f) {
        return DropdownMenuItem(
          value: f.id,
          child: Text(isArabic ? f.nameAr : (f.nameEn.isNotEmpty ? f.nameEn : f.nameAr)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(labelText: 'supplier'.tr(), border: const OutlineInputBorder()),
      items: _suppliers.map((v) {
        return DropdownMenuItem(
          value: v.id,
          child: Text(isArabic ? v.nameAr : (v.nameEn.isNotEmpty ? v.nameEn : v.nameAr)),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedSupplierId = val);
        _calculateWithholdingTax();
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _orderDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null && mounted) setState(() => _orderDate = d);
        },
      ),
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: 'tax_rate_percent'.tr(), suffixText: '%', border: const OutlineInputBorder()),
      onChanged: (v) {
        final rate = double.tryParse(v) ?? _taxRate;
        setState(() => _taxRate = rate);
        for (int i = 0; i < _items.length; i++) {
          _items[i] = _items[i].updateTaxStatus(_items[i].isTaxable, _items[i].isTaxable ? rate : 0);
        }
        _calculateWithholdingTax();
      },
    );
  }

  Widget _buildWithholdingTaxInfo() {
    if (_selectedSupplierId == null) return const SizedBox();
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '', nameAr: '', nameEn: '', phone: '', email: '', address: '',
        userId: '', createdAt: Timestamp.now(),
        subjectToWithholding: false, withholdingTaxRate: 1.0,
      ),
    );
    if (!selectedSupplier.subjectToWithholding) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'withholding_tax_rate_info'.tr(args: [selectedSupplier.withholdingTaxRate.toString()]),
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userPaymentTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_payment_terms'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('payment_terms'.tr()),
            value: _selectedPaymentTermId,
            items: _userPaymentTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic), style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPaymentTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userDeliveryTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_delivery_terms'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('delivery_terms'.tr()),
            value: _selectedDeliveryTermId,
            items: _userDeliveryTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic), style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDeliveryTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<AdditionalItem> items,
    required List<String> selectedIds,
    required Function(List<String>) onChanged,
    required bool isLoading,
  }) {
    final isArabic = context.locale.languageCode == 'ar';
    if (isLoading) {
      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    }
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_items_available'.tr(), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedIds.contains(item.id);
                return FilterChip(
                  label: Text(item.getTitle(isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newList = List.from(selectedIds);
                    if (selected) {
                      newList.add(item.id);
                    } else {
                      newList.remove(item.id);
                    }
                    onChanged(newList);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('no_items_added'.tr(), style: const TextStyle(color: Colors.grey))),
        ),
      );
    }
    final isArabic = context.locale.languageCode == 'ar';
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          key: ValueKey(item.itemId),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(isArabic ? item.nameAr : (item.nameEn.isNotEmpty ? item.nameEn : item.nameAr), style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        decoration: const InputDecoration(labelText: 'quantity', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? item.quantity;
                          if (newQty != item.quantity) {
                            setState(() {
                              _items[index] = item.updateQuantity(newQty);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        decoration: const InputDecoration(labelText: 'unit_price', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), prefixText: 'EGP '),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newPrice = double.tryParse(v) ?? item.unitPrice;
                          if (newPrice != item.unitPrice) {
                            setState(() {
                              _items[index] = item.updateUnitPrice(newPrice);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('is_taxable'),
                        value: item.isTaxable,
                        onChanged: (val) {
                          setState(() {
                            _items[index] = item.updateTaxStatus(val, val ? _taxRate : 0);
                            _calculateWithholdingTax();
                          });
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('total:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('${item.totalAfterTaxAmount.toStringAsFixed(2)} ${'currency'.tr()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    if (_items.isEmpty) return const SizedBox();
    final subtotal = _calculateSubtotal();
    final totalTax = _calculateTotalTax();
    final beforeWithholding = subtotal + totalTax;
    final netPayable = _calculateNetPayable();
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('order_summary'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            if (_supplierSubjectToWithholding && _withholdingTaxAmount > 0)
              _buildSummaryRow('withholding_tax'.tr(), -_withholdingTaxAmount, valueColor: Colors.red),
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false, Color? valueColor}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text('$sign${displayValue.toStringAsFixed(2)} ${'currency'.tr()}', style: TextStyle(color: valueColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

/*   Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(allItems: _allItems, preSelectedItems: _items.map((i) => i.itemId).toList()),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
      }
    });
    _calculateWithholdingTax();
  }
 */
 
 Future<void> _showItemSelectionDialog() async {
  final selected = await showDialog<List<Item>>(
    context: context,
    builder: (_) => ItemSelectionDialog(
      allItems: _allItems,
      preSelectedItems: _items.map((i) => i.itemId).toList(),
      isArabic: context.locale.languageCode == 'ar', // ✅ تمرير اللغة
    ),
  );
  if (selected == null || selected.isEmpty) return;
  setState(() {
    for (var i in selected) {
      if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
    }
  });
  _calculateWithholdingTax();
}
 
  bool _validateForm() {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return false;
    }
    if (_selectedSupplierId == null) {
      _showErrorSnackbar('supplier_not_selected'.tr());
      return false;
    }
    if (_items.isEmpty) {
      _showErrorSnackbar('no_items_selected'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return;
    }
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber = await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';

      final subtotal = _calculateSubtotal();
      final totalTax = _calculateTotalTax();
      final beforeWithholding = subtotal + totalTax;
      final netPayable = _calculateNetPayable();

      final selectedPaymentTerm = _userPaymentTerms.firstWhere(
        (t) => t.id == _selectedPaymentTermId,
        orElse: () => _userPaymentTerms.first,
      );
      final selectedDeliveryTerm = _userDeliveryTerms.firstWhere(
        (t) => t.id == _selectedDeliveryTermId,
        orElse: () => _userDeliveryTerms.first,
      );

      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: subtotal,
        totalTax: totalTax,
        totalAmountAfterTax: beforeWithholding,
        isDelivered: _isDelivered,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        paymentTermCode: selectedPaymentTerm.code,
        deliveryTermCode: selectedDeliveryTerm.code,
        conditionsIds: _selectedConditionsIds,
        documentsIds: _selectedDocumentsIds,
        notesIds: _selectedNotesIds,
      );

      await _firestoreService.createPurchaseOrder(order);
      
      if (_isDelivered && _selectedFactoryId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestoreService.processStockDelivery(
            companyId: _selectedCompanyId!,
            factoryId: _selectedFactoryId!,
            orderId: orderId,
            userId: user.uid,
            items: _items,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
} */

// pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart
/* 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/currency_service.dart';
import 'package:puresip_purchasing/services/user_currency_service.dart';
import '../../../services/firestore_service.dart';
import 'item_selection_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final UserCurrencyService _userCurrencyService = UserCurrencyService();

  // ==================== بيانات أساسية ====================
  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  // ==================== ضريبة الخصم ====================
  double _withholdingTaxAmount = 0.0;
  bool _supplierSubjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  // ==================== شروط الدفع والتسليم ====================
  List<UserPaymentTerm> _userPaymentTerms = [];
  List<UserDeliveryTerm> _userDeliveryTerms = [];
  String? _selectedPaymentTermId;
  String? _selectedDeliveryTermId;

  // ==================== العناصر الإضافية ====================
  List<AdditionalItem> _additionalConditions = [];
  List<AdditionalItem> _additionalDocuments = [];
  List<AdditionalItem> _additionalNotes = [];

  List<String> _selectedConditionsIds = [];
  List<String> _selectedDocumentsIds = [];
  List<String> _selectedNotesIds = [];

  bool _isLoadingAdditional = true;
  bool _isLoadingTerms = true;

  bool _showCompanySelector = true;
  bool _showFactorySelector = true;

  // ==================== متغيرات العملة ====================
  String _baseCurrency = 'EGP';
  String? _selectedCurrencyCode = 'EGP';
  double _exchangeRate = 1.0;
  bool _isLoadingCurrency = true;

  final List<String> _currencies = CurrencyService.getAvailableCurrencies();

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadAllData();
    _loadUserBaseCurrency();
  }

  // ==================== تحميل عملة المستخدم الأساسية ====================
  Future<void> _loadUserBaseCurrency() async {
    setState(() => _isLoadingCurrency = true);
    try {
      _baseCurrency = await _userCurrencyService.getUserBaseCurrency();
      _selectedCurrencyCode = _baseCurrency;
      _exchangeRate = 1.0;
      safeDebugPrint('✅ User base currency: $_baseCurrency');
    } catch (e) {
      safeDebugPrint('Error loading base currency: $e');
    } finally {
      setState(() => _isLoadingCurrency = false);
    }
  }

  // ==================== تحميل كل البيانات ====================
  Future<void> _loadAllData() async {
    await _loadInitialData();
    await _loadAdditionalItems();
    await _loadUserTerms();
  }

  // ==================== تحميل البيانات الأساسية ====================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('user_data_not_found'.tr());
        return;
      }

      final userData = userDoc.data()!;
      final companyIds =
          (userData['companyIds'] as List?)?.cast<String>() ?? [];
      if (companyIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('no_companies_found'.tr());
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserCompanies(companyIds),
        _firestoreService.getUserVendors(
          user.uid,
          (userData['supplierIds'] as List?)?.cast<String>() ?? [],
        ),
        _firestoreService.getUserItems(user.uid),
      ]);

      final companies = results[0] as List<Company>;
      final suppliers = results[1] as List<Supplier>;
      final items = results[2] as List<Item>;

      final String? firstCompanyId =
          companies.isNotEmpty ? companies.first.id : null;

      if (mounted) {
        setState(() {
          _companies = companies;
          _suppliers = suppliers;
          _allItems = items;

          if (companies.isNotEmpty &&
              (_selectedCompanyId == null || _selectedCompanyId!.isEmpty)) {
            _selectedCompanyId = firstCompanyId;
            _showCompanySelector = companies.length > 1;
          } else if (companies.length == 1) {
            _showCompanySelector = false;
          } else {
            _showCompanySelector = true;
          }
          _isLoading = false;
        });
      }

      if (firstCompanyId != null && firstCompanyId.isNotEmpty) {
        await _loadFactoriesForCompany(firstCompanyId);
      } else {
        if (mounted) {
          setState(() {
            _factories = [];
            _showFactorySelector = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar('error_loading_data'.tr());
    }
  }

  // ==================== تحميل المصانع ====================
  Future<void> _loadFactoriesForCompany(String companyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
      return;
    }

    try {
      final factories =
          await _firestoreService.getFactoriesByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _factories = factories;
          if (_factories.isNotEmpty && _selectedFactoryId == null) {
            _selectedFactoryId = _factories.first.id;
            _showFactorySelector = _factories.length > 1;
          } else if (_factories.length == 1) {
            _showFactorySelector = false;
          } else {
            _showFactorySelector = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
    }
  }

  // ==================== تحميل العناصر الإضافية ====================
  Future<void> _loadAdditionalItems() async {
    if (!mounted) return;
    setState(() => _isLoadingAdditional = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAdditional = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('additional_items')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs
          .map((doc) => AdditionalItem.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _additionalConditions =
              allItems.where((i) => i.type == AdditionalItemType.condition).toList();
          _additionalDocuments =
              allItems.where((i) => i.type == AdditionalItemType.document).toList();
          _additionalNotes =
              allItems.where((i) => i.type == AdditionalItemType.note).toList();
          _isLoadingAdditional = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAdditional = false);
    }
  }

  // ==================== تحميل شروط الدفع والتسليم ====================
  Future<void> _loadUserTerms() async {
    if (!mounted) return;
    setState(() => _isLoadingTerms = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTerms = false);
      return;
    }

    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final deliverySnapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final paymentTerms = paymentSnapshot.docs
          .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
          .toList();
      final deliveryTerms = deliverySnapshot.docs
          .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _userPaymentTerms = paymentTerms;
          _userDeliveryTerms = deliveryTerms;
          if (_userPaymentTerms.isNotEmpty && _selectedPaymentTermId == null) {
            _selectedPaymentTermId = _userPaymentTerms.first.id;
          }
          if (_userDeliveryTerms.isNotEmpty && _selectedDeliveryTermId == null) {
            _selectedDeliveryTermId = _userDeliveryTerms.first.id;
          }
          _isLoadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  // ==================== حساب القيم ====================
  double _calculateSubtotal() =>
      _items.fold(0.0, (t, i) => t + i.totalPrice);
  double _calculateTotalTax() =>
      _items.fold(0.0, (t, i) => t + i.taxAmount);
  double _calculateNetPayable() =>
      (_calculateSubtotal() + _calculateTotalTax()) - _withholdingTaxAmount;

  void _calculateWithholdingTax() {
    if (_selectedSupplierId != null) {
      final selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(
          id: '',
          nameAr: '',
          nameEn: '',
          phone: '',
          email: '',
          address: '',
          userId: '',
          createdAt: Timestamp.now(),
          subjectToWithholding: false,
          withholdingTaxRate: 1.0,
        ),
      );
      setState(() {
        _supplierSubjectToWithholding = selectedSupplier.subjectToWithholding;
        _withholdingTaxRate = selectedSupplier.withholdingTaxRate;
        _withholdingTaxAmount = _supplierSubjectToWithholding
            ? _calculateSubtotal() * (_withholdingTaxRate / 100)
            : 0.0;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== حساب القيمة بالعملة الأساسية ====================
  double _getAmountInBaseCurrency(double amount) {
    return amount * _exchangeRate;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _isLoadingTerms || _isLoadingCurrency) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('basic_info'.tr()),
              const SizedBox(height: 8),
              _buildCompanyDropdown(),
              const SizedBox(height: 12),
              _buildFactoryDropdown(),
              const SizedBox(height: 12),
              _buildSupplierDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildCurrencySelector(),
              const SizedBox(height: 12),

              _buildSectionTitle('taxes_discounts'.tr()),
              const SizedBox(height: 8),
              _buildTaxRateField(),
              const SizedBox(height: 12),
              _buildWithholdingTaxInfo(),
              const SizedBox(height: 12),

              _buildSectionTitle('payment_delivery_terms'.tr()),
              const SizedBox(height: 8),
              _buildPaymentTermsDropdown(),
              const SizedBox(height: 12),
              _buildDeliveryTermsDropdown(),
              const SizedBox(height: 12),

              _buildSectionTitle('additional_requirements'.tr()),
              const SizedBox(height: 8),
              _buildMultiSelectSection(
                title: 'conditions'.tr(),
                items: _additionalConditions,
                selectedIds: _selectedConditionsIds,
                onChanged: (list) => setState(() => _selectedConditionsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'required_documents'.tr(),
                items: _additionalDocuments,
                selectedIds: _selectedDocumentsIds,
                onChanged: (list) => setState(() => _selectedDocumentsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'notes'.tr(),
                items: _additionalNotes,
                selectedIds: _selectedNotesIds,
                onChanged: (list) => setState(() => _selectedNotesIds = list),
                isLoading: _isLoadingAdditional,
              ),

              _buildSectionTitle('items'.tr()),
              const SizedBox(height: 8),
              _buildItemsList(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),

              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('delivered'.tr()),
                value: _isDelivered,
                onChanged: (val) => setState(() => _isDelivered = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== دوال بناء الأقسام ====================
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (!_showCompanySelector && _companies.isNotEmpty) {
      final selectedCompany = _companies.firstWhere(
        (c) => c.id == _selectedCompanyId,
        orElse: () => _companies.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('company'.tr(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedCompany.nameAr
                          : (selectedCompany.nameEn.isNotEmpty
                              ? selectedCompany.nameEn
                              : selectedCompany.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue:
          _companies.any((c) => c.id == _selectedCompanyId) ? _selectedCompanyId : null,
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _companies.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Text(
            isArabic
                ? c.nameAr
                : (c.nameEn.isNotEmpty ? c.nameEn : c.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
        });
        await _loadFactoriesForCompany(val);
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    if (_selectedCompanyId == null) return const SizedBox();
    final isArabic = context.locale.languageCode == 'ar';

    if (!_showFactorySelector && _factories.isNotEmpty) {
      final selectedFactory = _factories.firstWhere(
        (f) => f.id == _selectedFactoryId,
        orElse: () => _factories.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('factory'.tr(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedFactory.nameAr
                          : (selectedFactory.nameEn.isNotEmpty
                              ? selectedFactory.nameEn
                              : selectedFactory.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_factories.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_factories_found'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _factories.map((f) {
        return DropdownMenuItem(
          value: f.id,
          child: Text(
            isArabic
                ? f.nameAr
                : (f.nameEn.isNotEmpty ? f.nameEn : f.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _suppliers.map((v) {
        return DropdownMenuItem(
          value: v.id,
          child: Text(
            isArabic
                ? v.nameAr
                : (v.nameEn.isNotEmpty ? v.nameEn : v.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedSupplierId = val);
        _calculateWithholdingTax();
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _orderDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null && mounted) setState(() => _orderDate = d);
        },
      ),
    );
  }

  // ==================== اختيار العملة ====================
  Widget _buildCurrencySelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCurrencyCode,
      decoration: InputDecoration(
        labelText: 'currency'.tr(),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
        helperText: 'base_currency'.tr(args: [_baseCurrency]),
        helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      items: _currencies.map<DropdownMenuItem<String>>((code) {
        final symbol = CurrencyService.getSymbol(code);
        final name = CurrencyService.getCurrencyName(code);
        final isBase = code == _baseCurrency;
        return DropdownMenuItem(
          value: code,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isBase ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBase ? Colors.green[700] : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              if (isBase)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'base'.tr(),
                    style: TextStyle(fontSize: 9, color: Colors.green[700]),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCurrencyCode = value);
          _exchangeRate = 1.0;
        }
      },
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final rate = double.tryParse(v) ?? _taxRate;
        setState(() => _taxRate = rate);
        for (int i = 0; i < _items.length; i++) {
          _items[i] = _items[i].updateTaxStatus(
              _items[i].isTaxable, _items[i].isTaxable ? rate : 0);
        }
        _calculateWithholdingTax();
      },
    );
  }

  Widget _buildWithholdingTaxInfo() {
    if (_selectedSupplierId == null) return const SizedBox();
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '',
        nameAr: '',
        nameEn: '',
        phone: '',
        email: '',
        address: '',
        userId: '',
        createdAt: Timestamp.now(),
        subjectToWithholding: false,
        withholdingTaxRate: 1.0,
      ),
    );
    if (!selectedSupplier.subjectToWithholding) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'withholding_tax_rate_info'.tr(
                    args: [selectedSupplier.withholdingTaxRate.toString()]),
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userPaymentTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_payment_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('payment_terms'.tr()),
            value: _selectedPaymentTermId,
            items: _userPaymentTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPaymentTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userDeliveryTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_delivery_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('delivery_terms'.tr()),
            value: _selectedDeliveryTermId,
            items: _userDeliveryTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDeliveryTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<AdditionalItem> items,
    required List<String> selectedIds,
    required Function(List<String>) onChanged,
    required bool isLoading,
  }) {
    final isArabic = context.locale.languageCode == 'ar';
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_items_available'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedIds.contains(item.id);
                return FilterChip(
                  label: Text(item.getTitle(isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newList = List.from(selectedIds);
                    if (selected) {
                      newList.add(item.id);
                    } else {
                      newList.remove(item.id);
                    }
                    onChanged(newList);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('no_items_added'.tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    final isArabic = context.locale.languageCode == 'ar';
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          key: ValueKey(item.itemId),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isArabic
                            ? item.nameAr
                            : (item.nameEn.isNotEmpty ? item.nameEn : item.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        decoration: const InputDecoration(
                          labelText: 'quantity',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? item.quantity;
                          if (newQty != item.quantity) {
                            setState(() {
                              _items[index] = item.updateQuantity(newQty);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        decoration: InputDecoration(
                          labelText: 'unit_price'.tr(),
                          border: const OutlineInputBorder(),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixText: '$_selectedCurrencyCode ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newPrice = double.tryParse(v) ?? item.unitPrice;
                          if (newPrice != item.unitPrice) {
                            setState(() {
                              _items[index] = item.updateUnitPrice(newPrice);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('is_taxable'),
                        value: item.isTaxable,
                        onChanged: (val) {
                          setState(() {
                            _items[index] = item.updateTaxStatus(
                                val, val ? _taxRate : 0);
                            _calculateWithholdingTax();
                          });
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('total:',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${item.totalAfterTaxAmount.toStringAsFixed(2)} $_selectedCurrencyCode',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    if (_items.isEmpty) return const SizedBox();
    final subtotal = _calculateSubtotal();
    final totalTax = _calculateTotalTax();
    final beforeWithholding = subtotal + totalTax;
    final netPayable = _calculateNetPayable();
    final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('order_summary'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow('total_before_withholding'.tr(), beforeWithholding),
            if (_supplierSubjectToWithholding && _withholdingTaxAmount > 0)
              _buildSummaryRow('withholding_tax'.tr(), -_withholdingTaxAmount,
                  valueColor: Colors.red),
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
            if (_selectedCurrencyCode != _baseCurrency) ...[
              const Divider(thickness: 1),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'amount_in_base_currency'.tr(args: [_baseCurrency]),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_baseCurrency ${amountInBaseCurrency.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isTotal = false, Color? valueColor}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            '$sign${displayValue.toStringAsFixed(2)} $_selectedCurrencyCode',
            style: TextStyle(
                color: valueColor,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
        isArabic: context.locale.languageCode == 'ar',
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
      }
    });
    _calculateWithholdingTax();
  }

  bool _validateForm() {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return false;
    }
    if (_selectedSupplierId == null) {
      _showErrorSnackbar('supplier_not_selected'.tr());
      return false;
    }
    if (_items.isEmpty) {
      _showErrorSnackbar('no_items_selected'.tr());
      return false;
    }
    return true;
  }

  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return;
    }
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber =
          await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';

      final subtotal = _calculateSubtotal();
      final totalTax = _calculateTotalTax();
      final beforeWithholding = subtotal + totalTax;
      final netPayable = _calculateNetPayable();

      final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

      final selectedPaymentTerm = _userPaymentTerms.firstWhere(
        (t) => t.id == _selectedPaymentTermId,
        orElse: () => _userPaymentTerms.first,
      );
      final selectedDeliveryTerm = _userDeliveryTerms.firstWhere(
        (t) => t.id == _selectedDeliveryTermId,
        orElse: () => _userDeliveryTerms.first,
      );

      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: subtotal,
        totalTax: totalTax,
        totalAmountAfterTax: beforeWithholding,
        isDelivered: _isDelivered,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        paymentTermCode: selectedPaymentTerm.code,
        deliveryTermCode: selectedDeliveryTerm.code,
        conditionsIds: _selectedConditionsIds,
        documentsIds: _selectedDocumentsIds,
        notesIds: _selectedNotesIds,
        currencyCode: _selectedCurrencyCode,
        exchangeRate: _exchangeRate,
        totalAmountInBaseCurrency: amountInBaseCurrency,
      );

      await _firestoreService.createPurchaseOrder(order);

      if (_isDelivered && _selectedFactoryId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestoreService.processStockDelivery(
            companyId: _selectedCompanyId!,
            factoryId: _selectedFactoryId!,
            orderId: orderId,
            userId: user.uid,
            items: _items,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('save_order_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
} */

// pages/purchasing/Purchasing_orders_crud/add_purchase_order_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/services/currency_service.dart';
import 'package:puresip_purchasing/services/user_currency_service.dart';
import '../../../services/firestore_service.dart';
import 'item_selection_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  const AddPurchaseOrderPage({super.key, this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final UserCurrencyService _userCurrencyService = UserCurrencyService();

  // ==================== بيانات أساسية ====================
  double _taxRate = 14.0;
  final List<Item> _items = [];
  List<Company> _companies = [];
  List<Factory> _factories = [];
  List<Supplier> _suppliers = [];
  List<Item> _allItems = [];

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  bool _isLoading = false;
  bool _isDelivered = false;

  // ==================== ضريبة الخصم ====================
  double _withholdingTaxAmount = 0.0;
  bool _supplierSubjectToWithholding = false;
  double _withholdingTaxRate = 1.0;

  // ==================== شروط الدفع والتسليم ====================
  List<UserPaymentTerm> _userPaymentTerms = [];
  List<UserDeliveryTerm> _userDeliveryTerms = [];
  String? _selectedPaymentTermId;
  String? _selectedDeliveryTermId;

  // ==================== العناصر الإضافية ====================
  List<AdditionalItem> _additionalConditions = [];
  List<AdditionalItem> _additionalDocuments = [];
  List<AdditionalItem> _additionalNotes = [];

  List<String> _selectedConditionsIds = [];
  List<String> _selectedDocumentsIds = [];
  List<String> _selectedNotesIds = [];

  bool _isLoadingAdditional = true;
  bool _isLoadingTerms = true;

  bool _showCompanySelector = true;
  bool _showFactorySelector = true;

  // ==================== متغيرات العملة ====================
  String _baseCurrency = 'EGP';
  String? _selectedCurrencyCode = 'EGP';
  double _exchangeRate = 1.0;
  bool _isLoadingCurrency = true;

  final List<String> _currencies = CurrencyService.getAvailableCurrencies();

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompany;
    _loadAllData();
    _loadUserBaseCurrency();
  }

  // ==================== تحميل عملة المستخدم الأساسية ====================
  Future<void> _loadUserBaseCurrency() async {
    setState(() => _isLoadingCurrency = true);
    try {
      _baseCurrency = await _userCurrencyService.getUserBaseCurrency();
      _selectedCurrencyCode = _baseCurrency;
      _exchangeRate = 1.0;
      safeDebugPrint('✅ User base currency: $_baseCurrency');
    } catch (e) {
      safeDebugPrint('Error loading base currency: $e');
    } finally {
      setState(() => _isLoadingCurrency = false);
    }
  }

  // ==================== تحميل كل البيانات ====================
  Future<void> _loadAllData() async {
    await _loadInitialData();
    await _loadAdditionalItems();
    await _loadUserTerms();
  }

  // ==================== تحميل البيانات الأساسية ====================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('user_data_not_found'.tr());
        return;
      }

      final userData = userDoc.data()!;
      final companyIds =
          (userData['companyIds'] as List?)?.cast<String>() ?? [];
      if (companyIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showErrorSnackbar('no_companies_found'.tr());
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserCompanies(companyIds),
        _firestoreService.getUserVendors(
          user.uid,
          (userData['supplierIds'] as List?)?.cast<String>() ?? [],
        ),
        _firestoreService.getUserItems(user.uid),
      ]);

      final companies = results[0] as List<Company>;
      final suppliers = results[1] as List<Supplier>;
      final items = results[2] as List<Item>;

      final String? firstCompanyId =
          companies.isNotEmpty ? companies.first.id : null;

      if (mounted) {
        setState(() {
          _companies = companies;
          _suppliers = suppliers;
          _allItems = items;

          if (companies.isNotEmpty &&
              (_selectedCompanyId == null || _selectedCompanyId!.isEmpty)) {
            _selectedCompanyId = firstCompanyId;
            _showCompanySelector = companies.length > 1;
          } else if (companies.length == 1) {
            _showCompanySelector = false;
          } else {
            _showCompanySelector = true;
          }
          _isLoading = false;
        });
      }

      if (firstCompanyId != null && firstCompanyId.isNotEmpty) {
        await _loadFactoriesForCompany(firstCompanyId);
      } else {
        if (mounted) {
          setState(() {
            _factories = [];
            _showFactorySelector = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar('error_loading_data'.tr());
    }
  }

  // ==================== تحميل المصانع ====================
  Future<void> _loadFactoriesForCompany(String companyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (companyId.isEmpty) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
      return;
    }

    try {
      final factories =
          await _firestoreService.getFactoriesByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _factories = factories;
          if (_factories.isNotEmpty && _selectedFactoryId == null) {
            _selectedFactoryId = _factories.first.id;
            _showFactorySelector = _factories.length > 1;
          } else if (_factories.length == 1) {
            _showFactorySelector = false;
          } else {
            _showFactorySelector = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _factories = [];
          _showFactorySelector = false;
        });
      }
    }
  }

  // ==================== تحميل العناصر الإضافية ====================
  Future<void> _loadAdditionalItems() async {
    if (!mounted) return;
    setState(() => _isLoadingAdditional = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAdditional = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('additional_items')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs
          .map((doc) => AdditionalItem.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _additionalConditions = allItems
              .where((i) => i.type == AdditionalItemType.condition)
              .toList();
          _additionalDocuments = allItems
              .where((i) => i.type == AdditionalItemType.document)
              .toList();
          _additionalNotes =
              allItems.where((i) => i.type == AdditionalItemType.note).toList();
          _isLoadingAdditional = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAdditional = false);
    }
  }

  // ==================== تحميل شروط الدفع والتسليم ====================
  Future<void> _loadUserTerms() async {
    if (!mounted) return;
    setState(() => _isLoadingTerms = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTerms = false);
      return;
    }

    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final deliverySnapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final paymentTerms = paymentSnapshot.docs
          .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
          .toList();
      final deliveryTerms = deliverySnapshot.docs
          .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _userPaymentTerms = paymentTerms;
          _userDeliveryTerms = deliveryTerms;
          if (_userPaymentTerms.isNotEmpty && _selectedPaymentTermId == null) {
            _selectedPaymentTermId = _userPaymentTerms.first.id;
          }
          if (_userDeliveryTerms.isNotEmpty &&
              _selectedDeliveryTermId == null) {
            _selectedDeliveryTermId = _userDeliveryTerms.first.id;
          }
          _isLoadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  // ==================== حساب القيم ====================
  double _calculateSubtotal() => _items.fold(0.0, (t, i) => t + i.totalPrice);
  double _calculateTotalTax() => _items.fold(0.0, (t, i) => t + i.taxAmount);
  double _calculateNetPayable() =>
      (_calculateSubtotal() + _calculateTotalTax()) - _withholdingTaxAmount;

  void _calculateWithholdingTax() {
    if (_selectedSupplierId != null) {
      final selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(
          id: '',
          nameAr: '',
          nameEn: '',
          phone: '',
          email: '',
          address: '',
          userId: '',
          createdAt: Timestamp.now(),
          subjectToWithholding: false,
          withholdingTaxRate: 1.0,
        ),
      );
      setState(() {
        _supplierSubjectToWithholding = selectedSupplier.subjectToWithholding;
        _withholdingTaxRate = selectedSupplier.withholdingTaxRate;
        _withholdingTaxAmount = _supplierSubjectToWithholding
            ? _calculateSubtotal() * (_withholdingTaxRate / 100)
            : 0.0;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== حساب القيمة بالعملة الأساسية ====================
  double _getAmountInBaseCurrency(double amount) {
    return amount * _exchangeRate;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _isLoadingTerms || _isLoadingCurrency) {
      return Scaffold(
        appBar: AppBar(title: Text('new_purchase_order'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('new_purchase_order'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitOrder,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('basic_info'.tr()),
              const SizedBox(height: 8),
              _buildCompanyDropdown(),
              const SizedBox(height: 12),
              _buildFactoryDropdown(),
              const SizedBox(height: 12),
              _buildSupplierDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildCurrencySelector(),
              const SizedBox(height: 12),
              _buildSectionTitle('taxes_discounts'.tr()),
              const SizedBox(height: 8),
              _buildTaxRateField(),
              const SizedBox(height: 12),
              _buildWithholdingTaxInfo(),
              const SizedBox(height: 12),
              _buildSectionTitle('payment_delivery_terms'.tr()),
              const SizedBox(height: 8),
              _buildPaymentTermsDropdown(),
              const SizedBox(height: 12),
              _buildDeliveryTermsDropdown(),
              const SizedBox(height: 12),
              _buildSectionTitle('additional_requirements'.tr()),
              const SizedBox(height: 8),
              _buildMultiSelectSection(
                title: 'conditions'.tr(),
                items: _additionalConditions,
                selectedIds: _selectedConditionsIds,
                onChanged: (list) =>
                    setState(() => _selectedConditionsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'required_documents'.tr(),
                items: _additionalDocuments,
                selectedIds: _selectedDocumentsIds,
                onChanged: (list) =>
                    setState(() => _selectedDocumentsIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildMultiSelectSection(
                title: 'notes'.tr(),
                items: _additionalNotes,
                selectedIds: _selectedNotesIds,
                onChanged: (list) => setState(() => _selectedNotesIds = list),
                isLoading: _isLoadingAdditional,
              ),
              _buildSectionTitle('items'.tr()),
              const SizedBox(height: 8),
              _buildItemsList(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_items'.tr()),
                onPressed: _showItemSelectionDialog,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('delivered'.tr()),
                value: _isDelivered,
                onChanged: (val) => setState(() => _isDelivered = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== دوال بناء الأقسام ====================
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (!_showCompanySelector && _companies.isNotEmpty) {
      final selectedCompany = _companies.firstWhere(
        (c) => c.id == _selectedCompanyId,
        orElse: () => _companies.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('company'.tr(),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedCompany.nameAr
                          : (selectedCompany.nameEn.isNotEmpty
                              ? selectedCompany.nameEn
                              : selectedCompany.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _companies.any((c) => c.id == _selectedCompanyId)
          ? _selectedCompanyId
          : null,
      decoration: InputDecoration(
        labelText: 'company'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _companies.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Text(
            isArabic ? c.nameAr : (c.nameEn.isNotEmpty ? c.nameEn : c.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) async {
        if (val == null) return;
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
        });
        await _loadFactoriesForCompany(val);
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildFactoryDropdown() {
    if (_selectedCompanyId == null) return const SizedBox();
    final isArabic = context.locale.languageCode == 'ar';

    if (!_showFactorySelector && _factories.isNotEmpty) {
      final selectedFactory = _factories.firstWhere(
        (f) => f.id == _selectedFactoryId,
        orElse: () => _factories.first,
      );
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.factory, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('factory'.tr(),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      isArabic
                          ? selectedFactory.nameAr
                          : (selectedFactory.nameEn.isNotEmpty
                              ? selectedFactory.nameEn
                              : selectedFactory.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_factories.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_factories_found'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedFactoryId,
      decoration: InputDecoration(
        labelText: 'factory'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _factories.map((f) {
        return DropdownMenuItem(
          value: f.id,
          child: Text(
            isArabic ? f.nameAr : (f.nameEn.isNotEmpty ? f.nameEn : f.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedFactoryId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return DropdownButtonFormField<String>(
      initialValue: _selectedSupplierId,
      decoration: InputDecoration(
        labelText: 'supplier'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: _suppliers.map((v) {
        return DropdownMenuItem(
          value: v.id,
          child: Text(
            isArabic ? v.nameAr : (v.nameEn.isNotEmpty ? v.nameEn : v.nameAr),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedSupplierId = val);
        _calculateWithholdingTax();
      },
      validator: (val) => val == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text('order_date'.tr()),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _orderDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null && mounted) setState(() => _orderDate = d);
        },
      ),
    );
  }

  // ==================== اختيار العملة ====================
  Widget _buildCurrencySelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCurrencyCode,
      decoration: InputDecoration(
        labelText: 'currency'.tr(),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
        helperText: 'base_currency'.tr(args: [_baseCurrency]),
        helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      items: _currencies.map<DropdownMenuItem<String>>((code) {
        final symbol = CurrencyService.getSymbol(code);
        final name = CurrencyService.getCurrencyName(code);
        final isBase = code == _baseCurrency;
        return DropdownMenuItem(
          value: code,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isBase ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBase ? Colors.green[700] : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              if (isBase)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'base'.tr(),
                    style: TextStyle(fontSize: 9, color: Colors.green[700]),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCurrencyCode = value);
          _exchangeRate = 1.0;
        }
      },
      validator: (value) => value == null ? 'required_field'.tr() : null,
    );
  }

  Widget _buildTaxRateField() {
    return TextFormField(
      initialValue: _taxRate.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'tax_rate_percent'.tr(),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final rate = double.tryParse(v) ?? _taxRate;
        setState(() => _taxRate = rate);
        for (int i = 0; i < _items.length; i++) {
          _items[i] = _items[i].updateTaxStatus(
              _items[i].isTaxable, _items[i].isTaxable ? rate : 0);
        }
        _calculateWithholdingTax();
      },
    );
  }

  Widget _buildWithholdingTaxInfo() {
    if (_selectedSupplierId == null) return const SizedBox();
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '',
        nameAr: '',
        nameEn: '',
        phone: '',
        email: '',
        address: '',
        userId: '',
        createdAt: Timestamp.now(),
        subjectToWithholding: false,
        withholdingTaxRate: 1.0,
      ),
    );
    if (!selectedSupplier.subjectToWithholding) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'withholding_tax_rate_info'
                    .tr(args: [selectedSupplier.withholdingTaxRate.toString()]),
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userPaymentTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_payment_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('payment_terms'.tr()),
            value: _selectedPaymentTermId,
            items: _userPaymentTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) =>
                setState(() => _selectedPaymentTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTermsDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_userDeliveryTerms.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_delivery_terms'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('delivery_terms'.tr()),
            value: _selectedDeliveryTermId,
            items: _userDeliveryTerms.map((term) {
              return DropdownMenuItem(
                value: term.id,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(term.getName(isArabic),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        term.getDescription(isArabic),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) =>
                setState(() => _selectedDeliveryTermId = value),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<AdditionalItem> items,
    required List<String> selectedIds,
    required Function(List<String>) onChanged,
    required bool isLoading,
  }) {
    final isArabic = context.locale.languageCode == 'ar';
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('no_items_available'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedIds.contains(item.id);
                return FilterChip(
                  label: Text(item.getTitle(isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newList = List.from(selectedIds);
                    if (selected) {
                      newList.add(item.id);
                    } else {
                      newList.remove(item.id);
                    }
                    onChanged(newList);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Card(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('no_items_added'.tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    final isArabic = context.locale.languageCode == 'ar';
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          key: ValueKey(item.itemId),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isArabic
                            ? item.nameAr
                            : (item.nameEn.isNotEmpty
                                ? item.nameEn
                                : item.nameAr),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        decoration: const InputDecoration(
                          labelText: 'quantity',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? item.quantity;
                          if (newQty != item.quantity) {
                            setState(() {
                              _items[index] = item.updateQuantity(newQty);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        decoration: InputDecoration(
                          labelText: 'unit_price'.tr(),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          prefixText: '$_selectedCurrencyCode ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newPrice = double.tryParse(v) ?? item.unitPrice;
                          if (newPrice != item.unitPrice) {
                            setState(() {
                              _items[index] = item.updateUnitPrice(newPrice);
                              _calculateWithholdingTax();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('is_taxable'),
                        value: item.isTaxable,
                        onChanged: (val) {
                          setState(() {
                            _items[index] =
                                item.updateTaxStatus(val, val ? _taxRate : 0);
                            _calculateWithholdingTax();
                          });
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('total:',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${item.totalAfterTaxAmount.toStringAsFixed(2)} $_selectedCurrencyCode',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    if (_items.isEmpty) return const SizedBox();
    final subtotal = _calculateSubtotal();
    final totalTax = _calculateTotalTax();
    final beforeWithholding = subtotal + totalTax;
    final netPayable = _calculateNetPayable();
    final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('order_summary'.tr(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildSummaryRow('subtotal'.tr(), subtotal),
            _buildSummaryRow('tax'.tr(), totalTax),
            _buildSummaryRow(
                'total_before_withholding'.tr(), beforeWithholding),
            if (_supplierSubjectToWithholding && _withholdingTaxAmount > 0)
              _buildSummaryRow('withholding_tax'.tr(), -_withholdingTaxAmount,
                  valueColor: Colors.red),
            const Divider(thickness: 2),
            _buildSummaryRow('net_payable'.tr(), netPayable, isTotal: true),
            if (_selectedCurrencyCode != _baseCurrency) ...[
              const Divider(thickness: 1),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'amount_in_base_currency'.tr(args: [_baseCurrency]),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_baseCurrency ${amountInBaseCurrency.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isTotal = false, Color? valueColor}) {
    final sign = value.isNegative ? '- ' : '';
    final displayValue = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            '$sign${displayValue.toStringAsFixed(2)} $_selectedCurrencyCode',
            style: TextStyle(
                color: valueColor,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemSelectionDialog() async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: _allItems,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
        isArabic: context.locale.languageCode == 'ar',
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) _items.add(i);
      }
    });
    _calculateWithholdingTax();
  }

  bool _validateForm() {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return false;
    }
    if (_selectedSupplierId == null) {
      _showErrorSnackbar('supplier_not_selected'.tr());
      return false;
    }
    if (_items.isEmpty) {
      _showErrorSnackbar('no_items_selected'.tr());
      return false;
    }
    return true;
  }

  // ✅ تحسين دالة _submitOrder مع معالجة أفضل للأخطاء
  Future<void> _submitOrder() async {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showErrorSnackbar('company_not_selected'.tr());
      return;
    }
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final poNumber =
          await _firestoreService.generatePoNumber(_selectedCompanyId!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'PO-$timestamp';

      final subtotal = _calculateSubtotal();
      final totalTax = _calculateTotalTax();
      final beforeWithholding = subtotal + totalTax;
      final netPayable = _calculateNetPayable();

      final amountInBaseCurrency = _getAmountInBaseCurrency(netPayable);

/*       final selectedPaymentTerm = _userPaymentTerms.firstWhere(
        (t) => t.id == _selectedPaymentTermId,
        orElse: () => _userPaymentTerms.first,
      );
      final selectedDeliveryTerm = _userDeliveryTerms.firstWhere(
        (t) => t.id == _selectedDeliveryTermId,
        orElse: () => _userDeliveryTerms.first,
      ); */

      final selectedPaymentTerm = _userPaymentTerms.isNotEmpty
          ? _userPaymentTerms.firstWhere(
              (t) => t.id == _selectedPaymentTermId,
              orElse: () => _userPaymentTerms.first,
            )
          : UserPaymentTerm(
              id: '',
              userId: '',
              code: 'CASH',
              nameAr: 'دفع نقدي',
              nameEn: 'Cash',
              descriptionAr: '',
              descriptionEn: '',
              isActive: true,
              order: 0,
              days: 0, // ✅ أضف القيمة المطلوبة
              createdAt: DateTime.now(), // ✅ أضف القيمة المطلوبة
            );

      final selectedDeliveryTerm = _userDeliveryTerms.isNotEmpty
          ? _userDeliveryTerms.firstWhere(
              (t) => t.id == _selectedDeliveryTermId,
              orElse: () => _userDeliveryTerms.first,
            )
          : UserDeliveryTerm(
              id: '',
              userId: '',
              code: 'EXW',
              nameAr: 'تسليم من المصنع',
              nameEn: 'Ex Works',
              descriptionAr: '',
              descriptionEn: '',
              isActive: true,
              order: 0, // ✅ إذا كان مطلوباً
              createdAt: DateTime.now(), // ✅ إذا كان مطلوباً
            );

      final order = PurchaseOrder(
        id: orderId,
        poNumber: poNumber,
        userId: _auth.currentUser?.uid ?? '',
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        status: 'pending',
        items: _items,
        taxRate: _taxRate,
        totalAmount: subtotal,
        totalTax: totalTax,
        totalAmountAfterTax: beforeWithholding,
        isDelivered: _isDelivered,
        withholdingTaxAmount: _withholdingTaxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        netPayable: netPayable,
        paymentTermCode: selectedPaymentTerm.code,
        deliveryTermCode: selectedDeliveryTerm.code,
        conditionsIds: _selectedConditionsIds,
        documentsIds: _selectedDocumentsIds,
        notesIds: _selectedNotesIds,
        currencyCode: _selectedCurrencyCode,
        exchangeRate: _exchangeRate,
        totalAmountInBaseCurrency: amountInBaseCurrency,
      );

      // ✅ طباعة تفاصيل الطلب للتأكد
      safeDebugPrint('📦 Saving order: ${order.poNumber} (${order.id})');
      safeDebugPrint(
          '💰 Currency: ${order.currencyCode}, Rate: ${order.exchangeRate}');

      await _firestoreService.createPurchaseOrder(order);

      if (_isDelivered && _selectedFactoryId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestoreService.processStockDelivery(
            companyId: _selectedCompanyId!,
            factoryId: _selectedFactoryId!,
            orderId: orderId,
            userId: user.uid,
            items: _items,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      // ✅ عرض تفاصيل الخطأ كاملة
      safeDebugPrint('❌ Error saving order: $e');
      safeDebugPrint('📚 Stack trace: $stackTrace');
      _showErrorSnackbar('${'save_order_error'.tr()}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
